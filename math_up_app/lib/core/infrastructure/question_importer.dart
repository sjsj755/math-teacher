import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;
import 'package:sqflite/sqflite.dart';

import '../db/migrations/migrate.dart';
import '../domain/models/question.dart';

/// 题库导入结果（供初始化用例与页面展示）。
class ImportResult {
  const ImportResult({
    required this.imported,
    required this.questionCount,
    required this.chapterCount,
    required this.contentVersion,
    required this.schemaVersion,
  });

  /// 本次是否实际执行了导入（false 表示内容未变化，跳过导入）。
  final bool imported;
  final int questionCount;
  final int chapterCount;
  final int contentVersion;
  final int schemaVersion;
}

/// 将 assets 中的题库 JSON 导入 SQLite question 表。
///
/// 幂等规则：app_config.content_version 与内容索引一致且题目数一致时跳过导入；
/// 内容版本变化时仅清空重导 question 表，不影响学习记录表。
class QuestionImporter {
  QuestionImporter(this._db);

  final Database _db;

  static const Set<String> _questionTypes = {
    'choice',
    'fill',
    'essay',
    'self_s',
    'self_p',
  };
  static const Set<String> _loseTypes = {
    'knowledge',
    'method',
    'calculation',
    'standard',
    'psychology',
  };
  static const Set<String> _thinkingMethods = {
    '函数与方程',
    '数形结合',
    '分类讨论',
    '转化与化归',
    '特殊与一般',
    '有限与无限',
    '整体与局部',
    '或然与必然',
  };

  Future<ImportResult> importFromAssets({AssetBundle? bundle}) async {
    final assets = bundle ?? rootBundle;
    final chaptersJson = await assets.loadString('assets/data/chapters.json');
    final questionsJson = await assets.loadString('assets/data/questions.json');
    final contentIndexJson = await assets.loadString(
      'assets/data/content_index.json',
    );
    return import(
      chaptersJson: chaptersJson,
      questionsJson: questionsJson,
      contentIndexJson: contentIndexJson,
    );
  }

  Future<ImportResult> import({
    required String chaptersJson,
    required String questionsJson,
    required String contentIndexJson,
  }) async {
    final index = jsonDecode(contentIndexJson) as Map<String, dynamic>;
    final contentVersion = index['content_version'] as int;

    final chapters = jsonDecode(chaptersJson) as Map<String, dynamic>;
    final chapterIds = <String>{};
    final sectionIds = <String>{};
    _collectChapterCodes(chapters, chapterIds, sectionIds);

    final rawQuestions =
        (jsonDecode(questionsJson) as Map<String, dynamic>)['questions']
            as List<dynamic>;
    final questions = rawQuestions
        .map((item) => Question.fromJson(item as Map<String, dynamic>))
        .toList();
    _validate(questions, chapterIds, sectionIds);

    final storedVersion = await _getConfig('content_version');
    final storedCount = await _db.rawQuery(
      'SELECT COUNT(*) AS c FROM question',
    );
    final existingCount = storedCount.first['c'] as int;
    if (storedVersion == '$contentVersion' &&
        existingCount == questions.length) {
      return ImportResult(
        imported: false,
        questionCount: questions.length,
        chapterCount: chapterIds.length,
        contentVersion: contentVersion,
        schemaVersion: kSchemaVersion,
      );
    }

    await _db.transaction((txn) async {
      await txn.delete('question');
      for (final question in questions) {
        await txn.insert(
          'question',
          question.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await txn.insert('app_config', {
        'key': 'content_version',
        'value': '$contentVersion',
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });

    return ImportResult(
      imported: true,
      questionCount: questions.length,
      chapterCount: chapterIds.length,
      contentVersion: contentVersion,
      schemaVersion: kSchemaVersion,
    );
  }

  void _collectChapterCodes(
    Map<String, dynamic> chapters,
    Set<String> chapterIds,
    Set<String> sectionIds,
  ) {
    final books = chapters['books'] as List<dynamic>;
    for (final book in books.cast<Map<String, dynamic>>()) {
      for (final chapter
          in (book['chapters'] as List<dynamic>).cast<Map<String, dynamic>>()) {
        final chapterId = chapter['id'] as String;
        chapterIds.add(chapterId);
        for (final section
            in (chapter['sections'] as List<dynamic>? ?? const [])
                .cast<Map<String, dynamic>>()) {
          sectionIds.add(section['id'] as String);
        }
      }
    }
  }

  void _validate(
    List<Question> questions,
    Set<String> chapterIds,
    Set<String> sectionIds,
  ) {
    final ids = <String>{};
    for (final question in questions) {
      if (!ids.add(question.id)) {
        throw FormatException('题库导入失败：题目 id 重复 ${question.id}');
      }
      if (!_questionTypes.contains(question.type.code)) {
        throw FormatException('题库导入失败：非法题目类型 ${question.type.code}');
      }
      if (question.difficulty < 1 || question.difficulty > 5) {
        throw FormatException('题库导入失败：难度越界 ${question.id}');
      }
      if (!_loseTypes.contains(question.loseType.code)) {
        throw FormatException('题库导入失败：非法失分类型 ${question.loseType.code}');
      }
      final method = question.thinkingMethod;
      if (method != null && !_thinkingMethods.contains(method)) {
        throw FormatException('题库导入失败：非法思维方法 $method（${question.id}）');
      }
      if (question.difficulty >= 3 &&
          question.type != QuestionType.selfS &&
          question.type != QuestionType.selfP &&
          method == null) {
        throw FormatException('题库导入失败：中档及以上题目缺少思维方法标签 ${question.id}');
      }
      if (question.chapter != 'DIAG' &&
          !chapterIds.contains(question.chapter)) {
        throw FormatException(
          '题库导入失败：章节编码悬空 ${question.chapter}（${question.id}）',
        );
      }
      if (!sectionIds.contains(question.variantGroup) &&
          !question.variantGroup.startsWith('DIAG-')) {
        throw FormatException(
          '题库导入失败：variant_group 悬空 ${question.variantGroup}（${question.id}）',
        );
      }
      if (question.stem.isEmpty || question.knowledgePoint.isEmpty) {
        throw FormatException('题库导入失败：题干或知识点为空 ${question.id}');
      }
      if (question.type == QuestionType.choice) {
        if (question.options.length != 4 ||
            !const {'A', 'B', 'C', 'D'}.contains(question.answer)) {
          throw FormatException('题库导入失败：选择题选项或答案不合法 ${question.id}');
        }
      } else if (question.type == QuestionType.fill ||
          question.type == QuestionType.essay) {
        if (question.answer.trim().isEmpty) {
          throw FormatException('题库导入失败：填空/解答题答案为空 ${question.id}');
        }
      } else {
        if (question.options.length < 2) {
          throw FormatException('题库导入失败：自评题选项不足 ${question.id}');
        }
      }
    }
  }

  Future<String?> _getConfig(String key) async {
    final rows = await _db.query(
      'app_config',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['value'] as String;
  }
}
