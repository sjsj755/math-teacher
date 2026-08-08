import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';

import '../domain/answer_grading.dart';
import '../domain/error_book_machine.dart';
import '../domain/models/practice.dart';
import '../domain/models/question.dart';
import '../infrastructure/error_book_repository.dart';
import '../infrastructure/question_repository_impl.dart';
import 'diagnosis_service.dart';
import 'practice_recommender.dart';

/// 练习用例编排：推荐/重做/周清会话与逐题提交。
class PracticeService {
  PracticeService({
    required this.db,
    Future<String> Function(String path)? assetLoader,
  }) : assetLoader = assetLoader ?? _rootBundleLoader;

  final Database db;
  final Future<String> Function(String path) assetLoader;
  final Random _random = Random();

  static Future<String> _rootBundleLoader(String path) {
    return rootBundle.loadString(path);
  }

  Future<PracticeSession> startRecommendSession(String grade) async {
    final config = await _loadConfig();
    final questions = await SqliteQuestionRepository(db).all();
    final chapters =
        jsonDecode(await assetLoader('assets/data/chapters.json'))
            as Map<String, dynamic>;
    final errorIds = await ErrorBookRepository(db).allQuestionIds();
    final latest = await DiagnosisService(
      db: db,
      assetLoader: assetLoader,
    ).latestResult();
    final recommendation = PracticeRecommender().recommend(
      weakPoints: latest?.weakPoints ?? const [],
      all: questions,
      config: config,
      excludeIds: errorIds.toSet(),
      gradeChapterIds: _gradeChapterIds(grade, chapters),
    );
    return PracticeSession(
      mode: PracticeMode.recommend,
      config: config,
      questions: [
        for (final q in recommendation.questions) PracticeQuestion(question: q),
      ],
    );
  }

  Future<PracticeSession> startRedoSession() async {
    final config = await _loadConfig();
    final all = await SqliteQuestionRepository(db).all();
    final byId = {for (final q in all) q.id: q};
    final repo = ErrorBookRepository(db);
    final entries = await repo.listByStatuses([
      ErrorBookStatus.pending,
      ErrorBookStatus.pendingUpgrade,
    ]);
    final errorIds = (await repo.allQuestionIds()).toSet();
    final questions = <PracticeQuestion>[];

    for (final entry in entries) {
      final original = byId[entry.questionId];
      if (original == null) {
        continue;
      }
      if (entry.status == ErrorBookStatus.pending) {
        questions.add(
          PracticeQuestion(question: original, errorBookId: entry.id),
        );
      } else {
        // 升级类：优先同类题（同节、未入错题本、选择/填空）。
        final similarPool =
            all
                .where(
                  (q) =>
                      q.variantGroup == original.variantGroup &&
                      !errorIds.contains(q.id) &&
                      (q.type == QuestionType.choice ||
                          q.type == QuestionType.fill),
                )
                .toList()
              ..shuffle(_random);
        final picked = similarPool.isEmpty ? original : similarPool.first;
        questions.add(
          PracticeQuestion(
            question: picked,
            errorBookId: entry.id,
            similar: true,
          ),
        );
      }
    }
    return PracticeSession(
      mode: PracticeMode.redo,
      config: config,
      questions: questions,
    );
  }

  Future<PracticeSession> startWeeklySession() async {
    final config = await _loadConfig();
    final all = await SqliteQuestionRepository(db).all();
    final byId = {for (final q in all) q.id: q};
    final repo = ErrorBookRepository(db);
    final entries = await repo.listByStatuses([ErrorBookStatus.redone]);
    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    final questions = <PracticeQuestion>[];

    for (final entry in entries) {
      final reviewAt = entry.reviewAt;
      if (reviewAt == null || reviewAt.isAfter(today)) {
        continue;
      }
      final question = byId[entry.questionId];
      if (question == null) {
        continue;
      }
      questions.add(
        PracticeQuestion(question: question, errorBookId: entry.id),
      );
    }
    return PracticeSession(
      mode: PracticeMode.weekly,
      config: config,
      questions: questions,
    );
  }

