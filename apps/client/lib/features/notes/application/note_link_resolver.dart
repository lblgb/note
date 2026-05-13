// 文件说明：提供笔记 Markdown 内链预处理和目标笔记解析能力。
import '../data/note_repository.dart';
import '../domain/note.dart';

// NoteLinkResolver 负责把笔记链接文本解析为仓储中的目标笔记。
class NoteLinkResolver {
  // NoteLinkResolver 绑定一个笔记仓储用于查询目标笔记。
  const NoteLinkResolver(this._repository);

  static final RegExp _wikiLinkPattern = RegExp(r'\[\[([^\]\n]+)\]\]');

  final NoteRepository _repository;

  // expandWikiLinks 将 [[标题]] 转换为 Markdown 可点击链接。
  String expandWikiLinks(String content) {
    return content.replaceAllMapped(_wikiLinkPattern, (match) {
      final title = match.group(1)!.trim();
      final encodedTitle = Uri.encodeComponent(title);
      return '[$title](note-title:$encodedTitle)';
    });
  }

  // isInternalHref 判断 href 是否属于笔记内部链接协议。
  bool isInternalHref(String href) {
    return href.startsWith('note:') || href.startsWith('note-title:');
  }

  // resolve 根据内部链接 href 查找目标笔记，未命中时返回 null。
  Note? resolve(String href) {
    if (href.startsWith('note:')) {
      return _repository.findNote(href.substring('note:'.length));
    }

    if (href.startsWith('note-title:')) {
      final title = Uri.decodeComponent(href.substring('note-title:'.length));
      return _findLatestByTitle(title);
    }

    return null;
  }

  // _findLatestByTitle 按精确标题匹配并返回更新时间最新的笔记。
  Note? _findLatestByTitle(String title) {
    Note? latest;
    for (final folder in _repository.listFolders()) {
      for (final note in _repository.listNotes(folder.id)) {
        if (note.title != title) {
          continue;
        }
        if (latest == null || note.updatedAt.isAfter(latest.updatedAt)) {
          latest = note;
        }
      }
    }
    return latest;
  }
}
