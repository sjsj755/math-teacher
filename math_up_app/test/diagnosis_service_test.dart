import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:math_up_app/core/application/diagnosis_service.dart';
import 'package:math_up_app/core/db/database.dart';
import 'package:math_up_app/core/domain/models/diagnosis.dart';
import 'package:math_up_app/core/domain/models/question.dart';
import 'package:math_up_app/core/infrastructure/question_importer.dart';

Future<Database> _openDb(String path) async {
  return AppDatabase.open(
    factory: databaseFactory,
    path: path,
    sqlLoader: (file) async =>
        File(p.join('lib', 'core', 'db', 'migrations', file)).readAsString(),
  );
}

Future<void> _importAssets(Database db) async {
  final importer = QuestionImporter(db);
  await importer.import(
    chaptersJson: await File('assets/data/chapters.json').readAsString(),
    questionsJson: await File('assets/data/questions.json').readAsString(),
    contentIndexJson: await File(
      'assets/data/content_index.json',
    ).readAsString(),
  );
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('集成：完成一次诊断后落库并可还原结果', () async {
    final db = await _openDb(inMemoryDatabasePath);
    await _importAssets(db);
    final service = DiagnosisService(
      db: db,
      assetLoader: (path) => File(path).readAsString(),
    );

    final session = await service.startSession('高一');
    expect(session.questions, hasLength(15));

    final answers = <DiagnosisAnswer>[
      for (final item in session.questions)
        DiagnosisAnswer(
          question: item.question,
          group: item.group,
          timed: item.timed,
          selectedOption: item.question.type == QuestionType.choice
              ? item.question.answer
              : null,
          fillText: item.question.type == QuestionType.fill
              ? item.question.answer
              : null,
          selfOption:
              (item.question.type == QuestionType.selfS ||
                  item.question.type == QuestionType.selfP)
              ? 0
              : null,
          seconds: item.timed ? 30 : 5,
        ),
    ];

    final result = await service.submitDiagnosis(answers);
    expect(result.diagnosisId, isNotNull);
    expect(result.kScore, 1);
    expect(result.tScore, 1);
    expect(result.sScore, 1);
    expect(result.pScore, 1);

    final diagnosisRows = await db.query('diagnosis');
    expect(diagnosisRows, hasLength(1));
    final recordRows = await db.query('answer_record');
    expect(recordRows, hasLength(15));
    expect(
      recordRows.every((r) => r['diagnosis_id'] == result.diagnosisId),
      isTrue,
    );

    final latest = await service.latestResult();
    expect(latest, isNotNull);
    expect(latest!.overall, 1);
    expect(latest.totalQuestions, 12);
    expect(latest.totalCorrect, 12);
    expect(latest.weakPoints, isEmpty);
    expect(latest.attribution, isEmpty);

    await db.close();
  });

  test('迁移升级：v1 库升级到 v2 保留旧数据并新增列', () async {
    final dir = await Directory.systemTemp.createTemp('math_migrate');
    final path = p.join(dir.path, 'upgrade.db');
    final sql001 = await File(
      p.join('lib', 'core', 'db', 'migrations', '001_init.sql'),
    ).readAsString();

    final v1 = await databaseFactory.openDatabase(path);
    final statements = sql001.split('\n').fold<StringBuffer>(StringBuffer(), (
      buf,
      line,
    ) {
      if (line.trim().isEmpty || line.trim().startsWith('--')) {
        return buf;
      }
      buf.writeln(line);
      return buf;
    }).toString();
    for (final statement
        in statements
            .split(RegExp(r';\s*\n'))
            .where((s) => s.trim().isNotEmpty)) {
      await v1.execute(statement);
    }
    await v1.insert('answer_record', {
      'question_id': 'A1-1-1-001',
      'result': 1,
      'seconds': 5,
      'date': '2026-08-08',
    });
    await v1.setVersion(1);
    await v1.close();

    final upgraded = await _openDb(path);
    expect(await upgraded.getVersion(), 2);

    final questionCols = await upgraded.rawQuery('PRAGMA table_info(question)');
    expect(questionCols.map((c) => c['name']), contains('is_timed'));
    final answerCols = await upgraded.rawQuery(
      'PRAGMA table_info(answer_record)',
    );
    expect(answerCols.map((c) => c['name']), contains('self_option'));
    final diagnosisCols = await upgraded.rawQuery(
      'PRAGMA table_info(diagnosis)',
    );
    expect(diagnosisCols.map((c) => c['name']), contains('attribution'));

    final records = await upgraded.query('answer_record');
    expect(records, hasLength(1));
    expect(records.first['question_id'], 'A1-1-1-001');

    await upgraded.close();
    await dir.delete(recursive: true);
  });
}
