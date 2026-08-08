import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:math_up_app/core/application/digest_service.dart';
import 'package:math_up_app/core/db/database.dart';
import 'package:math_up_app/core/infrastructure/question_importer.dart';
import 'package:math_up_app/core/infrastructure/http_sync_service.dart';

Future<Database> _openTestDb() async {
  return AppDatabase.open(
    factory: databaseFactory,
    path: inMemoryDatabasePath,
    sqlLoader: (file) async =>
        File(p.join('lib', 'core', 'db', 'migrations', file)).readAsString(),
  );
}

Future<void> _importQuestions(Database db) async {
  final chapters = jsonDecode(
    await File('assets/data/chapters.json').readAsString(),
  ) as Map<String, dynamic>;
  final questions = jsonDecode(
    await File('assets/data/questions.json').readAsString(),
  ) as Map<String, dynamic>;
  final contentIndex = jsonDecode(
    await File('assets/data/content_index.json').readAsString(),
  ) as Map<String, dynamic>;
  await QuestionImporter(db).import(
    chaptersJson: jsonEncode(chapters),
    questionsJson: jsonEncode(questions),
    contentIndexJson: jsonEncode(contentIndex),
  );
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;

  setUp(() async {
    db = await _openTestDb();
    await _importQuestions(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> seedRecords(DateTime now) async {
    final today = '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final yesterdayText = '${yesterday.year.toString().padLeft(4, '0')}-'
        '${yesterday.month.toString().padLeft(2, '0')}-'
        '${yesterday.day.toString().padLeft(2, '0')}';

    // 今日：3 对 2 错（错题分布在两个知识点）
    final answers = [
      ('A1-1-1-001', 1, 30),
      ('A1-1-2-001', 1, 25),
      ('A1-2-1-001', 1, 40),
      ('A1-3-2-001', 0, 60),
      ('A1-3-2-002', 0, 75),
    ];
    for (final (id, result, seconds) in answers) {
      await db.insert('answer_record', {
        'question_id': id,
        'result': result,
        'seconds': seconds,
        'date': today,
      });
    }
    // 昨日：2 条（用于连续打卡）
    await db.insert('answer_record', {
      'question_id': 'A1-1-1-001',
      'result': 1,
      'seconds': 20,
      'date': yesterdayText,
    });
    await db.insert('answer_record', {
      'question_id': 'A1-1-1-002',
      'result': 0,
      'seconds': 30,
      'date': yesterdayText,
    });
  }

  test('buildToday：题数/正确率/时长/薄弱点/连续天数', () async {
    final now = DateTime(2026, 8, 8, 21, 0);
    await seedRecords(now);

    final digest = await DigestService(db: db, now: () => now).buildToday();

    expect(digest.practiceCount, 5);
    expect(digest.correctCount, 3);
    expect(digest.errorCount, 2);
    expect(digest.minutes, 4); // (30+25+40+60+75)/60 ≈ 3.83 → 4
    expect(digest.weakPoints, ['A1-3-2']);
    expect(digest.weakPointNames, isNotEmpty);
    expect(digest.streakDays, 2);
  });

  test('generateToday：写入队列且同日覆盖', () async {
    final now = DateTime(2026, 8, 8);
    await seedRecords(now);
    final service = DigestService(db: db, now: () => now);

    await service.generateToday();
    var rows = await db.query('digest_queue');
    expect(rows.length, 1);
    expect(rows.first['synced'], 0);
    expect(rows.first['date'], '2026-08-08');

    final payload = jsonDecode(rows.first['payload'] as String)
        as Map<String, dynamic>;
    expect(payload['practice_count'], 5);

    // 同日再次生成只覆盖、不新增
    await service.generateToday();
    rows = await db.query('digest_queue');
    expect(rows.length, 1);
  });

  test('syncPending：上送成功标记 synced=1', () async {
    final now = DateTime(2026, 8, 8);
    await seedRecords(now);
    await db.insert('app_config', {
      'key': 'server_url',
      'value': 'http://localhost:8000/api/v1',
    });

    http.Request? captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response('{"accepted": true}', 200);
    });
    final service = DigestService(
      db: db,
      now: () => now,
      syncFactory: (baseUrl) => HttpSyncService(
        baseUrl: baseUrl,
        client: client,
      ),
    );

    await service.generateToday();
    final synced = await service.syncPending();

    expect(synced, 1);
    expect(captured!.url.path, '/api/v1/daily-digest');
    final body = jsonDecode(captured!.body) as Map<String, dynamic>;
    expect(body['date'], '2026-08-08');
    expect(body['practice_count'], 5);
    expect(body['device_id'], isNot(isEmpty));

    final rows = await db.query('digest_queue');
    expect(rows.first['synced'], 1);
  });

  test('syncPending：未配置服务器地址时跳过', () async {
    final now = DateTime(2026, 8, 8);
    await seedRecords(now);
    final service = DigestService(db: db, now: () => now);
    await service.generateToday();

    expect(await service.syncPending(), 0);
    final rows = await db.query('digest_queue');
    expect(rows.first['synced'], 0);
  });

  test('syncPending：服务端拒绝时保留未同步', () async {
    final now = DateTime(2026, 8, 8);
    await seedRecords(now);
    await db.insert('app_config', {
      'key': 'server_url',
      'value': 'http://localhost:8000/api/v1',
    });
    final client = MockClient(
      (_) async => http.Response(
        '{"detail": {"code": "NOT_BOUND", "message": "设备未绑定"}}',
        404,
      ),
    );
    final service = DigestService(
      db: db,
      now: () => now,
      syncFactory: (baseUrl) => HttpSyncService(
        baseUrl: baseUrl,
        client: client,
      ),
    );
    await service.generateToday();

    expect(await service.syncPending(), 0);
    final rows = await db.query('digest_queue');
    expect(rows.first['synced'], 0);
  });
}
