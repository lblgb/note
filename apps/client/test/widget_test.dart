// 文件说明：客户端本地笔记浏览器组件测试。

import 'package:flutter_test/flutter_test.dart';
import 'package:note_client/app/note_app.dart';

// main 注册客户端本地笔记浏览器组件测试。
void main() {
  testWidgets('默认展示第一条种子笔记', (tester) async {
    await tester.pumpWidget(const NoteApp());

    expect(find.text('轻量同步笔记'), findsOneWidget);
    expect(find.text('收集箱'), findsOneWidget);
    expect(find.text('后续会支持链接跳转'), findsOneWidget);
    expect(find.text('下一批功能会逐步接入外部链接、内部笔记链接和 Markdown 预览。'), findsOneWidget);
  });

  testWidgets('点击文件夹后切换笔记列表和详情', (tester) async {
    await tester.pumpWidget(const NoteApp());

    await tester.tap(find.text('工作'));
    await tester.pumpAndSettle();

    expect(find.text('工作计划'), findsOneWidget);
    expect(find.text('这里展示工作文件夹下的笔记。当前阶段只读，下一阶段会接入本地编辑保存。'), findsOneWidget);
  });

  testWidgets('点击笔记后切换详情', (tester) async {
    await tester.pumpWidget(const NoteApp());

    await tester.tap(find.text('欢迎使用轻量同步笔记'));
    await tester.pumpAndSettle();

    expect(find.text('这是第一条本地种子笔记，用来验证文件夹、列表和详情区的浏览体验。'), findsOneWidget);
  });
}
