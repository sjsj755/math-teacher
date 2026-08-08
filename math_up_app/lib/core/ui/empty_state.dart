import 'package:flutter/material.dart';

import 'geo_spirit.dart';

/// 空状态：平静态小精灵＋标题＋说明。
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    this.subtitle,
    this.mood = GeoSpiritMood.quiet,
  });

  final String title;
  final String? subtitle;
  final GeoSpiritMood mood;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GeoSpirit(size: 104, mood: mood, showBubbles: true),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium,
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}
