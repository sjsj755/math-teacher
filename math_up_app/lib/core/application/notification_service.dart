import 'dart:math';

import 'package:sqflite/sqflite.dart';

import '../infrastructure/app_config_repository.dart';
import '../infrastructure/http_sync_service.dart';

/// 家长通知用例：服务器地址、绑定码、状态轮询、解绑与推送设置。
class NotificationService {
  NotificationService({
    required Database db,
    HttpSyncService? sync,
  }) : this._internal(AppConfigRepository(db), sync);

  NotificationService._internal(this._config, this._sync);

  final AppConfigRepository _config;
  HttpSyncService? _sync;

  Future<HttpSyncService> _service() async {
    final cached = _sync;
    if (cached != null) {
      return cached;
    }
    final serverUrl = (await _config.get('server_url') ?? '').trim();
    if (serverUrl.isEmpty) {
      throw const SyncException('NO_SERVER_URL', '请先在设置页填写服务器地址');
    }
    return HttpSyncService(baseUrl: serverUrl);
  }

  Future<String> _deviceId() async {
    final existing = await _config.get('device_id');
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }
    final random = Random.secure();
    final id =
        'dev-${List.generate(16, (_) => random.nextInt(16).toRadixString(16)).join()}';
    await _config.set('device_id', id);
    return id;
  }

  Future<String> serverUrl() async {
    return (await _config.get('server_url') ?? '').trim();
  }

  Future<void> saveServerUrl(String value) async {
    await _config.set('server_url', value.trim());
    _sync = null; // 地址变更后重建客户端
  }

  Future<bool> dailyEnabled() async {
    return (await _config.get('daily_enabled') ?? 'true') == 'true';
  }

  Future<String?> boundFlag() async => _config.get('bound');

  Future<void> setDailyEnabled(bool value) async {
    await _config.set('daily_enabled', value ? 'true' : 'false');
  }

  Future<String> pushTime() async {
    return await _config.get('push_time') ?? '21:30';
  }

  Future<void> setPushTime(String value) async {
    await _config.set('push_time', value);
  }

  Future<String?> bindCode() async => _config.get('bind_code');

  Future<String?> bindCodeExpiresAt() async =>
      _config.get('bind_code_expires_at');

  Future<String?> parentNick() async => _config.get('parent_nick');

  Future<String?> lastPushAt() async => _config.get('last_push_at');

  /// 生成绑定码（24 小时有效）并本地保存。
  Future<String> requestBindCode() async {
    final service = await _service();
    final deviceId = await _deviceId();
    final info = await service.requestBindCode(deviceId);
    await _config.set('bind_code', info.bindCode);
    await _config.set('bind_code_expires_at', info.expiresAt);
    return info.bindCode;
  }

  /// 查询绑定与推送状态；绑定成功后保存家长昵称与最近推送时间。
  Future<BindStatus> fetchStatus() async {
    final service = await _service();
    final deviceId = await _deviceId();
    final status = await service.fetchStatus(deviceId);
    if (status.bound) {
      await _config.set('bound', 'true');
      if (status.lastPushAt != null) {
        await _config.set('last_push_at', status.lastPushAt!);
      }
    } else {
      await _config.set('bound', 'false');
    }
    return status;
  }

  /// 学生端确认绑定（家长已在 QQ 发送“绑定 绑定码”）。
  Future<String?> confirmBind() async {
    final service = await _service();
    final deviceId = await _deviceId();
    final code = await _config.get('bind_code');
    if (code == null || code.isEmpty) {
      throw const SyncException('NO_BIND_CODE', '请先生成绑定码');
    }
    final nick = await service.confirmBind(code, deviceId);
    await _config.set('bound', 'true');
    if (nick != null) {
      await _config.set('parent_nick', nick);
    }
    return nick;
  }

  /// 解绑并清理本地绑定状态。
  Future<void> unbind() async {
    final service = await _service();
    final deviceId = await _deviceId();
    await service.unbind(deviceId);
    await _config.set('bound', 'false');
    await _config.set('parent_nick', '');
    await _config.set('last_push_at', '');
    await _config.set('bind_code', '');
    await _config.set('bind_code_expires_at', '');
  }
}
