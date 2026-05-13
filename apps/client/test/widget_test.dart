// 文件说明：客户端本地笔记浏览和编辑组件测试。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:note_client/app/note_app.dart';
import 'package:note_client/features/notes/data/in_memory_note_repository.dart';
import 'package:note_client/features/notes/presentation/note_browser_page.dart';

// main 注册客户端本地笔记浏览和编辑组件测试。
void main() {
  // buildTestApp 创建使用独立内存仓储的测试应用。
  Widget buildTestApp({InMemoryNoteRepository? repository}) {
    return NoteApp(repository: repository ?? InMemoryNoteRepository());
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

    expect(find.text('轻量同步笔记'), findsOneWidget);
    expect(find.text('搜索标题、正文或链接...'), findsOneWidget);
    expect(find.text('SQLite 已保存'), findsWidgets);
    expect(find.text('收集箱'), findsWidgets);
    expect(find.text('后续会支持链接跳转'), findsWidgets);
    expect(find.text('下一批功能会逐步接入外部链接、内部笔记链接和 Markdown 预览。'), findsWidgets);
  });

  testWidgets('点击文件夹后切换笔记列表和详情', (tester) async {
    await tester.pumpWidget(buildTestApp());

    await tester.tap(find.text('工作'));
    await tester.pumpAndSettle();

    expect(find.text('工作计划'), findsWidgets);
    expect(find.text('这里展示工作文件夹下的笔记。当前阶段只读，下一阶段会接入本地编辑保存。'), findsOneWidget);
  });

  testWidgets('点击当前笔记后保持详情可读', (tester) async {
    await tester.pumpWidget(buildTestApp());

    await tester.tap(find.text('后续会支持链接跳转').first);
    await tester.pumpAndSettle();

    expect(find.text('下一批功能会逐步接入外部链接、内部笔记链接和 Markdown 预览。'), findsOneWidget);
  });

  testWidgets('新建笔记后展示新内容', (tester) async {
    await tester.pumpWidget(buildTestApp());

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
    )..createNote(
        folderId: 'folder-inbox',
        title: '内链测试',
        content: '[[工作计划]]',
      );

    await tester.pumpWidget(buildTestApp(repository: repository));
    await tester.pumpAndSettle();

    expect(find.text('内链测试'), findsWidgets);

    await tester.tap(find.text('工作计划', findRichText: true));
    await tester.pumpAndSettle();

    expect(find.text('工作计划'), findsWidgets);
    expect(find.text('内链测试'), findsNothing);
  });
}
