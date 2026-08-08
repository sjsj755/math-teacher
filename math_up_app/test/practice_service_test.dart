import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:math_up_app/core/application/practice_service.dart';
import 'package:math_up_app/core/db/database.dart';
import 'package:math_up_app/core/domain/models/practice.dart';
import 'package:math_up_app/core/domain/models/question.dart';
import 'package:math_up_app/core/infrastructure/error_book_repository.dart';
import 'package:math_up_app/core/infrastructure/question_importer.dart';

Future<Database> _openDb() async {
  return AppDatabase.open(
    factory: databaseFactory,
    path: inMemoryDatabasePath,
    sqlLoader: (file) async =>
        File(p.join('lib', 'core', 'db', 'migrations', file)).readAsString(),
  );
}

Future<void> _importAssets(Database db) async {
  await QuestionImporter(db).import(
    chaptersJson: await File('assets/data/chapters.json').readAsString(),
    questionsJson: await File('assets/data/questions.json').readAsString(),
    contentIndexJson: await File(
      'assets/data/content_index.json',
    ).readAsString(),
  );
}

PracticeAnswer _answer(Question q, {bool correct = true}) {
  if (q.type == QuestionType.choice) {
    return PracticeAnswer(
      question: q,
      selectedOption: correct ? q.answer : _wrongLetter(q),
      seconds: 10,
    );
  }
  return PracticeAnswer(
    question: q,
    fillText: correct ? q.answer : 'wrong-answer',
    seconds: 10,
  );
}

String _wrongLetter(Question q) {
  for (final letter in const ['A', 'B', 'C', 'D']) {
    if (letter != q.answer) {
      return letter;
    }
  }
  return 'A';
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('推荐练习答错：自动收录错题本并落库作答记录', () async {
    final db = await _openDb();
    await _importAssets(db);
    final service = PracticeService(
      db: db,
      assetLoader: (path) => File(path).readAsString(),
    );

    final session = await service.startRecommendSession('高一');
    expect(session.mode, PracticeMode.recommend);
    expect(session.questions, hasLength(10));

    final first = session.questions.first.question;
    final feedback = await service.submitAnswer(
      session,
      _answer(first, correct: false),
    );
    expect(feedback.correct, isFalse);
    expect(feedback.addedToErrorBook, isTrue);

    final recordRows = await db.query('answer_record');
    expect(recordRows, hasLength(1));
    final repo = ErrorBookRepository(db);
    final entry = await repo.find(first.id);
    expect(entry, isNotNull);
    expect(entry!.status, ErrorBookStatus.pending);

    await db.close();
  });

  test('重做答对：进入观察期（review_at=+7 天）', () async {
    final db = await _openDb();
    await _importAssets(db);
    final service = PracticeService(
      db: db,
      assetLoader: (path) => File(path).readAsString(),
    );

    final session = await service.startRecommendSession('高一');
    final target = session.questions.first.question;
    await service.submitAnswer(session, _answer(target, correct: false));

    final redoSession = await service.startRedoSession();
    expect(redoSession.mode, PracticeMode.redo);
    expect(redoSession.questions, hasLength(1));
    expect(redoSession.questions.first.question.id, target.id);

    final feedback = await service.submitAnswer(
      redoSession,
      _answer(target, correct: true),
    );
    expect(feedback.correct, isTrue);
    expect(feedback.newErrorStatus, ErrorBookStatus.redone);

    final entry = await ErrorBookRepository(db).find(target.id);
    expect(entry!.status, ErrorBookStatus.redone);
    final expectedReview = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    ).add(const Duration(days: 7));
    expect(
      entry.reviewAt!.isBefore(expectedReview.add(const Duration(days: 1))),
      isTrue,
    );
    expect(
      entry.reviewAt!.isAfter(expectedReview.subtract(const Duration(days: 2))),
      isTrue,
    );

    await db.close();
  });

  test('升级类重做：使用同类题（同节未入错题本）', () async {
    final db = await _openDb();
    await _importAssets(db);
    final service = PracticeService(
      db: db,
      assetLoader: (path) => File(path).readAsString(),
    );
    final repo = ErrorBookRepository(db);

    // 直接构造一条 pending 错题（A1-1-1 节下有多道题）。
    final entryId = await repo.insert(
      questionId: 'A1-1-1-001',
      loseType: LoseType.knowledge,
    );
    // 重做答错 → 升级。
    final redoSession = await service.startRedoSession();
    final original = redoSession.questions.first;
    expect(original.question.id, 'A1-1-1-001');
    await service.submitAnswer(
      redoSession,
      _answer(original.question, correct: false),
    );
    final upgraded = await repo.findById(entryId);
    expect(upgraded!.status, ErrorBookStatus.pendingUpgrade);
    expect(upgraded.redoCount, 1);

    // 再次进入重做：应为同类题。
    final nextSession = await service.startRedoSession();
    expect(nextSession.questions, hasLength(1));
    final similar = nextSession.questions.first;
    expect(similar.similar, isTrue);
    expect(similar.question.id, isNot('A1-1-1-001'));
    expect(similar.question.variantGroup, 'A1-1-1');

    await db.close();
  });

  test('周清复测：到期题复测答对→已掌握，未到期不出现', () async {
    final db = await _openDb();
    await _importAssets(db);
    final service = PracticeService(
      db: db,
      assetLoader: (path) => File(path).readAsString(),
    );
    final repo = ErrorBookRepository(db);

    final session = await service.startRecommendSession('高一');
    final target = session.questions.first.question;
    await service.submitAnswer(session, _answer(target, correct: false));
    final entry = await repo.find(target.id);
    expect(entry, isNotNull);

    // 重做答对 → 观察中。
    final redoSession = await service.startRedoSession();
    await service.submitAnswer(redoSession, _answer(target, correct: true));

    // 未到期：周清为空。
    final emptyWeekly = await service.startWeeklySession();
    expect(emptyWeekly.questions, isEmpty);

    // 把复测日期改为今天 → 进入周清；答对 → 已掌握。
    await repo.setReviewDate(entry!.id, DateTime.now());
    final weekly = await service.startWeeklySession();
    expect(weekly.questions, hasLength(1));
    final feedback = await service.submitAnswer(
      weekly,
      _answer(weekly.questions.first.question, correct: true),
    );
    expect(feedback.newErrorStatus, ErrorBookStatus.mastered);
    final mastered = await repo.findById(entry.id);
    expect(mastered!.status, ErrorBookStatus.mastered);

    await db.close();
  });
}
