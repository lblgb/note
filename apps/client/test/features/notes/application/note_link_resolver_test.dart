// 文件说明：测试笔记内链解析器的 Markdown 预处理和目标笔记匹配规则。
import 'package:flutter_test/flutter_test.dart';
import 'package:note_client/features/notes/application/note_link_resolver.dart';
import 'package:note_client/features/notes/data/in_memory_note_repository.dart';

// main 验证笔记内链解析器的核心规则。
void main() {
  test('expandWikiLinks 将标题内链转换为 Markdown 链接', () {
    final repository = InMemoryNoteRepository();
    final resolver = NoteLinkResolver(repository);

    final markdown = resolver.expandWikiLinks('查看 [[工作计划]] 和 [[生活清单]]');

    expect(
      markdown,
      '查看 [工作计划](note-title:%E5%B7%A5%E4%BD%9C%E8%AE%A1%E5%88%92) 和 '
      '[生活清单](note-title:%E7%94%9F%E6%B4%BB%E6%B8%85%E5%8D%95)',
    );
  });

  test('resolve 按 note ID 精确匹配目标笔记', () {
    final repository = InMemoryNoteRepository();
    final resolver = NoteLinkResolver(repository);

    final note = resolver.resolve('note:note-work-plan');

    expect(note?.id, 'note-work-plan');
    expect(note?.title, '工作计划');
  });

  test('resolve 按标题匹配时选择更新时间最新的笔记', () {
    final repository = InMemoryNoteRepository(
      now: () => DateTime(2026, 5, 12, 9),
    );
    final newer = repository.createNote(
      folderId: 'folder-life',
      title: '工作计划',
      content: '同名但更新。',
    );
    final resolver = NoteLinkResolver(repository);

    final note = resolver.resolve(
      'note-title:%E5%B7%A5%E4%BD%9C%E8%AE%A1%E5%88%92',
    );

    expect(note?.id, newer.id);
    expect(note?.folderId, 'folder-life');
  });

  test('resolve 找不到内部目标时返回 null', () {
    final repository = InMemoryNoteRepository();
    final resolver = NoteLinkResolver(repository);

    expect(resolver.resolve('note:missing-note'), isNull);
    expect(resolver.resolve('note-title:%E4%B8%8D%E5%AD%98%E5%9C%A8'), isNull);
  });

  test('isInternalHref 只识别笔记内部链接', () {
    final repository = InMemoryNoteRepository();
    final resolver = NoteLinkResolver(repository);

    expect(resolver.isInternalHref('note:note-work-plan'), isTrue);
    expect(
      resolver.isInternalHref(
        'note-title:%E5%B7%A5%E4%BD%9C%E8%AE%A1%E5%88%92',
      ),
      isTrue,
    );
    expect(resolver.isInternalHref('https://example.com'), isFalse);
  });
}
