import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'migrations/migrate.dart';

/// SQLite 数据库打开、迁移与默认配置初始化。
abstract final class AppDatabase {
  static const String dbName = 'math_up.db';

  static const Map<String, String> defaultConfig = {
    'schema_version': '$kSchemaVersion',
    'content_version': '0',
    'grade': '',
    'push_time': '21:30',
    'daily_enabled': 'true',
    'bound': 'false',
  };

  /// 打开数据库（测试可注入 [factory] 与 [path]），执行迁移并写入默认配置。
  static Future<Database> open({
    DatabaseFactory? factory,
    String? path,
    Future<String> Function(String file)? sqlLoader,
  }) async {
    final dbFactory = factory ?? databaseFactory;
    final dbPath = path ?? await defaultPath();
    final db = await dbFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        // 不声明 version：迁移完全交给 DatabaseMigrator（PRAGMA user_version）管理，
        // 避免 sqflite 在新建库时直接写入默认版本号导致迁移被跳过。
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
      ),
    );
    await DatabaseMigrator.migrate(db, loader: sqlLoader);
    await _seedConfig(db);
    return db;
  }

  static Future<String> defaultPath() async {
    final dir = await getDatabasesPath();
    return p.join(dir, dbName);
  }

  static Future<void> _seedConfig(Database db) async {
    await db.transaction((txn) async {
      for (final entry in defaultConfig.entries) {
        await txn.insert('app_config', {
          'key': entry.key,
          'value': entry.value,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    });
  }
}
