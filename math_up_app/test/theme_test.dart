import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:math_up_app/core/theme.dart';

double _luminance(Color c) {
  double lin(double v) {
    return v <= 0.03928
        ? v / 12.92
        : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  }

  return 0.2126 * lin(c.r) + 0.7152 * lin(c.g) + 0.0722 * lin(c.b);
}

double _contrast(Color a, Color b) {
  final l1 = _luminance(a);
  final l2 = _luminance(b);
  final hi = math.max(l1, l2);
  final lo = math.min(l1, l2);
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  test('设计令牌与设计值一致', () {
    expect(AppColors.primary, const Color(0xFF0B7E82));
    expect(AppColors.secondary, const Color(0xFF0E9AA0));
    expect(AppColors.accent, const Color(0xFFFFC53D));
    expect(AppColors.background, const Color(0xFFF0FBF9));
    expect(AppColors.cream, const Color(0xFFFFF9F3));
    expect(AppColors.textPrimary, const Color(0xFF1F2937));
    expect(AppColors.textSecondary, const Color(0xFF6B7280));
    expect(AppColors.correct, const Color(0xFF2E9E6B));
    expect(AppColors.wrong, const Color(0xFFD9534F));
  });

  test('主色与白字对比度达到 WCAG AA（≥4.5:1）', () {
    expect(
      _contrast(AppColors.primary, Colors.white),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      _contrast(AppColors.accent, AppColors.accentText),
      greaterThanOrEqualTo(4.5),
    );
  });

  test('字号层级符合 2 进制栅格 12/14/16/20/24/28', () {
    final textTheme = AppTheme.textTheme;
    expect(textTheme.bodySmall?.fontSize, 12);
    expect(textTheme.bodyMedium?.fontSize, 14);
    expect(textTheme.bodyLarge?.fontSize, 16);
    expect(textTheme.titleLarge?.fontSize, 20);
    expect(textTheme.headlineSmall?.fontSize, 24);
    expect(textTheme.displaySmall?.fontSize, 28);
  });

  test('圆角令牌：卡片 20 / 按钮 16 / 小控件 12', () {
    expect(AppTheme.radiusCard, 20);
    expect(AppTheme.radiusButton, 16);
    expect(AppTheme.radiusSmall, 12);
  });
}
