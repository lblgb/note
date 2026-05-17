// 文件说明：提供 Flutter 客户端认证 API JSON 调用能力。
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../domain/auth_session.dart';

typedef AuthApiTransport = Future<AuthApiResponse> Function(AuthApiRequest);

// resolveAuthApiBaseUrl 解析认证 API 地址，支持编译期配置和平台默认值。
String resolveAuthApiBaseUrl({
  String configuredBaseUrl = const String.fromEnvironment('NOTE_API_BASE_URL'),
  bool? isAndroid,
}) {
  final trimmed = configuredBaseUrl.trim();
  if (trimmed.isNotEmpty) {
    return trimmed;
  }
  if (isAndroid ?? Platform.isAndroid) {
    return 'http://10.0.2.2:8080';
  }
  return 'http://127.0.0.1:8080';
}

// AuthApiRequest 表示认证 API 传输层请求。
class AuthApiRequest {
  const AuthApiRequest({
    required this.method,
    required this.path,
    required this.body,
    required this.headers,
  });

  final String method;
  final String path;
  final String body;
  final Map<String, String> headers;
}

// AuthApiResponse 表示认证 API 传输层响应。
class AuthApiResponse {
  const AuthApiResponse({required this.statusCode, required this.body});

  final int statusCode;
  final String body;
}

// AuthApiException 表示认证 API 可展示错误。
class AuthApiException implements Exception {
  const AuthApiException({required this.code, required this.message});

  final String code;
  final String message;

  // toString 返回便于日志查看的错误文本。
  @override
  String toString() => 'AuthApiException($code, $message)';
}

// AuthApiClient 调用服务端注册、登录和退出接口。
class AuthApiClient {
  AuthApiClient({String? baseUrl, AuthApiTransport? transport})
    : baseUrl = baseUrl ?? resolveAuthApiBaseUrl(),
      _transport = transport;

  final String baseUrl;
  final AuthApiTransport? _transport;

  // register 注册账号并返回认证会话。
  Future<AuthSession> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final response = await _post('/api/auth/register', {
      'email': email,
      'password': password,
      'displayName': displayName,
    });
    return _parseSession(response);
  }

  // login 登录账号并返回认证会话。
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final response = await _post('/api/auth/login', {
      'email': email,
      'password': password,
    });
    return _parseSession(response);
  }

  // logout 请求服务端注销刷新令牌。
  Future<void> logout(String refreshToken) async {
    await _post('/api/auth/logout', {'refreshToken': refreshToken});
  }

  // registerDevice 登记当前设备并返回服务端设备信息。
  Future<AuthDevice> registerDevice({
    required String accessToken,
    required String deviceName,
    required String platform,
  }) async {
    final response = await _post('/api/devices/register', {
      'deviceName': deviceName,
      'platform': platform,
    }, accessToken: accessToken);
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, Object?> ||
        decoded['device'] is! Map<String, Object?>) {
      throw const AuthApiException(
        code: 'invalid_response',
        message: '请求失败，请稍后重试',
      );
    }
    return AuthDevice.fromJson(decoded['device'] as Map<String, Object?>);
  }

  // _post 发送认证 API POST JSON 请求。
  Future<AuthApiResponse> _post(
    String path,
    Map<String, Object?> body, {
    String? accessToken,
  }) async {
    final headers = <String, String>{
      'content-type': 'application/json; charset=utf-8',
      if (accessToken != null) 'authorization': 'Bearer $accessToken',
    };
    final request = AuthApiRequest(
      method: 'POST',
      path: path,
      body: jsonEncode(body),
      headers: headers,
    );

    try {
      final response = _transport == null
          ? await _sendWithHttpClient(request)
          : await _transport(request);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw _parseError(response);
      }
      return response;
    } on AuthApiException {
      rethrow;
    } on SocketException {
      throw const AuthApiException(
        code: 'network_error',
        message: '无法连接服务器，请检查 API 地址或服务状态',
      );
    } on TimeoutException {
      throw const AuthApiException(
        code: 'network_error',
        message: '无法连接服务器，请检查 API 地址或服务状态',
      );
    } on IOException {
      throw const AuthApiException(
        code: 'network_error',
        message: '无法连接服务器，请检查 API 地址或服务状态',
      );
    }
  }

  // _sendWithHttpClient 使用 dart:io 发送真实 HTTP 请求。
  Future<AuthApiResponse> _sendWithHttpClient(AuthApiRequest request) async {
    final client = HttpClient();
    try {
      final uri = Uri.parse(baseUrl).resolve(request.path);
      final httpRequest = await client
          .openUrl(request.method, uri)
          .timeout(const Duration(seconds: 10));
      for (final header in request.headers.entries) {
        httpRequest.headers.set(header.key, header.value);
      }
      httpRequest.write(request.body);
      final httpResponse = await httpRequest.close().timeout(
        const Duration(seconds: 10),
      );
      final responseBody = await utf8.decoder.bind(httpResponse).join();
      return AuthApiResponse(
        statusCode: httpResponse.statusCode,
        body: responseBody,
      );
    } finally {
      client.close(force: true);
    }
  }

  // _parseSession 从成功响应中解析认证会话。
  AuthSession _parseSession(AuthApiResponse response) {
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, Object?>) {
      throw const AuthApiException(
        code: 'invalid_response',
        message: '请求失败，请稍后重试',
      );
    }
    return AuthSession.fromJson(decoded);
  }

  // _parseError 从服务端错误响应中解析可展示错误。
  AuthApiException _parseError(AuthApiResponse response) {
    try {
      final decoded = jsonDecode(response.body);
      final error = decoded is Map<String, Object?> ? decoded['error'] : null;
      if (error is Map<String, Object?>) {
        return AuthApiException(
          code: error['code'] as String? ?? 'request_failed',
          message: error['message'] as String? ?? '请求失败，请稍后重试',
        );
      }
    } on FormatException {
      // 使用默认错误。
    }
    return const AuthApiException(
      code: 'request_failed',
      message: '请求失败，请稍后重试',
    );
  }
}
