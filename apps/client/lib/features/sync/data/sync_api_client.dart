// 文件说明：提供文件夹和笔记同步 API JSON 调用能力。
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../auth/data/auth_api_client.dart';

typedef SyncApiTransport = Future<SyncApiResponse> Function(SyncApiRequest);

// SyncApiRequest 表示同步 API 传输层请求。
class SyncApiRequest {
  const SyncApiRequest({
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

// SyncApiResponse 表示同步 API 传输层响应。
class SyncApiResponse {
  const SyncApiResponse({required this.statusCode, required this.body});

  final int statusCode;
  final String body;
}

// SyncApiException 表示同步 API 可展示错误。
class SyncApiException implements Exception {
  const SyncApiException({required this.code, required this.message});

  final String code;
  final String message;

  // toString 返回便于日志查看的错误文本。
  @override
  String toString() => 'SyncApiException($code, $message)';
}

// SyncFolder 表示服务端同步文件夹。
class SyncFolder {
  const SyncFolder({
    required this.id,
    required this.name,
    this.parentId = '',
    this.deleted = false,
    this.updatedAt,
    this.serverVersion = 0,
  });

  final String id;
  final String name;
  final String parentId;
  final bool deleted;
  final DateTime? updatedAt;
  final int serverVersion;

  // toJson 转换为同步 API JSON。
  Map<String, Object?> toJson() {
    return {
      'id': id,
      'name': name,
      'parentId': parentId,
      'deleted': deleted,
      'updatedAt': updatedAt?.toUtc().microsecondsSinceEpoch == null
          ? 0
          : updatedAt!.toUtc().microsecondsSinceEpoch * 1000,
    };
  }

  // fromJson 从同步 API JSON 创建文件夹。
  factory SyncFolder.fromJson(Map<String, Object?> json) {
    return SyncFolder(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      parentId: json['parentId'] as String? ?? '',
      deleted: json['deleted'] as bool? ?? false,
      updatedAt: _dateTimeFromUnixNano(json['updatedAt']),
      serverVersion: (json['serverVersion'] as num?)?.toInt() ?? 0,
    );
  }
}

// SyncNote 表示服务端同步笔记。
class SyncNote {
  const SyncNote({
    required this.id,
    required this.folderId,
    required this.title,
    required this.body,
    this.deleted = false,
    this.updatedAt,
    this.serverVersion = 0,
  });

  final String id;
  final String folderId;
  final String title;
  final String body;
  final bool deleted;
  final DateTime? updatedAt;
  final int serverVersion;

  // toJson 转换为同步 API JSON。
  Map<String, Object?> toJson() {
    return {
      'id': id,
      'folderId': folderId,
      'title': title,
      'body': body,
      'deleted': deleted,
      'updatedAt': updatedAt?.toUtc().microsecondsSinceEpoch == null
          ? 0
          : updatedAt!.toUtc().microsecondsSinceEpoch * 1000,
    };
  }

  // fromJson 从同步 API JSON 创建笔记。
  factory SyncNote.fromJson(Map<String, Object?> json) {
    return SyncNote(
      id: json['id'] as String? ?? '',
      folderId: json['folderId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      deleted: json['deleted'] as bool? ?? false,
      updatedAt: _dateTimeFromUnixNano(json['updatedAt']),
      serverVersion: (json['serverVersion'] as num?)?.toInt() ?? 0,
    );
  }
}

// SyncPushInput 表示同步推送请求。
class SyncPushInput {
  const SyncPushInput({required this.folders, required this.notes});

  final List<SyncFolder> folders;
  final List<SyncNote> notes;

  // toJson 转换为同步 API JSON。
  Map<String, Object?> toJson() {
    return {
      'folders': [for (final folder in folders) folder.toJson()],
      'notes': [for (final note in notes) note.toJson()],
    };
  }
}

// SyncVersion 表示同步实体服务端版本。
class SyncVersion {
  const SyncVersion({required this.id, required this.serverVersion});

  final String id;
  final int serverVersion;

  // fromJson 从同步 API JSON 创建版本结果。
  factory SyncVersion.fromJson(Map<String, Object?> json) {
    return SyncVersion(
      id: json['id'] as String? ?? '',
      serverVersion: (json['serverVersion'] as num?)?.toInt() ?? 0,
    );
  }
}

// SyncPushResult 表示同步推送响应。
class SyncPushResult {
  const SyncPushResult({
    required this.serverVersion,
    required this.folders,
    required this.notes,
  });

  final int serverVersion;
  final List<SyncVersion> folders;
  final List<SyncVersion> notes;

  // fromJson 从同步 API JSON 创建推送响应。
  factory SyncPushResult.fromJson(Map<String, Object?> json) {
    return SyncPushResult(
      serverVersion: (json['serverVersion'] as num?)?.toInt() ?? 0,
      folders: _parseVersions(json['folders']),
      notes: _parseVersions(json['notes']),
    );
  }
}

// SyncPullResult 表示同步拉取响应。
class SyncPullResult {
  const SyncPullResult({
    required this.serverVersion,
    required this.folders,
    required this.notes,
  });

  final int serverVersion;
  final List<SyncFolder> folders;
  final List<SyncNote> notes;

  // fromJson 从同步 API JSON 创建拉取响应。
  factory SyncPullResult.fromJson(Map<String, Object?> json) {
    return SyncPullResult(
      serverVersion: (json['serverVersion'] as num?)?.toInt() ?? 0,
      folders: _parseFolders(json['folders']),
      notes: _parseNotes(json['notes']),
    );
  }
}

// SyncApiClient 调用服务端同步接口。
class SyncApiClient {
  SyncApiClient({String? baseUrl, SyncApiTransport? transport})
    : baseUrl = baseUrl ?? resolveAuthApiBaseUrl(),
      _transport = transport;

  final String baseUrl;
  final SyncApiTransport? _transport;

  // push 推送本地文件夹和笔记。
  Future<SyncPushResult> push({
    required String accessToken,
    required SyncPushInput input,
  }) async {
    final response = await _send(
      SyncApiRequest(
        method: 'POST',
        path: '/api/sync/push',
        body: jsonEncode(input.toJson()),
        headers: _headers(accessToken),
      ),
    );
    return SyncPushResult.fromJson(_decodeObject(response));
  }

  // pull 拉取远端文件夹和笔记。
  Future<SyncPullResult> pull({
    required String accessToken,
    required int since,
  }) async {
    final response = await _send(
      SyncApiRequest(
        method: 'GET',
        path: '/api/sync/pull?since=$since',
        body: '',
        headers: _headers(accessToken),
      ),
    );
    return SyncPullResult.fromJson(_decodeObject(response));
  }

  // _send 发送同步 API 请求并处理错误。
  Future<SyncApiResponse> _send(SyncApiRequest request) async {
    try {
      final response = _transport == null
          ? await _sendWithHttpClient(request)
          : await _transport(request);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw _parseError(response);
      }
      return response;
    } on SyncApiException {
      rethrow;
    } on SocketException {
      throw const SyncApiException(
        code: 'network_error',
        message: '无法连接同步服务，请检查 API 地址或服务状态',
      );
    } on TimeoutException {
      throw const SyncApiException(
        code: 'network_error',
        message: '无法连接同步服务，请检查 API 地址或服务状态',
      );
    } on IOException {
      throw const SyncApiException(
        code: 'network_error',
        message: '无法连接同步服务，请检查 API 地址或服务状态',
      );
    }
  }

  // _sendWithHttpClient 使用 dart:io 发送真实 HTTP 请求。
  Future<SyncApiResponse> _sendWithHttpClient(SyncApiRequest request) async {
    final client = HttpClient();
    try {
      final uri = Uri.parse(baseUrl).resolve(request.path);
      final httpRequest = await client
          .openUrl(request.method, uri)
          .timeout(const Duration(seconds: 10));
      for (final header in request.headers.entries) {
        httpRequest.headers.set(header.key, header.value);
      }
      if (request.body.isNotEmpty) {
        httpRequest.write(request.body);
      }
      final httpResponse = await httpRequest.close().timeout(
        const Duration(seconds: 10),
      );
      final body = await utf8.decoder.bind(httpResponse).join();
      return SyncApiResponse(statusCode: httpResponse.statusCode, body: body);
    } finally {
      client.close(force: true);
    }
  }

  // _headers 构建同步 API 请求头。
  Map<String, String> _headers(String accessToken) {
    return {
      'content-type': 'application/json; charset=utf-8',
      'authorization': 'Bearer $accessToken',
    };
  }

  // _decodeObject 解析 JSON 对象响应。
  Map<String, Object?> _decodeObject(SyncApiResponse response) {
    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, Object?>) {
      return decoded;
    }
    throw const SyncApiException(code: 'invalid_response', message: '同步响应无效');
  }

  // _parseError 从服务端错误响应中解析可展示错误。
  SyncApiException _parseError(SyncApiResponse response) {
    try {
      final decoded = jsonDecode(response.body);
      final error = decoded is Map<String, Object?> ? decoded['error'] : null;
      if (error is Map<String, Object?>) {
        return SyncApiException(
          code: error['code'] as String? ?? 'sync_failed',
          message: error['message'] as String? ?? '同步失败，请稍后重试',
        );
      }
    } on FormatException {
      // 使用默认错误。
    }
    return const SyncApiException(code: 'sync_failed', message: '同步失败，请稍后重试');
  }
}

// _parseVersions 解析服务端版本数组。
List<SyncVersion> _parseVersions(Object? value) {
  if (value is! List) {
    return const [];
  }
  return [
    for (final item in value)
      if (item is Map<String, Object?>) SyncVersion.fromJson(item),
  ];
}

// _parseFolders 解析服务端文件夹数组。
List<SyncFolder> _parseFolders(Object? value) {
  if (value is! List) {
    return const [];
  }
  return [
    for (final item in value)
      if (item is Map<String, Object?>) SyncFolder.fromJson(item),
  ];
}

// _parseNotes 解析服务端笔记数组。
List<SyncNote> _parseNotes(Object? value) {
  if (value is! List) {
    return const [];
  }
  return [
    for (final item in value)
      if (item is Map<String, Object?>) SyncNote.fromJson(item),
  ];
}

// _dateTimeFromUnixNano 将 Unix 纳秒转换为 UTC 时间。
DateTime? _dateTimeFromUnixNano(Object? value) {
  final nano = (value as num?)?.toInt();
  if (nano == null || nano == 0) {
    return null;
  }
  return DateTime.fromMicrosecondsSinceEpoch(nano ~/ 1000, isUtc: true);
}
