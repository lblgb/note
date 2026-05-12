// 文件说明：本地笔记读取和写入仓储接口。

import '../domain/folder.dart';
import '../domain/note.dart';

// NoteRepository 定义笔记浏览和编辑所需的数据能力。
abstract interface class NoteRepository {
  // listFolders 返回本地文件夹列表。
  List<Folder> listFolders();

  // listNotes 返回指定文件夹下的笔记列表。
  List<Note> listNotes(String folderId);

  // findNote 根据笔记 ID 查找笔记。
  Note? findNote(String noteId);

  // createNote 在指定文件夹下创建笔记。
  Note createNote({
    required String folderId,
    required String title,
    required String content,
  });

  // updateNote 更新已有笔记，目标不存在时返回 null。
  Note? updateNote({
    required String noteId,
    required String title,
    required String content,
  });
}
