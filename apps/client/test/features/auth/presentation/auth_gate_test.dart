// 文件说明：测试认证入口在不同会话状态下的界面切换。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:note_client/features/auth/data/auth_api_client.dart';
import 'package:note_client/features/auth/data/auth_session_store.dart';
import 'package:note_client/features/auth/domain/auth_session.dart';
import 'package:note_client/features/auth/presentation/auth_gate.dart';

// main 验证 AuthGate 和 AuthPage 的主要交互。
void main() {
  const session = AuthSession(
    user: AuthUser(id: 'usr_1', email: 'user@example.com', displayName: '用户'),
    accessToken: 'access-token',
    refreshToken: 'refresh-token',
  );

  // buildGate 创建用于测试的认证入口。
  Widget buildGate({
    AuthSession? initialSession,
    AuthSession? loginSession,
    AuthSession? registerSession,
  }) {
    return MaterialApp(
      home: AuthGate(
        apiClient: _FakeAuthApiClient(
          loginSession: loginSession ?? session,
          registerSession: registerSession ?? session,
        ),
        sessionStore: MemoryAuthSessionStore()..saveInitial(initialSession),
        authenticatedBuilder: (context, currentSession, logout) {
          return Scaffold(
            body: Column(
              children: [
                Text('已登录：${currentSession.user.displayName}'),
                TextButton(onPressed: logout, child: const Text('退出')),
              ],
            ),
          );
        },
      ),
    );
  }

  testWidgets('无会话时显示登录页', (tester) async {
    await tester.pumpWidget(buildGate());
    await tester.pumpAndSettle();

    expect(find.text('登录账号'), findsOneWidget);
    expect(find.text('注册'), findsOneWidget);
  });

  testWidgets('已有会话时显示已登录内容', (tester) async {
    await tester.pumpWidget(buildGate(initialSession: session));
    await tester.pumpAndSettle();

    expect(find.text('已登录：用户'), findsOneWidget);
    expect(find.text('登录账号'), findsNothing);
  });

  testWidgets('登录成功后切换到已登录内容', (tester) async {
    await tester.pumpWidget(buildGate());
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, '邮箱'),
      'user@example.com',
    );
    await tester.enterText(find.widgetWithText(TextField, '密码'), 'pass123456');
    await tester.tap(find.text('登录'));
    await tester.pumpAndSettle();

    expect(find.text('已登录：用户'), findsOneWidget);
  });

  testWidgets('退出登录后回到登录页', (tester) async {
    await tester.pumpWidget(buildGate(initialSession: session));
    await tester.pumpAndSettle();

    await tester.tap(find.text('退出'));
    await tester.pumpAndSettle();

    expect(find.text('登录账号'), findsOneWidget);
  });
}

// _FakeAuthApiClient 提供组件测试使用的认证 API 假实现。
class _FakeAuthApiClient implements AuthApiClient {
  _FakeAuthApiClient({
    required this.loginSession,
    required this.registerSession,
  });

  final AuthSession loginSession;
  final AuthSession registerSession;

  // baseUrl 返回测试 API 地址。
  @override
  String get baseUrl => 'http://localhost:8080';

  // login 返回预设登录会话。
  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    return loginSession;
  }

  // logout 记录退出请求。
  @override
  Future<void> logout(String refreshToken) async {}

  // register 返回预设注册会话。
  @override
  Future<AuthSession> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    return registerSession;
  }
}

// _MemoryAuthSessionStoreTestExtension 为测试准备初始会话。
extension _MemoryAuthSessionStoreTestExtension on MemoryAuthSessionStore {
  // saveInitial 同步设置测试初始会话。
  MemoryAuthSessionStore saveInitial(AuthSession? session) {
    if (session != null) {
      save(session);
    }
    return this;
  }
}
