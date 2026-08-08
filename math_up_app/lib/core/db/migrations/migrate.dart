import 'package:flutter/services.dart' show rootBundle;
import 'package:sqflite/sqflite.dart';

/// 数据库结构版本号，与 app_config.schema_version 保持一致。
const int kSchemaVersion = 1;

/// 按序执行 migrations/ 下的 SQL 迁移脚本（事务内完成）。
///
/// [loader] 用于读取迁移脚本内容：默认从 Flutter assets 读取；
/// 测试环境可注入基于文件系统的 loader。
abstract final class DatabaseMigrator {
  static const String initSqlAsset = 'lib/core/db/migrations/001_init.sql';

  static Future<void> migrate(
    Database db, {
    Future<String> Function(String file)? loader,
  }) async {
    final load = loader ?? _assetLoader;
    final current = await db.getVersion();

    if (current < 1) {
      await db.transaction((txn) async {
        final sql = await load('001_init.sql');
        for (final statement in _splitStatements(sql)) {
          await txn.execute(statement);
        }
      });
      await db.setVersion(1);
    }
  }

  static Future<String> _assetLoader(String file) async {
    final bundle = rootBundle;
    return bundle.loadString('lib/core/db/migrations/$file');
  }

  /// 按“分号 + 换行”切分 SQL 语句，兼容注释行。
  static List<String> _splitStatements(String sql) {
    final lines = sql.split('\n');
    final statements = <String>[];
    final buffer = StringBuffer();
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('--') || trimmed.isEmpty) {
        continue;
      }
      buffer.writeln(line);
      if (line.trim().endsWith(';')) {
        statements.add(buffer.toString());
        buffer.clear();
      }
    }
    if (buffer.toString().trim().isNotEmpty) {
      statements.add(buffer.toString());
    }
    return statements;
  }
}
