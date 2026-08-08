import 'package:flutter/material.dart';

import '../theme.dart';

/// 统一卡片：白底、圆角 20、极浅阴影，可选描边与点击反馈。
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color = AppColors.surface,
    this.borderColor,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final Color? borderColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppTheme.radiusCard);
    return Material(
      color: color,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: radius,
            border: borderColor == null
                ? null
                : Border.all(color: borderColor!, width: 1.4),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0D0B7E82),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
