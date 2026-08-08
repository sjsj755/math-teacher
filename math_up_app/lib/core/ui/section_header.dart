import 'package:flutter/material.dart';

import '../theme.dart';

/// 区块标题：主色短条＋标题，可选右侧附加内容。
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 12),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const Spacer(),
          ?trailing,
        ],
      ),
    );
  }
}