  Future<PracticeFeedback> submitAnswer(
    PracticeSession session,
    PracticeAnswer answer,
  ) async {
    final correct = AnswerGrading.isCorrect(
      question: answer.question,
      selectedOption: answer.selectedOption,
      fillText: answer.fillText,
      timedOut: answer.timedOut,
    );
    await db.insert('answer_record', {
      'question_id': answer.question.id,
      'result': correct ? 1 : 0,
      'seconds': answer.seconds,
      'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
    });

    final answerText = switch (answer.question.type) {
      QuestionType.choice =>
        '正确答案：${answer.question.answer}（${_optionText(answer.question, answer.question.answer)}）',
      _ => '正确答案：${answer.question.answer}',
    };
    final repo = ErrorBookRepository(db);
    var addedToErrorBook = false;
    ErrorBookStatus? newStatus;
    String? statusMessage;

    switch (session.mode) {
      case PracticeMode.recommend:
        if (!correct) {
          final existing = await repo.find(answer.question.id);
          if (existing == null) {
            await repo.insert(
              questionId: answer.question.id,
              loseType: answer.question.loseType,
            );
            addedToErrorBook = true;
          } else {
            final transition = ErrorBookMachine.transition(
              current: existing.status,
              correct: false,
              mode: PracticeMode.recommend,
            );
            await repo.applyTransition(existing.id, transition);
          }
        }
      case PracticeMode.redo:
      case PracticeMode.weekly:
        final practiceQuestion = session.questions.firstWhere(
          (item) => item.question.id == answer.question.id,
        );
        final entryId = practiceQuestion.errorBookId;
        if (entryId != null) {
          final entry = await repo.findById(entryId);
          if (entry != null) {
            final transition = ErrorBookMachine.transition(
              current: entry.status,
              correct: correct,
              mode: session.mode,
            );
            await repo.applyTransition(entry.id, transition);
            newStatus = transition.status;
            statusMessage = _statusMessage(
              session.mode,
              correct,
              transition.status,
            );
          }
        }
    }

    return PracticeFeedback(
      correct: correct,
      answerText: answerText,
      explain: answer.question.explain ?? '暂无解析',
      addedToErrorBook: addedToErrorBook,
      newErrorStatus: newStatus,
      statusMessage: statusMessage,
    );
  }

  Future<PracticeConfig> _loadConfig() async {
    final json =
        jsonDecode(await assetLoader('assets/data/config.json'))
            as Map<String, dynamic>;
    return PracticeConfig.fromJson(json);
  }

  Set<String> _gradeChapterIds(String grade, Map<String, dynamic> chapters) {
    final books = (chapters['books'] as List<dynamic>? ?? const []);
    final ids = <String>{};
    for (final book in books.cast<Map<String, dynamic>>()) {
      final grades = (book['grades'] as List<dynamic>? ?? const [])
          .cast<String>();
      if (grade != '高三' && !grades.contains(grade)) {
        continue;
      }
      for (final chapter
          in (book['chapters'] as List<dynamic>? ?? const [])
              .cast<Map<String, dynamic>>()) {
        ids.add(chapter['id'] as String);
      }
    }
    return ids;
  }

  String _optionText(Question question, String letter) {
    final index = letter.codeUnitAt(0) - 65;
    if (index < 0 || index >= question.options.length) {
      return letter;
    }
    return question.options[index];
  }

  String _statusMessage(
    PracticeMode mode,
    bool correct,
    ErrorBookStatus status,
  ) {
    if (mode == PracticeMode.redo) {
      return correct ? '已重做，进入 7 天观察期' : '升级为待重做，下次推荐同类题';
    }
    return correct ? '复测通过，已掌握' : '复测未通过，升级为待重做';
  }
}
