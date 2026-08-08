import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/ui/app_buttons.dart';
import '../../core/ui/app_card.dart';
import '../../core/ui/app_progress.dart';

/// 诊断页（阶段三功能前的专注式外壳）：进度条＋题目卡片骨架，零装饰。
class DiagnosisPage extends StatelessWidget {
  const DiagnosisPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('诊断测试')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          AppProgressBar(value: 2 / 15),
          const SizedBox(height: 10),
          Row(
            children: [
              Text('第 1 / 15 题', style: theme.textTheme.bodySmall),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.secondaryContainer,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '知识 K',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.onSecondaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('题目将在这里显示', style: theme.textTheme.titleLarge),
                const SizedBox(height: 12),
                _placeholderLine(theme, widthFactor: 0.9),
                const SizedBox(height: 6),
                _placeholderLine(theme, widthFactor: 0.7),
              ],
            ),
          ),
          const SizedBox(height: 16),
          for (final label in ['A', 'B', 'C', 'D'])
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _OptionPlaceholder(label: label),
            ),
          const SizedBox(height: 8),
          AppSoftButton(onPressed: () {}, child: const Text('下一题')),
        ],
      ),
    );
  }

  Widget _placeholderLine(ThemeData theme, {required double widthFactor}) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      alignment: Alignment.centerLeft,
      child: Container(
        height: 14,
        decoration: BoxDecoration(
          color: const Color(0xFFE6F0EE),
          borderRadius: BorderRadius.circular(7),
        ),
      ),
    );
  }
}

class _OptionPlaceholder extends StatelessWidget {
  const _OptionPlaceholder({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        border: Border.all(color: AppColors.outline),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 13,
            backgroundColor: AppColors.background,
            child: Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(fontSize: 13),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 12,
              decoration: BoxDecoration(
                color: const Color(0xFFE6F0EE),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
