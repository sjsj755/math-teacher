import 'package:flutter/material.dart';

/// 圆角进度条。
class AppProgressBar extends StatelessWidget {
  const AppProgressBar({super.key, required this.value, this.height = 8});

  final double value;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: LinearProgressIndicator(
        value: value.clamp(0, 1),
        minHeight: height,
      ),
    );
  }
}
