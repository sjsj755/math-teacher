import 'package:flutter/material.dart';

import '../../core/application/db_initializer.dart';
import '../../core/router.dart';

/// 首页：展示题库初始化状态与 6 个功能入口。
class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.dbInitController});

  final DbInitController dbInitController;

  @override
  Widget build(BuildContext context) {
    const entries = <({String title, String subtitle, String route})>[
      (title: '年级选择', subtitle: '首次启动设置年级', route: AppRoutes.onboarding),
      (title: '诊断测试', subtitle: '完成入项诊断，生成四因子报告', route: AppRoutes.diagnosis),
      (title: '学情报告', subtitle: '四因子雷达图与薄弱知识点', route: AppRoutes.report),
      (title: '练习', subtitle: '按薄弱知识点推荐练习', route: AppRoutes.practice),
      (title: '错题本', subtitle: '错题记录与重做', route: AppRoutes.errorbook),
      (title: '设置', subtitle: '家长通知与绑定', route: AppRoutes.settings),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('数学学习提升')),
      body: ListenableBuilder(
        listenable: dbInitController,
        builder: (context, _) {
          return ListView(
            children: [
              _StatusCard(controller: dbInitController),
              const Divider(height: 1),
              for (final entry in entries)
                ListTile(
                  leading: const Icon(Icons.chevron_right),
                  title: Text(entry.title),
                  subtitle: Text(entry.subtitle),
                  onTap: () => Navigator.pushNamed(context, entry.route),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// 题库初始化状态卡片（初始化中 / 成功 / 失败可重试）。
class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.controller});

  final DbInitController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Widget content;
    switch (controller.state) {
      case DbInitState.initializing:
        content = const Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Expanded(child: Text('正在初始化本地题库…')),
          ],
        );
      case DbInitState.success:
        final result = controller.result!;
        content = Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green.shade600),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('题库导入成功', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 2),
                  Text(
                    '题目 ${result.questionCount} · 章节 ${result.chapterCount}'
                    ' · 内容版本 ${result.contentVersion}'
                    ' · 数据版本 ${result.schemaVersion}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        );
      case DbInitState.failure:
        content = Row(
          children: [
            Icon(Icons.error_outline, color: theme.colorScheme.error),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('题库初始化失败', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 2),
                  Text(
                    controller.error ?? '未知错误',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 6),
                  FilledButton.tonal(
                    onPressed: controller.run,
                    child: const Text('重试'),
                  ),
                ],
              ),
            ),
          ],
        );
    }
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(padding: const EdgeInsets.all(16), child: content),
    );
  }
}
