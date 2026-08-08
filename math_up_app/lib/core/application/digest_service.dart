import 'dart:convert';
import 'dart:math';

import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';

import '../domain/models/digest.dart';
import '../infrastructure/app_config_repository.dart';
import '../infrastructure/http_sync_service.dart';

/// 日报摘要用例：从学习记录生成当日摘要 → 写 digest_queue → 有网自动上送。
///
/// 离线时摘要留在队列（synced=0），下次启动或练习完成后自动补传。
class DigestService {
  DigestService({
    required Database db,
    DateTime Function()? now,
    HttpSyncService Function(String baseUrl)? syncFactory,
  }) : this._internal(
         db,
         now ?? DateTime.now,
         syncFactory ?? ((baseUrl) => HttpSyncService(baseUrl: baseUrl)),
       );

  DigestService._internal(this._db, this._now, this._syncFactory);

  final Database _db;
  final DateTime Function() _now;
  final HttpSyncService Function(String baseUrl) _syncFactory;

  /// 依据当日 answer_record 生成摘要（不落库）。
  Future<DailyDigest> buildToday() async {
    final today = _dateOnly(_now());
    final dateText = _formatDate(today);
    final rows = await _db.rawQuery(
      'SELECT a.result, a.seconds, q.variant_group, q.knowledge_point '
      'FROM answer_record a LEFT JOIN question q ON q.id = a.question_id '
      'WHERE a.date = ?',
      [dateText],
    );

    final practiceCount = rows.length;
    final correctCount = rows
        .where((row) => (row['result'] as int? ?? 0) == 1)
        .length;
    final errorCount = practiceCount - correctCount;
    final totalSeconds = rows.fold<int>(
      0,
      (sum, row) => sum + (row['seconds'] as int? ?? 0),
    );
    final minutes = (totalSeconds / 60).round();

    final counts = <String, int>{};
    final names = <String, String>{};
    for (final row in rows) {
      if ((row['result'] as int? ?? 0) == 1) {
        continue;
      }
      final code = row['variant_group'] as String? ?? 'unknown';
      counts[code] = (counts[code] ?? 0) + 1;
      names[code] = row['knowledge_point'] as String? ?? code;
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(3).toList();

    return DailyDigest(
      date: today,
      practiceCount: practiceCount,
      correctCount: correctCount,
      errorCount: errorCount,
      minutes: minutes,
      weakPoints: [for (final entry in top) entry.key],
      weakPointNames: [for (final entry in top) names[entry.key] ?? entry.key],
      streakDays: await _streakDays(today),
    );
  }

  /// 生成并覆盖写入当日摘要队列（同日只保留一份，未同步标记）。
  Future<void> generateToday() async {
    final digest = await buildToday();
    final dateText = _formatDate(digest.date);
    final payload = jsonEncode(digest.toJson());
    final existing = await _db.query(
      'digest_queue',
      where: 'date = ?',
      whereArgs: [dateText],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      await _db.update(
        'digest_queue',
        {'payload': payload, 'synced': 0},
        where: 'date = ?',
        whereArgs: [dateText],
      );
    } else {
      await _db.insert('digest_queue', {
        'date': dateText,
        'payload': payload,
        'synced': 0,
      });
    }
  }

  /// 上送所有未同步摘要；返回成功条数（失败静默保留队列）。
  Future<int> syncPending() async {
    final config = AppConfigRepository(_db);
    final serverUrl = (await config.get('server_url') ?? '').trim();
    if (serverUrl.isEmpty) {
      return 0;
    }
    final deviceId = await _ensureDeviceId(config);
    final service = _syncFactory(serverUrl);
    final rows = await _db.query(
      'digest_queue',
      where: 'synced = 0',
      orderBy: 'date ASC',
    );
    var synced = 0;
    for (final row in rows) {
      try {
        final payload = jsonDecode(row['payload'] as String)
            as Map<String, dynamic>;
        final digest = DailyDigest.fromJson(payload);
        if (await service.uploadDailyDigest(digest, deviceId: deviceId)) {
          await _db.update(
            'digest_queue',
            {'synced': 1},
            where: 'id = ?',
            whereArgs: [row['id']],
          );
          synced++;
        }
      } catch (_) {
        // 网络不可用或服务端拒绝：保留未同步，下次重试
      }
    }
    return synced;
  }

  /// 生成当日摘要并立即尝试上送（启动与练习完成后调用）。
  Future<void> generateTodayAndSync() async {
    await generateToday();
    await syncPending();
  }

  Future<int> _streakDays(DateTime today) async {
    final rows = await _db.query(
      'answer_record',
      columns: ['date'],
      distinct: true,
    );
    final dates = <DateTime>{};
    for (final row in rows) {
      final parsed = DateTime.tryParse(row['date'] as String? ?? '');
      if (parsed != null) {
        dates.add(_dateOnly(parsed));
      }
    }
    var streak = 0;
    var cursor = today;
    if (!dates.contains(cursor)) {
      // 今天尚无记录：从昨天开始计算连续天数
      cursor = cursor.subtract(const Duration(days: 1));
    }
    while (dates.contains(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  Future<String> _ensureDeviceId(AppConfigRepository config) async {
    final existing = await config.get('device_id');
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }
    final random = Random.secure();
    final id =
        'dev-${List.generate(16, (_) => random.nextInt(16).toRadixString(16)).join()}';
    await config.set('device_id', id);
    return id;
  }

  DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  String _formatDate(DateTime value) => DateFormat('yyyy-MM-dd').format(value);
}
