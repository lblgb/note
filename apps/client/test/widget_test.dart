// 文件说明：客户端本地笔记浏览和编辑组件测试。
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:note_client/app/note_app.dart';
import 'package:note_client/features/auth/data/auth_api_client.dart';
import 'package:note_client/features/auth/data/auth_session_store.dart';
import 'package:note_client/features/auth/domain/auth_session.dart';
import 'package:note_client/features/notes/data/in_memory_note_repository.dart';
import 'package:note_client/features/notes/data/note_repository.dart';
import 'package:note_client/features/notes/domain/note.dart';
import 'package:note_client/features/notes/presentation/note_browser_page.dart';
import 'package:note_client/features/sync/application/note_sync_service.dart';
import 'package:note_client/features/sync/data/sync_api_client.dart';

// main 注册客户端本地笔记浏览和编辑组件测试。
void main() {
  // buildTestApp 创建使用独立内存仓储的测试应用。
  Widget buildTestApp({
    InMemoryNoteRepository? repository,
    RefreshingNoteSyncAction? syncAction,
    AuthApiClient? authApiClient,
  }) {
    return NoteApp(
      repository: repository ?? InMemoryNoteRepository(),
      authApiClient: authApiClient ?? _NoopAuthApiClient(),
      authSessionStore: MemoryAuthSessionStore(initialSession: _testSession),
      syncAction: syncAction,
    );
  }

  testWidgets('默认仓储加载完成前展示加载状态', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: NoteBrowserPage()));

    expect(find.text('正在加载笔记...'), findsOneWidget);
  });

  testWidgets('默认展示 Calm Cyan 笔记界面', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    expect(find.text('轻量同步笔记'), findsOneWidget);
    expect(find.text('搜索标题、正文或链接...'), findsOneWidget);
    expect(find.text('SQLite 已保存'), findsWidgets);
    expect(find.text('新建'), findsOneWidget);
    expect(find.text('收集箱'), findsWidgets);
    expect(find.text('后续会支持链接跳转'), findsWidgets);
    expect(find.text('下一批功能会逐步接入外部链接、内部笔记链接和 Markdown 预览。'), findsWidgets);
  });

  testWidgets('点击文件夹后切换笔记列表和详情', (tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('工作'));
    await tester.pumpAndSettle();

    expect(find.text('工作计划'), findsWidgets);
    expect(find.text('这里展示工作文件夹下的笔记。当前阶段只读，下一阶段会接入本地编辑保存。'), findsOneWidget);
  });

  testWidgets('点击当前笔记后保持详情可读', (tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('后续会支持链接跳转').first);
    await tester.pumpAndSettle();

    expect(find.text('下一批功能会逐步接入外部链接、内部笔记链接和 Markdown 预览。'), findsOneWidget);
  });

  testWidgets('点击复制链接后写入当前笔记 Markdown 链接', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    String? clipboardText;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          final data = Map<String, Object?>.from(call.arguments as Map);
          clipboardText = data['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });

    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('复制链接'));
    await tester.pumpAndSettle();

    expect(clipboardText, '[后续会支持链接跳转](note:note-links)');
    expect(find.text('已复制笔记链接'), findsOneWidget);
  });

  testWidgets('新建笔记后展示新内容', (tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('新建').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '标题'), '今天的记录');
    await tester.enterText(find.widgetWithText(TextField, '正文'), '这是新建后保存的正文。');
    await tester.ensureVisible(find.text('保存'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.text('今天的记录'), findsWidgets);
    expect(find.text('这是新建后保存的正文。'), findsOneWidget);
  });

  testWidgets('编辑笔记后更新标题和正文', (tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('编辑'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '标题'), '更新后的标题');
    await tester.enterText(find.widgetWithText(TextField, '正文'), '更新后的正文内容。');
    await tester.ensureVisible(find.text('保存'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.text('更新后的标题'), findsWidgets);
    expect(find.text('更新后的正文内容。'), findsOneWidget);
  });

  testWidgets('取消编辑后保留原内容', (tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('编辑'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '标题'), '不会保存的标题');
    await tester.enterText(find.widgetWithText(TextField, '正文'), '不会保存的正文。');
    await tester.ensureVisible(find.text('取消'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(find.text('不会保存的标题'), findsNothing);
    expect(find.text('不会保存的正文。'), findsNothing);
    expect(find.text('下一批功能会逐步接入外部链接、内部笔记链接和 Markdown 预览。'), findsOneWidget);
  });

  testWidgets('点击标题内链后跳转到目标笔记', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = InMemoryNoteRepository(
      now: () => DateTime(2026, 5, 13, 10),
    )..createNote(folderId: 'folder-inbox', title: '内链测试', content: '[[工作计划]]');

    await tester.pumpWidget(buildTestApp(repository: repository));
    await tester.pumpAndSettle();

    expect(find.text('内链测试'), findsWidgets);

    await tester.tap(find.text('工作计划', findRichText: true));
    await tester.pumpAndSettle();

    expect(find.text('工作计划'), findsWidgets);
    expect(find.text('内链测试'), findsNothing);
  });

  testWidgets('点击同步后调用同步服务并展示已同步', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var syncCount = 0;

    await tester.pumpWidget(
      buildTestApp(
        syncAction: (repository, accessTokenProvider) async {
          syncCount++;
          expect(await accessTokenProvider(), 'access-token');
          repository.upsertNote(
            Note(
              id: 'note-synced',
              folderId: 'folder-inbox',
              title: '同步回来的笔记',
              content: '来自服务端。',
              updatedAt: DateTime(2026, 5, 17, 13),
            ),
          );
          return const NoteSyncResult(
            serverVersion: 3,
            folderCount: 0,
            noteCount: 1,
          );
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('同步'));
    await tester.pumpAndSettle();

    expect(syncCount, 1);
    expect(find.text('已同步：0 文件夹 / 1 笔记'), findsOneWidget);
    expect(find.text('同步回来的笔记'), findsWidgets);
  });

  testWidgets('同步未授权时刷新令牌并重试成功', (tester) async {
    var syncCount = 0;
    final authClient = _NoopAuthApiClient(
      refreshResult: const AuthTokenPair(
        accessToken: 'new-access-token',
        refreshToken: 'new-refresh-token',
      ),
    );

    await tester.pumpWidget(
      buildTestApp(
        authApiClient: authClient,
        syncAction: (repository, accessTokenProvider) async {
          syncCount++;
          final accessToken = await accessTokenProvider();
          if (syncCount == 1) {
            expect(accessToken, 'access-token');
            throw const SyncApiException(
              code: 'unauthorized',
              message: '未登录或令牌无效',
            );
          }
          expect(accessToken, 'new-access-token');
          return const NoteSyncResult(
            serverVersion: 5,
            folderCount: 0,
            noteCount: 0,
          );
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('同步'));
    await tester.pumpAndSettle();

    expect(syncCount, 2);
    expect(authClient.refreshCount, 1);
    expect(find.text('已同步：0 文件夹 / 0 笔记'), findsOneWidget);
  });

  testWidgets('同步刷新失败时可重新登录', (tester) async {
    final authClient = _NoopAuthApiClient(refreshShouldFail: true);

    await tester.pumpWidget(
      buildTestApp(
        authApiClient: authClient,
        syncAction: (repository, accessTokenProvider) async {
          await accessTokenProvider();
          throw const SyncApiException(
            code: 'unauthorized',
            message: '未登录或令牌无效',
          );
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('同步'));
    await tester.pumpAndSettle();

    expect(find.text('登录已失效'), findsOneWidget);
    expect(find.text('当前登录状态已过期，请重新登录后再同步。'), findsOneWidget);

    await tester.tap(find.text('重新登录'));
    await tester.pumpAndSettle();

    expect(find.text('登录账号'), findsOneWidget);
  });
}

const _testSession = AuthSession(
  user: AuthUser(id: 'usr_test', email: 'user@example.com', displayName: '用户'),
  accessToken: 'access-token',
  refreshToken: 'refresh-token',
);

// _NoopAuthApiClient 为笔记组件测试提供无需联网的认证客户端。
class _NoopAuthApiClient implements AuthApiClient {
  _NoopAuthApiClient({this.refreshResult, this.refreshShouldFail = false});

  final AuthTokenPair? refreshResult;
  final bool refreshShouldFail;
  int refreshCount = 0;

  // baseUrl 返回测试 API 地址。
  @override
  String get baseUrl => 'http://localhost:8080';

  // login 返回测试会话。
  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    return _testSession;
  }

  // logout 忽略测试退出请求。
  @override
  Future<void> logout(String refreshToken) async {}

  // refresh 返回测试刷新令牌结果。
  @override
  Future<AuthTokenPair> refresh(String refreshToken) async {
    refreshCount++;
    if (refreshShouldFail) {
      throw const AuthApiException(
        code: 'invalid_credentials',
        message: '登录已失效',
      );
    }
    return refreshResult ??
        const AuthTokenPair(
          accessToken: 'access-token',
          refreshToken: 'refresh-token',
        );
  }

  // registerDevice 返回测试设备。
  @override
  Future<AuthDevice> registerDevice({
    required String accessToken,
    required String deviceName,
    required String platform,
  }) async {
    return AuthDevice(
      id: 'dev_test',
      userId: _testSession.user.id,
      deviceName: deviceName,
      platform: platform,
    );
  }

  // register 返回测试会话。
  @override
  Future<AuthSession> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    return _testSession;
  }
}
