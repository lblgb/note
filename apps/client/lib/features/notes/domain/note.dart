// 文件说明：笔记领域模型。

// Note 表示客户端本地笔记。
class Note {
  const Note({
    required this.id,
    required this.folderId,
    required this.title,
    required this.content,
    required this.updatedAt,
  });

  final String id;
  final String folderId;
  final String title;
  final String content;
  final DateTime updatedAt;
}
