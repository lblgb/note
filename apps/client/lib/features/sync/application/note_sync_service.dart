// 文件说明：协调本地笔记仓库和服务端同步 API。
import '../../notes/data/note_repository.dart';
import '../../notes/domain/folder.dart';
import '../../notes/domain/note.dart';
import '../data/sync_api_client.dart';
import '../data/sync_cursor_store.dart';

typedef NoteSyncAction =
    Future<NoteSyncResult> Function(
      NoteRepository repository,
      String accessToken,
    );

typedef RefreshingNoteSyncAction =
    Future<NoteSyncResult> Function(
      NoteRepository repository,
      Future<String> Function() accessTokenProvider,
    );

// NoteSyncResult 表示一次手动同步的结果。
class NoteSyncResult {
  const NoteSyncResult({
    required this.serverVersion,
    required this.folderCount,
    required this.noteCount,
  });

  final int serverVersion;
  final int folderCount;
  final int noteCount;
}

// NoteSyncService 执行本地笔记和服务端之间的手动同步。
class NoteSyncService {
  const NoteSyncService({
    required this.repository,
    required this.apiClient,
    required this.cursorStore,
  });

  final NoteRepository repository;
  final SyncApiClient apiClient;
  final SyncCursorStore cursorStore;

  // syncNow 使用固定访问令牌执行同步。
  Future<NoteSyncResult> syncNow({required String accessToken}) async {
    return syncNowWithRefresh(accessTokenProvider: () async => accessToken);
  }

  // syncNowWithRefresh 支持访问令牌失效后刷新并重试一次同步。
  Future<NoteSyncResult> syncNowWithRefresh({
    required Future<String> Function() accessTokenProvider,
  }) async {
    try {
      return await _syncOnce(accessToken: await accessTokenProvider());
    } on SyncApiException catch (error) {
      if (!_isUnauthorized(error)) {
        rethrow;
      }
      return _syncOnce(accessToken: await accessTokenProvider());
    }
  }

  // _syncOnce 先推送本地全量状态，再拉取服务端状态写回本地。
  Future<NoteSyncResult> _syncOnce({required String accessToken}) async {
    final since = await cursorStore.load();
    await apiClient.push(
      accessToken: accessToken,
      input: SyncPushInput(
        folders: [
          for (final folder in repository.listFolders()) _folderToSync(folder),
        ],
        notes: [
          for (final note in repository.listAllNotes()) _noteToSync(note),
        ],
      ),
    );
    final pulled = await apiClient.pull(accessToken: accessToken, since: since);
    for (final folder in pulled.folders.where((folder) => !folder.deleted)) {
      repository.upsertFolder(_folderFromSync(folder));
    }
    for (final note in pulled.notes.where((note) => !note.deleted)) {
      repository.upsertNote(_noteFromSync(note));
    }
    await cursorStore.save(pulled.serverVersion);
    return NoteSyncResult(
      serverVersion: pulled.serverVersion,
      folderCount: pulled.folders.length,
      noteCount: pulled.notes.length,
    );
  }

  // _folderToSync 将本地文件夹转换为同步文件夹。
  SyncFolder _folderToSync(Folder folder) {
    return SyncFolder(id: folder.id, name: folder.name);
  }

  // _noteToSync 将本地笔记转换为同步笔记。
  SyncNote _noteToSync(Note note) {
    return SyncNote(
      id: note.id,
      folderId: note.folderId,
      title: note.title,
      body: note.content,
      updatedAt: note.updatedAt,
    );
  }

  // _folderFromSync 将同步文件夹转换为本地文件夹。
  Folder _folderFromSync(SyncFolder folder) {
    return Folder(id: folder.id, name: folder.name);
  }

  // _noteFromSync 将同步笔记转换为本地笔记。
  Note _noteFromSync(SyncNote note) {
    return Note(
      id: note.id,
      folderId: note.folderId,
      title: note.title,
      content: note.body,
      updatedAt: note.updatedAt ?? DateTime.now().toUtc(),
    );
  }
}

// _isUnauthorized 判断同步错误是否表示访问令牌不可用。
bool _isUnauthorized(SyncApiException error) {
  return error.code == 'unauthorized' || error.code == 'invalid_credentials';
}
