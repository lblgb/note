// 文件说明：客户端基础壳页面，展示后续笔记工作区入口。

import 'package:flutter/material.dart';

// ShellPage 展示客户端第一阶段基础界面。
class ShellPage extends StatelessWidget {
  const ShellPage({super.key});

  // build 根据窗口宽度构建桌面或窄屏布局。
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('轻量同步笔记')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 900;
          if (isWide) {
            return const Row(
              children: [
                _SidebarPane(),
                VerticalDivider(width: 1),
                Expanded(child: _WorkspacePane()),
              ],
            );
          }

          return const _WorkspacePane();
        },
      ),
    );
  }
}

// _SidebarPane 展示桌面端侧边栏占位。
class _SidebarPane extends StatelessWidget {
  const _SidebarPane();

  // build 构建文件夹和最近笔记导航。
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          Text(
            '文件夹',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 12),
          ListTile(leading: Icon(Icons.folder_outlined), title: Text('全部笔记')),
          ListTile(leading: Icon(Icons.history), title: Text('最近编辑')),
        ],
      ),
    );
  }
}

// _WorkspacePane 展示当前阶段工作区占位。
class _WorkspacePane extends StatelessWidget {
  const _WorkspacePane();

  // build 构建居中的工作区状态说明。
  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '客户端基础壳已就绪',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Text(
                '下一阶段将接入本地笔记数据、文件夹和 Markdown 编辑体验。',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
