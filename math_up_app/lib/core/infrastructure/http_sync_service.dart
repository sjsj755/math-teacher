import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/models/digest.dart';

/// 同步接口业务错误（携带服务端业务错误码）。
class SyncException implements Exception {
  const SyncException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => '$code: $message';
}

/// 绑定码信息。
class BindCodeInfo {
  const BindCodeInfo({required this.bindCode, required this.expiresAt});

  final String bindCode;
  final String expiresAt;
}

/// 绑定与推送状态（GET /api/v1/status）。
class BindStatus {
  const BindStatus({
    required this.bound,
    this.lastPushAt,
    required this.dailyEnabled,
    required this.pushTime,
  });

  final bool bound;
  final String? lastPushAt;
  final bool dailyEnabled;
  final String pushTime;

  factory BindStatus.fromJson(Map<String, dynamic> json) {
    return BindStatus(
      bound: json['bound'] as bool? ?? false,
      lastPushAt: json['last_push_at'] as String?,
      dailyEnabled: json['daily_enabled'] as bool? ?? true,
      pushTime: json['push_time'] as String? ?? '21:30',
    );
  }
}

/// 通知服务 HTTP 客户端：摘要上送、绑定码、状态、解绑。
class HttpSyncService {
  HttpSyncService({required this.baseUrl, http.Client? client})
    : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  static const Duration _timeout = Duration(seconds: 8);

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  Map<String, String> get _headers => const {
    'Content-Type': 'application/json; charset=utf-8',
  };

  SyncException _error(http.Response response) {
    String code = 'HTTP_${response.statusCode}';
    String message = response.body;
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final detail = body['detail'];
      if (detail is Map<String, dynamic>) {
        code = detail['code'] as String? ?? code;
        message = detail['message'] as String? ?? message;
      }
    } catch (_) {
      // 非 JSON 错误体，保留原文
    }
    return SyncException(code, message);
  }

  /// 上送日报摘要；成功返回 true。
  Future<bool> uploadDailyDigest(
    DailyDigest digest, {
    required String deviceId,
  }) async {
    final response = await _client
        .post(
          _uri('/daily-digest'),
          headers: _headers,
          body: jsonEncode({...digest.toJson(), 'device_id': deviceId}),
        )
        .timeout(_timeout);
    if (response.statusCode == 200) {
      return true;
    }
    throw _error(response);
  }

  /// 生成绑定码（24 小时有效）。
  Future<BindCodeInfo> requestBindCode(String deviceId) async {
    final response = await _client
        .post(
          _uri('/bind-code'),
          headers: _headers,
          body: jsonEncode({'device_id': deviceId}),
        )
        .timeout(_timeout);
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return BindCodeInfo(
        bindCode: body['bind_code'] as String,
        expiresAt: body['expires_at'] as String? ?? '',
      );
    }
    throw _error(response);
  }

  /// 查询绑定与推送状态。
  Future<BindStatus> fetchStatus(String deviceId) async {
    final uri = _uri('/status').replace(
      queryParameters: {'device_id': deviceId},
    );
    final response = await _client.get(uri).timeout(_timeout);
    if (response.statusCode == 200) {
      return BindStatus.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }
    throw _error(response);
  }

  /// 学生端确认绑定，返回家长昵称。
  Future<String?> confirmBind(String bindCode, String deviceId) async {
    final response = await _client
        .post(
          _uri('/bind'),
          headers: _headers,
          body: jsonEncode({'bind_code': bindCode, 'device_id': deviceId}),
        )
        .timeout(_timeout);
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return body['parent_nick'] as String?;
    }
    throw _error(response);
  }

  /// 解绑。
  Future<void> unbind(String deviceId) async {
    final response = await _client
        .post(
          _uri('/unbind'),
          headers: _headers,
          body: jsonEncode({'device_id': deviceId}),
        )
        .timeout(_timeout);
    if (response.statusCode != 200) {
      throw _error(response);
    }
  }
}
