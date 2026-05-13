// 文件说明：客户端应用根组件。

import 'package:flutter/material.dart';

import '../features/auth/data/auth_api_client.dart';
import '../features/auth/data/auth_session_store.dart';
import '../features/auth/presentation/auth_gate.dart';
import '../features/notes/data/note_repository.dart';
import '../features/shell/shell_page.dart';
import 'app_theme.dart';

// NoteApp 是 Flutter 客户端根组件。
class NoteApp extends StatelessWidget {
  const NoteApp({
    super.key,
    this.repository,
    this.authApiClient,
    this.authSessionStore,
  });

  final NoteRepository? repository;
  final AuthApiClient? authApiClient;
  final AuthSessionStore? authSessionStore;

  // build 构建应用路由、主题和首页。
  @override
  Widget build(BuildContext context) {
    final apiClient = authApiClient ?? AuthApiClient();
    final sessionStore = authSessionStore ?? FileAuthSessionStore();

    return MaterialApp(
      title: '轻量同步笔记',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: AuthGate(
        apiClient: apiClient,
        sessionStore: sessionStore,
        authenticatedBuilder: (context, session, logout) {
          return ShellPage(repository: repository, onLogout: logout);
        },
      ),
    );
  }
}
