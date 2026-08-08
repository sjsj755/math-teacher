import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/ui/app_buttons.dart';
import '../../core/ui/app_card.dart';
import '../../core/ui/app_progress.dart';

/// 练习页外壳（阶段四功能前的专注式骨架）。
class PracticePage extends StatelessWidget {
  const PracticePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('练习')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          AppProgressBar(value: 1 / 10),
          const SizedBox(height: 10),
          Row(
            children: [
              Text('第 1 / 10 题', style: theme.textTheme.bodySmall),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.tertiaryContainer,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.timer_outlined,
                      size: 14,
                      color: AppColors.warmIcon,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '00:00',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppColors.warmIcon,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
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
                FractionallySizedBox(
                  widthFactor: 0.85,
                  alignment: Alignment.centerLeft,
                  child: Container(
                    height: 14,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE6F0EE),
                      borderRadius: BorderRadius.circular(7),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AppSoftButton(onPressed: () {}, child: const Text('下一题')),
        ],
      ),
    );
  }
}
