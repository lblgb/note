// 文件说明：测试同步 API 客户端的请求、响应解析和错误映射。
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:note_client/features/sync/data/sync_api_client.dart';

// main 验证同步 API 客户端行为。
void main() {
  test('push 发送文件夹和笔记并携带访问令牌', () async {
    final requests = <SyncApiRequest>[];
    final client = SyncApiClient(
      baseUrl: 'http://localhost:8080',
      transport: (request) async {
        requests.add(request);
        return const SyncApiResponse(
          statusCode: 200,
          body:
              '{"serverVersion":2,"folders":[{"id":"fld_1","serverVersion":1}],'
              '"notes":[{"id":"note_1","serverVersion":2}]}',
        );
      },
    );

    final result = await client.push(
      accessToken: 'access',
      input: SyncPushInput(
        folders: [const SyncFolder(id: 'fld_1', name: '收件箱')],
        notes: [
          SyncNote(
            id: 'note_1',
            folderId: 'fld_1',
            title: '标题',
            body: '正文',
            updatedAt: DateTime(2026, 5, 17, 12, 0),
          ),
        ],
      ),
    );

    expect(requests.single.path, '/api/sync/push');
    expect(requests.single.headers['authorization'], 'Bearer access');
    expect(jsonDecode(requests.single.body)['notes'][0]['title'], '标题');
    expect(result.serverVersion, 2);
  });

  test('pull 拉取服务端同步数据', () async {
    final requests = <SyncApiRequest>[];
    final client = SyncApiClient(
      baseUrl: 'http://localhost:8080',
      transport: (request) async {
        requests.add(request);
        return const SyncApiResponse(
          statusCode: 200,
          body:
              '{"serverVersion":3,"folders":[{"id":"fld_1","name":"远端","updatedAt":1770000000000000000,"serverVersion":1}],'
              '"notes":[{"id":"note_1","folderId":"fld_1","title":"远端标题","body":"远端正文","updatedAt":1770000000000000001,"serverVersion":3}]}',
        );
      },
    );

    final result = await client.pull(accessToken: 'access', since: 0);

    expect(requests.single.path, '/api/sync/pull?since=0');
    expect(result.serverVersion, 3);
    expect(result.folders.single.name, '远端');
    expect(result.notes.single.title, '远端标题');
  });

  test('服务端错误会映射为 SyncApiException', () async {
    final client = SyncApiClient(
      transport: (request) async {
        return const SyncApiResponse(
          statusCode: 401,
          body: '{"error":{"code":"unauthorized","message":"未登录或令牌无效"}}',
        );
      },
    );

    await expectLater(
      client.pull(accessToken: 'bad', since: 0),
      throwsA(
        isA<SyncApiException>()
            .having((error) => error.code, 'code', 'unauthorized')
            .having((error) => error.message, 'message', '未登录或令牌无效'),
      ),
    );
  });

  test('网络错误会映射为可读同步错误', () async {
    final client = SyncApiClient(
      transport: (request) async {
        throw const SocketException('connection refused');
      },
    );

    await expectLater(
      client.pull(accessToken: 'access', since: 0),
      throwsA(
        isA<SyncApiException>().having(
          (error) => error.message,
          'message',
          '无法连接同步服务，请检查 API 地址或服务状态',
        ),
      ),
    );
  });
}
