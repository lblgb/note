// 文件说明：测试笔记同步应用服务的本地和远端数据转换。
import 'package:flutter_test/flutter_test.dart';
import 'package:note_client/features/notes/data/in_memory_note_repository.dart';
import 'package:note_client/features/sync/application/note_sync_service.dart';
import 'package:note_client/features/sync/data/sync_api_client.dart';

// main 验证手动同步服务行为。
void main() {
  test('syncNow 推送本地数据并写回远端拉取结果', () async {
    final repository = InMemoryNoteRepository();
    final requests = <SyncApiRequest>[];
    final apiClient = SyncApiClient(
      transport: (request) async {
        requests.add(request);
        if (request.path == '/api/sync/push') {
          return const SyncApiResponse(
            statusCode: 200,
            body: '{"serverVersion":2,"folders":[],"notes":[]}',
          );
        }
        return const SyncApiResponse(
          statusCode: 200,
          body:
              '{"serverVersion":3,"folders":[{"id":"folder-remote","name":"远端文件夹","updatedAt":1770000000000000000,"serverVersion":2}],'
              '"notes":[{"id":"note-remote","folderId":"folder-remote","title":"远端标题","body":"远端正文","updatedAt":1770000000000000001,"serverVersion":3}]}',
        );
      },
    );
    final service = NoteSyncService(
      repository: repository,
      apiClient: apiClient,
    );

    final result = await service.syncNow(accessToken: 'access');

    expect(result.serverVersion, 3);
    expect(requests.first.path, '/api/sync/push');
    expect(requests.last.path, '/api/sync/pull?since=0');
    expect(
      repository.listFolders().map((folder) => folder.name),
      contains('远端文件夹'),
    );
    expect(repository.findNote('note-remote')?.title, '远端标题');
    expect(repository.findNote('note-remote')?.content, '远端正文');
  });
}
