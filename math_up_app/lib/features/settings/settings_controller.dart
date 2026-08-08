import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/application/notification_service.dart';
import '../../core/infrastructure/http_sync_service.dart';

/// 设置页状态控制器：绑定码、推送设置、状态轮询。
class SettingsController extends ChangeNotifier {
  SettingsController({
    required Database db,
    HttpSyncService? sync,
    this.pollInterval = const Duration(seconds: 30),
  }) : service = NotificationService(db: db, sync: sync);

  final NotificationService service;
  final Duration pollInterval;

  bool loading = true;
  String? error;
  String serverUrl = '';
  bool dailyEnabled = true;
  String pushTime = '21:30';
  String? bindCode;
  String? bindCodeExpiresAt;
  bool bound = false;
  String? parentNick;
  String? lastPushAt;
  bool busy = false;
  bool loaded = false;

  Timer? _pollTimer;

  Future<void> load() async {
    if (loaded) {
      return;
    }
    loading = true;
    error = null;
    notifyListeners();
    try {
      serverUrl = await service.serverUrl();
      dailyEnabled = await service.dailyEnabled();
      pushTime = await service.pushTime();
      bindCode = await service.bindCode();
      bindCodeExpiresAt = await service.bindCodeExpiresAt();
      parentNick = await service.parentNick();
      lastPushAt = await service.lastPushAt();
      bound = parentNick?.isNotEmpty == true ||
          (await _readBoundFlag() == 'true');
      loading = false;
    } catch (e) {
      error = e.toString();
      loading = false;
    }
    loaded = true;
    notifyListeners();
  }

  Future<String?> _readBoundFlag() => service.boundFlag();

  Future<void> saveServerUrl(String value) async {
    await _runBusy(() async {
      await service.saveServerUrl(value);
      serverUrl = value.trim();
      bindCode = null;
      bindCodeExpiresAt = null;
    });
  }

  Future<void> setDailyEnabled(bool value) async {
    await _runBusy(() async {
      await service.setDailyEnabled(value);
      dailyEnabled = value;
    });
  }

  Future<void> setPushTime(String value) async {
    await _runBusy(() async {
      await service.setPushTime(value);
      pushTime = value;
    });
  }

  Future<void> requestBindCode() async {
    await _runBusy(() async {
      bindCode = await service.requestBindCode();
      bindCodeExpiresAt = await service.bindCodeExpiresAt();
    });
  }

  Future<void> confirmBind() async {
    await _runBusy(() async {
      final nick = await service.confirmBind();
      bound = true;
      parentNick = nick;
      _stopPolling();
    });
  }

  Future<void> refreshStatus() async {
    if (busy) {
      return;
    }
    try {
      final status = await service.fetchStatus();
      bound = status.bound;
      if (status.bound) {
        parentNick = await service.parentNick() ?? '家长';
        lastPushAt = status.lastPushAt;
        _stopPolling();
      }
      notifyListeners();
    } catch (_) {
      // 轮询失败静默，下次再试
    }
  }

  Future<void> unbind() async {
    await _runBusy(() async {
      await service.unbind();
      bound = false;
      parentNick = null;
      lastPushAt = null;
      bindCode = null;
      bindCodeExpiresAt = null;
    });
  }

  /// 未绑定时每 30 秒轮询一次绑定状态。
  void startPolling() {
    if (bound || serverUrl.isEmpty || _pollTimer != null) {
      return;
    }
    _pollTimer = Timer.periodic(pollInterval, (_) => refreshStatus());
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _runBusy(Future<void> Function() action) async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      await action();
    } catch (e) {
      error = e.toString();
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _stopPolling();
    super.dispose();
  }
}
