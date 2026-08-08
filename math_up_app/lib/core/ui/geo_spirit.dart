import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// 吉祥物表情：平静 / 开心 / 加油。
enum GeoSpiritMood { quiet, happy, cheer }

/// 几何小精灵：圆角几何体＋点眼＋表情弧线，代码绘制，无图片资源。
/// 仅用于情感场景（欢迎、完成、空状态、薄弱提示），做题页与报告数据区禁用。
class GeoSpirit extends StatelessWidget {
  const GeoSpirit({
    super.key,
    this.size = 96,
    this.mood = GeoSpiritMood.quiet,
    this.showBubbles = false,
  });

  final double size;
  final GeoSpiritMood mood;
  final bool showBubbles;

  @override
  Widget build(BuildContext context) {
    const bubbleChars = ['π', '+', '−', '×', '÷'];
    final bubbleColors = [
      AppColors.primary,
      AppColors.secondary,
      AppColors.accent,
      AppColors.correct,
      AppColors.warmIcon,
    ];
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _GeoSpiritPainter(mood: mood),
          ),
          if (showBubbles)
            for (var i = 0; i < bubbleChars.length; i++)
              Positioned(
                top: size * (0.02 + 0.13 * (i % 3)),
                right: size * (0.02 + 0.16 * (i ~/ 3)),
                child: Transform.rotate(
                  angle: (i - 2) * 0.18,
                  child: Text(
                    bubbleChars[i],
                    style: TextStyle(
                      fontSize: size * 0.13,
                      fontWeight: FontWeight.w700,
                      color: bubbleColors[i],
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _GeoSpiritPainter extends CustomPainter {
  _GeoSpiritPainter({required this.mood});

  final GeoSpiritMood mood;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.12, h * 0.14, w * 0.76, h * 0.72),
      Radius.circular(w * 0.36),
    );

    // 身体：蓝绿渐变圆角块。
    final bodyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppColors.secondary, AppColors.primary],
      ).createShader(bodyRect.outerRect);
    canvas.drawRRect(bodyRect, bodyPaint);

    // 腮红（开心/加油）。
    if (mood != GeoSpiritMood.quiet) {
      final blush = Paint()..color = const Color(0x66FFB8B8);
      canvas.drawOval(
        Rect.fromLTWH(w * 0.24, h * 0.58, w * 0.13, h * 0.07),
        blush,
      );
      canvas.drawOval(
        Rect.fromLTWH(w * 0.63, h * 0.58, w * 0.13, h * 0.07),
        blush,
      );
    }

    final ink = Paint()..color = AppColors.primaryDark;
    final eyeY = h * 0.44;

    switch (mood) {
      case GeoSpiritMood.quiet:
        // 点眼＋浅微笑。
        canvas.drawCircle(Offset(w * 0.38, eyeY), w * 0.035, ink);
        canvas.drawCircle(Offset(w * 0.62, eyeY), w * 0.035, ink);
        final smile = Paint()
          ..color = AppColors.primaryDark
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.035
          ..strokeCap = StrokeCap.round;
        canvas.drawArc(
          Rect.fromLTWH(w * 0.38, h * 0.5, w * 0.24, h * 0.14),
          0.15 * math.pi,
          0.7 * math.pi,
          false,
          smile,
        );
      case GeoSpiritMood.happy:
        // 弯眼＋张嘴。
        final eye = Paint()
          ..color = AppColors.primaryDark
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.035
          ..strokeCap = StrokeCap.round;
        canvas.drawArc(
          Rect.fromLTWH(w * 0.3, eyeY - h * 0.07, w * 0.16, h * 0.13),
          math.pi,
          math.pi,
          false,
          eye,
        );
        canvas.drawArc(
          Rect.fromLTWH(w * 0.54, eyeY - h * 0.07, w * 0.16, h * 0.13),
          math.pi,
          math.pi,
          false,
          eye,
        );
        final mouth = Paint()..color = AppColors.primaryDark;
        canvas.drawArc(
          Rect.fromLTWH(w * 0.42, h * 0.5, w * 0.16, h * 0.16),
          0,
          math.pi,
          true,
          mouth,
        );
      case GeoSpiritMood.cheer:
        // 星星眼（× 形）＋大笑＋小星星。
        final star = Paint()
          ..color = AppColors.primaryDark
          ..strokeWidth = w * 0.028
          ..strokeCap = StrokeCap.round;
        for (final cx in [w * 0.38, w * 0.62]) {
          canvas.drawLine(
            Offset(cx - w * 0.045, eyeY - h * 0.055),
            Offset(cx + w * 0.045, eyeY + h * 0.055),
            star,
          );
          canvas.drawLine(
            Offset(cx - w * 0.045, eyeY + h * 0.055),
            Offset(cx + w * 0.045, eyeY - h * 0.055),
            star,
          );
        }
        final mouth = Paint()..color = AppColors.primaryDark;
        canvas.drawArc(
          Rect.fromLTWH(w * 0.38, h * 0.5, w * 0.24, h * 0.2),
          0,
          math.pi,
          true,
          mouth,
        );
        // 头顶小星星。
        final sparkle = Paint()
          ..color = AppColors.accent
          ..strokeWidth = w * 0.02
          ..strokeCap = StrokeCap.round;
        final sx = w * 0.78;
        final sy = h * 0.16;
        canvas.drawLine(
          Offset(sx, sy - h * 0.06),
          Offset(sx, sy + h * 0.06),
          sparkle,
        );
        canvas.drawLine(
          Offset(sx - w * 0.045, sy),
          Offset(sx + w * 0.045, sy),
          sparkle,
        );
    }
  }

  @override
  bool shouldRepaint(covariant _GeoSpiritPainter oldDelegate) {
    return oldDelegate.mood != mood;
  }
}
