import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:math_up_app/core/db/database.dart';
import 'package:math_up_app/core/domain/models/question.dart';
import 'package:math_up_app/core/infrastructure/question_importer.dart';
import 'package:math_up_app/core/infrastructure/question_repository_impl.dart';

Future<Database> _openTestDb() async {
  return AppDatabase.open(
    factory: databaseFactory,
    path: inMemoryDatabasePath,
    sqlLoader: (file) async =>
        File(p.join('lib', 'core', 'db', 'migrations', file)).readAsString(),
  );
}

Future<String> _readAsset(String relativePath) async {
  return File(relativePath).readAsString();
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;
  late Map<String, dynamic> chaptersJson;
  late Map<String, dynamic> questionsJson;
  late Map<String, dynamic> contentIndexJson;
  late int expectedCount;

  setUp(() async {
    db = await _openTestDb();
    chaptersJson =
        jsonDecode(await _readAsset('assets/data/chapters.json'))
            as Map<String, dynamic>;
    questionsJson =
        jsonDecode(await _readAsset('assets/data/questions.json'))
            as Map<String, dynamic>;
    contentIndexJson =
        jsonDecode(await _readAsset('assets/data/content_index.json'))
            as Map<String, dynamic>;
    expectedCount = (questionsJson['questions'] as List<dynamic>).length;
  });

  tearDown(() async {
    await db.close();
  });

  Future<ImportResult> runImport() {
    return QuestionImporter(db).import(
      chaptersJson: jsonEncode(chaptersJson),
      questionsJson: jsonEncode(questionsJson),
      contentIndexJson: jsonEncode(contentIndexJson),
    );
  }

  test('迁移：user_version 为 2 且写入默认配置', () async {
    expect(await db.getVersion(), 2);
    final rows = await db.query('app_config');
    final config = {
      for (final row in rows) row['key'] as String: row['value'] as String,
    };
    expect(config['schema_version'], '2');
    expect(config['content_version'], '0');
    expect(config['push_time'], '21:30');
    expect(config['daily_enabled'], 'true');
    expect(config['bound'], 'false');
  });

  test('导入：首次导入行数与 content_version 一致', () async {
    final result = await runImport();
    expect(result.imported, isTrue);
    expect(result.questionCount, expectedCount);
    expect(result.contentVersion, contentIndexJson['content_version']);
    expect(result.schemaVersion, 2);

    final count = await db.rawQuery('SELECT COUNT(*) AS c FROM question');
    expect(count.first['c'], expectedCount);

    final rows = await db.query(
      'app_config',
      where: 'key = ?',
      whereArgs: ['content_version'],
    );
    expect(rows.first['value'], '${contentIndexJson['content_version']}');
  });

  test('导入：重复初始化幂等，不重复插入', () async {
    final first = await runImport();
    expect(first.imported, isTrue);

    final second = await runImport();
    expect(second.imported, isFalse);
    expect(second.questionCount, expectedCount);

    final count = await db.rawQuery('SELECT COUNT(*) AS c FROM question');
    expect(count.first['c'], expectedCount);
  });

  test('导入：脏数据失败且不留半截数据', () async {
    final bad = jsonDecode(jsonEncode(questionsJson)) as Map<String, dynamic>;
    final list = bad['questions'] as List<dynamic>;
    list.add(jsonDecode(jsonEncode(list.first)));

    final importer = QuestionImporter(db);
    await expectLater(
      importer.import(
        chaptersJson: jsonEncode(chaptersJson),
        questionsJson: jsonEncode(bad),
        contentIndexJson: jsonEncode(contentIndexJson),
      ),
      throwsA(isA<FormatException>()),
    );

    final count = await db.rawQuery('SELECT COUNT(*) AS c FROM question');
    expect(count.first['c'], 0);
  });

  test('仓储：count/all/byKnowledge/byVariantGroup 查询正确', () async {
    await runImport();
    final repo = SqliteQuestionRepository(db);

    expect(await repo.count(), expectedCount);
    expect((await repo.all()).length, expectedCount);

    final byVariant = await repo.byVariantGroup('A1-3-2');
    expect(byVariant, isNotEmpty);
    expect(byVariant.every((q) => q.variantGroup == 'A1-3-2'), isTrue);

    final byChapter = await repo.byKnowledge('A1-3');
    expect(byChapter, isNotEmpty);
    expect(byChapter.every((q) => q.chapter == 'A1-3'), isTrue);
    expect(byChapter.length, greaterThanOrEqualTo(byVariant.length));
  });

  test('六表读写：answer_record/error_book/digest_queue/app_config', () async {
    await runImport();

    await db.insert('answer_record', {
      'question_id': 'A1-1-1-001',
      'result': 1,
      'seconds': 30,
      'date': '2026-08-08',
    });
    final answers = await db.query('answer_record');
    expect(answers.length, 1);

    await db.insert('error_book', {
      'question_id': 'A1-1-1-001',
      'lose_type': 'knowledge',
      'status': 'pending',
      'redo_count': 0,
    });
    await db.update(
      'error_book',
      {'status': 'redone'},
      where: 'question_id = ?',
      whereArgs: ['A1-1-1-001'],
    );
    final redone = await db.query(
      'error_book',
      where: 'status = ?',
      whereArgs: ['redone'],
    );
    expect(redone.length, 1);

    await db.insert('digest_queue', {
      'date': '2026-08-08',
      'payload': '{}',
      'synced': 0,
    });
    final unsynced = await db.query('digest_queue', where: 'synced = 0');
    expect(unsynced.length, 1);

    await db.insert('app_config', {
      'key': 'grade',
      'value': '高一',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    final grade = await db.query(
      'app_config',
      where: 'key = ?',
      whereArgs: ['grade'],
    );
    expect(grade.first['value'], '高一');

    final question = await db.query(
      'question',
      where: 'id = ?',
      whereArgs: ['A1-1-1-001'],
      limit: 1,
    );
    final model = Question.fromMap(question.first);
    expect(model.type, QuestionType.choice);
    expect(model.options.length, 4);
    expect(model.answer, 'B');
  });
}
