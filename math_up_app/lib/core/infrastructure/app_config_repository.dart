import 'package:sqflite/sqflite.dart';

/// app_config 表的读写仓储（年级、推送设置、绑定状态等）。
class AppConfigRepository {
  AppConfigRepository(this._db);

  final Database _db;

  Future<String?> get(String key) async {
    final rows = await _db.query(
      'app_config',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  Future<void> set(String key, String value) async {
    await _db.insert('app_config', {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
