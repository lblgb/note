// 文件说明：客户端基础壳页面，挂载当前主要功能页面。

import 'package:flutter/material.dart';

import '../auth/domain/auth_session.dart';
import '../notes/data/note_repository.dart';
import '../notes/presentation/note_browser_page.dart';
import '../sync/application/note_sync_service.dart';

// ShellPage 展示客户端第一阶段主要界面。
class ShellPage extends StatelessWidget {
  const ShellPage({
    super.key,
    required this.session,
    this.repository,
    this.onLogout,
    this.refreshSession,
    this.syncAction,
  });

  final AuthSession session;
  final NoteRepository? repository;
  final VoidCallback? onLogout;
  final Future<AuthSession> Function()? refreshSession;
  final RefreshingNoteSyncAction? syncAction;

  // build 构建应用壳并挂载本地笔记浏览器。
  @override
  Widget build(BuildContext context) {
    return NoteBrowserPage(
      repository: repository,
      accessToken: session.accessToken,
      onLogout: onLogout,
      refreshSession: refreshSession,
      syncAction: syncAction,
    );
  }
}
