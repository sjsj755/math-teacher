import 'package:flutter/material.dart';

import '../theme.dart';

/// 按压缩放反馈的包装组件。
class _PressScale extends StatefulWidget {
  const _PressScale({required this.child});

  final Widget child;

  @override
  State<_PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<_PressScale> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => setState(() => _pressed = true),
      onPointerUp: (_) => setState(() => _pressed = false),
      onPointerCancel: (_) => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// 主按钮：主色填充、圆角 16、按压回弹。
class AppFilledButton extends StatelessWidget {
  const AppFilledButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.expanded = true,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final button = FilledButton(onPressed: onPressed, child: child);
    return _PressScale(
      child: expanded
          ? SizedBox(width: double.infinity, child: button)
          : button,
    );
  }
}

/// 次级按钮：浅青容器＋深青文字。
class AppSoftButton extends StatelessWidget {
  const AppSoftButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.expanded = true,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final button = FilledButton.tonal(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primaryContainer,
        foregroundColor: AppColors.onPrimaryContainer,
      ),
      child: child,
    );
    return _PressScale(
      child: expanded
          ? SizedBox(width: double.infinity, child: button)
          : button,
    );
  }
}
