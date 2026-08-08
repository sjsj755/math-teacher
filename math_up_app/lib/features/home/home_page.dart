import 'package:flutter/material.dart';

import '../../core/application/db_initializer.dart';
import '../../core/router.dart';
import '../../core/theme.dart';
import '../../core/ui/app_card.dart';
import '../../core/ui/brand_mark.dart';
import '../../core/ui/section_header.dart';

/// 首页：品牌区＋题库状态卡＋功能宫格（诊断为主卡）。
class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.dbInitController});

  final DbInitController dbInitController;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('数学学习提升')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          const _BrandHeader(),
          const SizedBox(height: 16),
          ListenableBuilder(
            listenable: dbInitController,
            builder: (context, _) => _StatusCard(controller: dbInitController),
          ),
          const SizedBox(height: 24),
          const SectionHeader(title: '学习功能'),
          _PrimaryFeatureCard(
            icon: Icons.quiz_rounded,
            title: '诊断测试',
            subtitle: '15 题发现薄弱点，生成四因子报告',
            route: AppRoutes.diagnosis,
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.35,
            children: const [
              _FeatureCard(
                icon: Icons.edit_rounded,
                title: '练习',
                subtitle: '按薄弱点推荐',
                iconBackground: AppColors.primaryContainer,
                iconColor: AppColors.onPrimaryContainer,
                route: AppRoutes.practice,
              ),
              _FeatureCard(
                icon: Icons.star_rounded,
                title: '错题本',
                subtitle: '自动收录与重做',
                iconBackground: Color(0xFFFFF0C2),
                iconColor: AppColors.warmIcon,
                route: AppRoutes.errorbook,
              ),
              _FeatureCard(
                icon: Icons.radar_rounded,
                title: '学情报告',
                subtitle: '雷达图与归因',
                iconBackground: AppColors.secondaryContainer,
                iconColor: AppColors.onSecondaryContainer,
                route: AppRoutes.report,
              ),
              _FeatureCard(
                icon: Icons.settings_rounded,
                title: '设置',
                subtitle: '家长通知与绑定',
                iconBackground: Color(0xFFE8F1F5),
                iconColor: Color(0xFF3B6E8F),
                route: AppRoutes.settings,
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 118,
            child: _FeatureCard(
              icon: Icons.school_rounded,
              title: '年级选择',
              subtitle: '切换高一 / 高二 / 高三',
              iconBackground: AppColors.primaryContainer,
              iconColor: AppColors.onPrimaryContainer,
              route: AppRoutes.onboarding,
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Row(
        children: [
          const BrandMark(size: 52),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('数学学习提升', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 2),
              Text('清爽学习，每天进步一点点', style: theme.textTheme.bodySmall),
            ],
          ),
        ],
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
        content = Row(
          children: [
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text('正在初始化本地题库…', style: theme.textTheme.bodyMedium),
            ),
          ],
        );
      case DbInitState.success:
        final result = controller.result!;
        content = Row(
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: AppColors.correct,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('题库导入成功', style: theme.textTheme.titleMedium),
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: AppColors.wrong,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('题库初始化失败', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    controller.error ?? '未知错误',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
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
    return AppCard(child: content);
  }
}

/// 诊断主卡：主色渐变、通栏。
class _PrimaryFeatureCard extends StatelessWidget {
  const _PrimaryFeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.route,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String route;

  @override
  Widget build(BuildContext context) {
    return Material(
      borderRadius: BorderRadius.circular(AppTheme.radiusCard),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: const BoxDecoration(gradient: AppGradients.primary),
        child: InkWell(
          onTap: () => Navigator.pushNamed(context, route),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: Colors.white, size: 30),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: Colors.white),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 普通功能卡。
class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.iconBackground,
    required this.iconColor,
    required this.route,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color iconBackground;
  final Color iconColor;
  final String route;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => Navigator.pushNamed(context, route),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: iconBackground,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const Spacer(),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 2),
          Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
