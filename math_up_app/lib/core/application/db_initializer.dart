import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../db/database.dart';
import '../infrastructure/question_importer.dart';
import 'digest_service.dart';

/// 数据库初始化状态。
enum DbInitState { initializing, success, failure }

/// 应用启动时的数据层初始化用例：打开数据库 → 迁移 → 导入题库。
class DbInitController extends ChangeNotifier {
  DbInitState state = DbInitState.initializing;
  ImportResult? result;
  String? error;

  Database? _db;

  /// 已打开的数据库（后续阶段供仓储复用）。
  Database? get database => _db;

  Future<void> run() async {
    state = DbInitState.initializing;
    result = null;
    error = null;
    notifyListeners();
    try {
      final db = await AppDatabase.open();
      _db = db;
      result = await QuestionImporter(db).importFromAssets();
      state = DbInitState.success;
      // 启动后台生成当日摘要并补传离线队列；失败不影响初始化状态。
      try {
        await DigestService(db: db).generateTodayAndSync();
      } catch (_) {
        // 网络不可用或服务未配置：保留本地队列，下次重试
      }
    } catch (e) {
      error = e.toString();
      state = DbInitState.failure;
    }
    notifyListeners();
  }
}
