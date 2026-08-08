import 'package:flutter/material.dart';

import '../../core/router.dart';
import '../../core/theme.dart';
import '../../core/ui/app_buttons.dart';
import '../../core/ui/app_card.dart';
import '../../core/ui/app_chip.dart';
import '../../core/ui/section_header.dart';

/// 报告页外壳（阶段三功能前的版式骨架）：数据区保持简洁，不使用吉祥物。
class ReportPage extends StatelessWidget {
  const ReportPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('学情报告')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('综合得分', style: theme.textTheme.bodySmall),
                const SizedBox(height: 4),
                Text('--', style: theme.textTheme.displaySmall),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: const [
                    AppChip(label: '知识 K', icon: Icons.lightbulb_rounded),
                    AppChip(
                      label: '思维 T',
                      icon: Icons.psychology_rounded,
                      backgroundColor: AppColors.secondaryContainer,
                      foregroundColor: AppColors.onSecondaryContainer,
                    ),
                    AppChip(
                      label: '规范 S',
                      icon: Icons.rule_rounded,
                      backgroundColor: Color(0xFFFFF0C2),
                      foregroundColor: AppColors.warmIcon,
                    ),
                    AppChip(
                      label: '临场 P',
                      icon: Icons.timer_rounded,
                      backgroundColor: Color(0xFFE8F1F5),
                      foregroundColor: Color(0xFF3B6E8F),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const SectionHeader(title: '四因子雷达图'),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 36),
            child: Column(
              children: [
                Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.outline, width: 2),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.radar_rounded,
                      size: 64,
                      color: AppColors.outline,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text('完成一次诊断后，这里会生成雷达图', style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const SectionHeader(title: '薄弱知识点'),
          AppCard(child: Text('暂无数据', style: theme.textTheme.bodyMedium)),
          const SizedBox(height: 24),
          const SectionHeader(title: '归因清单'),
          AppCard(child: Text('暂无数据', style: theme.textTheme.bodyMedium)),
          const SizedBox(height: 24),
          AppFilledButton(
            onPressed: () => Navigator.pushNamed(context, AppRoutes.practice),
            child: const Text('开始练习'),
          ),
        ],
      ),
    );
  }
}
