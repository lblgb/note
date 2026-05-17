// 文件说明：协调本地笔记仓库和服务端同步 API。
import '../../notes/data/note_repository.dart';
import '../../notes/domain/folder.dart';
import '../../notes/domain/note.dart';
import '../data/sync_api_client.dart';

typedef NoteSyncAction =
    Future<NoteSyncResult> Function(
      NoteRepository repository,
      String accessToken,
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
  const NoteSyncService({required this.repository, required this.apiClient});

  final NoteRepository repository;
  final SyncApiClient apiClient;

  // syncNow 先推送本地全量状态，再拉取服务端状态写回本地。
  Future<NoteSyncResult> syncNow({required String accessToken}) async {
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
    final pulled = await apiClient.pull(accessToken: accessToken, since: 0);
    for (final folder in pulled.folders.where((folder) => !folder.deleted)) {
      repository.upsertFolder(_folderFromSync(folder));
    }
    for (final note in pulled.notes.where((note) => !note.deleted)) {
      repository.upsertNote(_noteFromSync(note));
    }
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
