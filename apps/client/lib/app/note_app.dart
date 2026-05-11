// 文件说明：客户端应用根组件。

import 'package:flutter/material.dart';

import '../features/shell/shell_page.dart';
import 'app_theme.dart';

// NoteApp 是 Flutter 客户端根组件。
class NoteApp extends StatelessWidget {
  const NoteApp({super.key});

  // build 构建应用路由、主题和首页。
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '轻量同步笔记',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const ShellPage(),
    );
  }
}
