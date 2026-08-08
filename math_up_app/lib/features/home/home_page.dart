import 'package:flutter/material.dart';

import '../../core/router.dart';

/// 首页：阶段 1 提供 6 个占位页入口。
class HomePage extends StatelessWidget {
  const HomePage({super.key});

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
      body: ListView.separated(
        itemCount: entries.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final entry = entries[index];
          return ListTile(
            leading: const Icon(Icons.chevron_right),
            title: Text(entry.title),
            subtitle: Text(entry.subtitle),
            onTap: () => Navigator.pushNamed(context, entry.route),
          );
        },
      ),
    );
  }
}
