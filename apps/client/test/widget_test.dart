// 文件说明：客户端基础壳组件测试。

import 'package:flutter_test/flutter_test.dart';
import 'package:note_client/app/note_app.dart';

// main 注册客户端基础壳组件测试。
void main() {
  testWidgets('显示客户端基础壳标题', (tester) async {
    await tester.pumpWidget(const NoteApp());

    expect(find.text('轻量同步笔记'), findsOneWidget);
    expect(find.text('客户端基础壳已就绪'), findsOneWidget);
  });
}
