// 文件说明：客户端基础壳页面，挂载当前主要功能页面。

import 'package:flutter/material.dart';

import '../notes/data/note_repository.dart';
import '../notes/presentation/note_browser_page.dart';

// ShellPage 展示客户端第一阶段主要界面。
class ShellPage extends StatelessWidget {
  const ShellPage({super.key, this.repository});

  final NoteRepository? repository;

  // build 构建应用壳并挂载本地笔记浏览器。
  @override
  Widget build(BuildContext context) {
    return NoteBrowserPage(repository: repository);
  }
}
