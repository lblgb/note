// 文件说明：测试 Flutter 认证 API 客户端的响应解析和错误映射。
import 'dart:convert';
import 'dart:io';

import 'package:note_client/features/auth/data/auth_api_client.dart';
import 'package:test/test.dart';

// main 验证认证 API 客户端的请求和响应行为。
void main() {
  test('resolveAuthApiBaseUrl 优先使用 dart-define 配置地址', () {
    final url = resolveAuthApiBaseUrl(
      configuredBaseUrl: 'http://192.168.1.20:8080',
      isAndroid: false,
    );

    expect(url, 'http://192.168.1.20:8080');
  });

  test('resolveAuthApiBaseUrl 为 Android 模拟器默认使用宿主机地址', () {
    final url = resolveAuthApiBaseUrl(configuredBaseUrl: '', isAndroid: true);

    expect(url, 'http://10.0.2.2:8080');
  });

  test('resolveAuthApiBaseUrl 为桌面默认使用本机地址', () {
    final url = resolveAuthApiBaseUrl(configuredBaseUrl: '', isAndroid: false);

    expect(url, 'http://127.0.0.1:8080');
  });

  test('login 发送登录请求并解析会话', () async {
    final requests = <AuthApiRequest>[];
    final client = AuthApiClient(
      baseUrl: 'http://localhost:8080',
      transport: (request) async {
        requests.add(request);
        return const AuthApiResponse(
          statusCode: 200,
          body:
              '{"user":{"id":"usr_1","email":"user@example.com","displayName":"用户"},'
              '"accessToken":"access","refreshToken":"refresh"}',
        );
      },
    );

    final session = await client.login(
      email: 'user@example.com',
      password: 'pass123456',
    );

    expect(requests.single.path, '/api/auth/login');
    expect(requests.single.method, 'POST');
    expect(jsonDecode(requests.single.body)['email'], 'user@example.com');
    expect(session.user.id, 'usr_1');
    expect(session.accessToken, 'access');
    expect(session.refreshToken, 'refresh');
  });

  test('register 发送注册请求并解析会话', () async {
    final requests = <AuthApiRequest>[];
    final client = AuthApiClient(
      baseUrl: 'http://localhost:8080',
      transport: (request) async {
        requests.add(request);
        return const AuthApiResponse(
          statusCode: 201,
          body:
              '{"user":{"id":"usr_2","email":"new@example.com","displayName":"新用户"},'
              '"accessToken":"new-access","refreshToken":"new-refresh"}',
        );
      },
    );

    final session = await client.register(
      email: 'new@example.com',
      password: 'pass123456',
      displayName: '新用户',
    );

    expect(requests.single.path, '/api/auth/register');
    expect(jsonDecode(requests.single.body)['displayName'], '新用户');
    expect(session.user.email, 'new@example.com');
    expect(session.accessToken, 'new-access');
  });

  test('服务端 JSON 错误会映射为 AuthApiException', () async {
    final client = AuthApiClient(
      baseUrl: 'http://localhost:8080',
      transport: (request) async {
        return const AuthApiResponse(
          statusCode: 401,
          body: '{"error":{"code":"invalid_credentials","message":"账号或凭据无效"}}',
        );
      },
    );

    await expectLater(
      client.login(email: 'user@example.com', password: 'bad-password'),
      throwsA(
        isA<AuthApiException>()
            .having((error) => error.code, 'code', 'invalid_credentials')
            .having((error) => error.message, 'message', '账号或凭据无效'),
      ),
    );
  });

  test('网络错误会映射为可读错误', () async {
    final client = AuthApiClient(
      baseUrl: 'http://localhost:8080',
      transport: (request) async {
        throw const SocketException('connection refused');
      },
    );

    await expectLater(
      client.login(email: 'user@example.com', password: 'pass123456'),
      throwsA(
        isA<AuthApiException>().having(
          (error) => error.message,
          'message',
          '无法连接服务器，请检查 API 地址或服务状态',
        ),
      ),
    );
  });

  test('logout 发送刷新令牌并接受成功响应', () async {
    final requests = <AuthApiRequest>[];
    final client = AuthApiClient(
      baseUrl: 'http://localhost:8080',
      transport: (request) async {
        requests.add(request);
        return const AuthApiResponse(statusCode: 200, body: '{"status":"ok"}');
      },
    );

    await client.logout('refresh-token');

    expect(requests.single.path, '/api/auth/logout');
    expect(jsonDecode(requests.single.body)['refreshToken'], 'refresh-token');
  });

  test('registerDevice 携带访问令牌登记当前设备', () async {
    final requests = <AuthApiRequest>[];
    final client = AuthApiClient(
      baseUrl: 'http://localhost:8080',
      transport: (request) async {
        requests.add(request);
        return const AuthApiResponse(
          statusCode: 201,
          body:
              '{"device":{"id":"dev_1","userId":"usr_1",'
              '"deviceName":"Windows 设备","platform":"windows"}}',
        );
      },
    );

    final device = await client.registerDevice(
      accessToken: 'access-token',
      deviceName: 'Windows 设备',
      platform: 'windows',
    );

    expect(requests.single.path, '/api/devices/register');
    expect(requests.single.headers['authorization'], 'Bearer access-token');
    expect(jsonDecode(requests.single.body)['platform'], 'windows');
    expect(device.id, 'dev_1');
    expect(device.platform, 'windows');
  });
}
