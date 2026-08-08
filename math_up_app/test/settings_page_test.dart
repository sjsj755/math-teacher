import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:math_up_app/core/application/db_initializer.dart';
import 'package:math_up_app/core/db/database.dart';
import 'package:math_up_app/core/infrastructure/http_sync_service.dart';
import 'package:math_up_app/core/theme.dart';
import 'package:math_up_app/features/settings/settings_controller.dart';
import 'package:math_up_app/features/settings/settings_page.dart';

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

  testWidgets('设置页渲染：通知设置＋QQ 绑定＋关于', (tester) async {
    // testWidgets 主体运行在 FakeAsync 区，sqflite_common_ffi 的隔离区调用
    // 需在 runAsync（真实异步区）中完成。
    late Database db;
    await tester.runAsync(() async {
      db = await _openTestDb();
    });
    addTearDown(() async {
      await tester.runAsync(() => db.close());
    });
    final client = MockClient(
      (request) async => http.Response('{"accepted": true}', 200),
    );
    final controller = SettingsController(
      db: db,
      sync: HttpSyncService(
        baseUrl: 'http://localhost:8000/api/v1',
        client: client,
      ),
    );
    // sqflite_common_ffi 走真实隔离区，需在 runAsync 中完成加载
    await tester.runAsync(controller.load);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: SettingsPage(
          dbInitController: DbInitController(),
          controller: controller,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('设置'), findsOneWidget);
    expect(find.text('家长通知'), findsOneWidget);
    expect(find.text('服务器地址'), findsOneWidget);
    expect(find.text('每日日报'), findsOneWidget);
    expect(find.text('推送时间'), findsOneWidget);
    expect(find.text('QQ 绑定'), findsOneWidget);
    expect(find.text('生成绑定码'), findsOneWidget);
    expect(find.text('关于'), findsOneWidget);
    expect(find.text('v0.6.0'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
