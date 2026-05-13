// 文件说明：渲染笔记详情 Markdown，并处理笔记内部链接点击。
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../application/note_link_resolver.dart';
import '../data/note_repository.dart';
import '../domain/note.dart';

const _markdownText = Color(0xFF103746);
const _markdownMuted = Color(0xFF627986);
const _markdownLine = Color(0xFFD9E7EC);
const _markdownPanelSoft = Color(0xFFF8FBFC);
const _markdownPrimary = Color(0xFF0891B2);

// MarkdownNoteBody 展示笔记内容的 Markdown 预览并桥接内部笔记跳转。
class MarkdownNoteBody extends StatelessWidget {
  const MarkdownNoteBody({
    super.key,
    required this.content,
    required this.repository,
    required this.onNoteSelected,
  });

  final String content;
  final NoteRepository repository;
  final ValueChanged<Note> onNoteSelected;

  // build 构建 Markdown 预览正文。
  @override
  Widget build(BuildContext context) {
    final resolver = NoteLinkResolver(repository);
    final theme = Theme.of(context);

    return MarkdownBody(
      data: resolver.expandWikiLinks(content),
      selectable: false,
      styleSheet: MarkdownStyleSheet(
        p: theme.textTheme.bodyLarge?.copyWith(
          color: _markdownText,
          height: 1.75,
        ),
        h1: theme.textTheme.headlineMedium?.copyWith(
          color: _markdownText,
          fontWeight: FontWeight.w700,
        ),
        h2: theme.textTheme.titleLarge?.copyWith(
          color: _markdownText,
          fontWeight: FontWeight.w700,
        ),
        h3: theme.textTheme.titleMedium?.copyWith(
          color: _markdownText,
          fontWeight: FontWeight.w700,
        ),
        strong: const TextStyle(fontWeight: FontWeight.w700),
        em: const TextStyle(fontStyle: FontStyle.italic),
        a: const TextStyle(
          color: _markdownPrimary,
          decoration: TextDecoration.underline,
          decorationColor: _markdownPrimary,
        ),
        blockquote: theme.textTheme.bodyLarge?.copyWith(
          color: _markdownMuted,
          height: 1.7,
        ),
        blockquoteDecoration: const BoxDecoration(
          color: _markdownPanelSoft,
          border: Border(left: BorderSide(color: _markdownPrimary, width: 3)),
        ),
        code: theme.textTheme.bodyMedium?.copyWith(
          color: _markdownText,
          backgroundColor: _markdownPanelSoft,
          fontFamily: 'Consolas',
        ),
        codeblockDecoration: BoxDecoration(
          color: _markdownPanelSoft,
          border: Border.all(color: _markdownLine),
          borderRadius: BorderRadius.circular(8),
        ),
        listBullet: theme.textTheme.bodyLarge?.copyWith(
          color: _markdownText,
          height: 1.7,
        ),
      ),
      onTapLink: (text, href, title) {
        _handleLinkTap(context, resolver, href);
      },
    );
  }

  // _handleLinkTap 根据链接类型执行内部跳转或显示当前阶段提示。
  void _handleLinkTap(
    BuildContext context,
    NoteLinkResolver resolver,
    String? href,
  ) {
    if (href == null || href.isEmpty) {
      return;
    }

    if (!resolver.isInternalHref(href)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('外部链接跳转将在后续支持')));
      return;
    }

    final note = resolver.resolve(href);
    if (note == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('未找到笔记')));
      return;
    }

    onNoteSelected(note);
  }
}
