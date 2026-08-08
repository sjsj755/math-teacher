import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:math_up_app/core/application/notification_service.dart';
import 'package:math_up_app/core/db/database.dart';
import 'package:math_up_app/core/infrastructure/app_config_repository.dart';
import 'package:math_up_app/core/infrastructure/http_sync_service.dart';

Future<Database> _openTestDb() async {
  return AppDatabase.open(
    factory: databaseFactory,
    path: inMemoryDatabasePath,
    sqlLoader: (file) async =>
        File(p.join('lib', 'core', 'db', 'migrations', file)).readAsString(),
  );
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;
  late AppConfigRepository config;
  late List<http.Request> requests;

  setUp(() async {
    db = await _openTestDb();
    config = AppConfigRepository(db);
    await config.set('server_url', 'http://localhost:8000/api/v1');
    requests = [];
  });

  tearDown(() async {
    await db.close();
  });

  NotificationService serviceWith(MockClient client) {
    return NotificationService(
      db: db,
      sync: HttpSyncService(
        baseUrl: 'http://localhost:8000/api/v1',
        client: client,
      ),
    );
  }

  test('requestBindCode：生成绑定码并保存有效期', () async {
    final client = MockClient((request) async {
      requests.add(request);
      return http.Response(
        '{"bind_code": "MATH-8F3K", "expires_at": "2026-08-09 21:30:00"}',
        200,
      );
    });
    final service = serviceWith(client);

    final code = await service.requestBindCode();

    expect(code, 'MATH-8F3K');
    expect(requests.single.url.path, '/api/v1/bind-code');
    expect(await config.get('bind_code'), 'MATH-8F3K');
    expect(await config.get('bind_code_expires_at'), '2026-08-09 21:30:00');
  });

  test('fetchStatus：已绑定时保存最近推送时间', () async {
    final client = MockClient((request) async {
      requests.add(request);
      return http.Response(
        '{"bound": true, "last_push_at": "2026-08-07 21:30", '
        '"daily_enabled": true, "push_time": "21:30"}',
        200,
      );
    });
    final service = serviceWith(client);

    final status = await service.fetchStatus();

    expect(status.bound, isTrue);
    expect(status.lastPushAt, '2026-08-07 21:30');
    expect(await config.get('bound'), 'true');
    expect(await config.get('last_push_at'), '2026-08-07 21:30');
  });

  test('confirmBind：返回家长昵称并标记已绑定', () async {
    await config.set('bind_code', 'MATH-8F3K');
    final client = MockClient((request) async {
      requests.add(request);
      return http.Response(
        '{"status": "bound", "parent_nick": "妈妈"}',
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    final service = serviceWith(client);

    final nick = await service.confirmBind();

    expect(nick, '妈妈');
    expect(await config.get('bound'), 'true');
    expect(await config.get('parent_nick'), '妈妈');
    final body = jsonDecode(requests.single.body) as Map<String, dynamic>;
    expect(body['bind_code'], 'MATH-8F3K');
    expect(body['device_id'], isNotEmpty);
  });

  test('unbind：调用接口并清理本地状态', () async {
    await config.set('bound', 'true');
    await config.set('parent_nick', '妈妈');
    await config.set('last_push_at', '2026-08-07 21:30');
    await config.set('bind_code', 'MATH-8F3K');
    final client = MockClient((request) async {
      requests.add(request);
      return http.Response('{"status": "unbound"}', 200);
    });
    final service = serviceWith(client);

    await service.unbind();

    expect(requests.single.url.path, '/api/v1/unbind');
    expect(await config.get('bound'), 'false');
    expect(await config.get('parent_nick'), '');
    expect(await config.get('bind_code'), '');
  });

  test('未配置服务器地址时抛 NO_SERVER_URL', () async {
    final service = NotificationService(db: db);
    await expectLater(
      service.requestBindCode(),
      throwsA(isA<SyncException>()),
    );
  });
}
