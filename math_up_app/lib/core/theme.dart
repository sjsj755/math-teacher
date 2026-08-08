import 'package:flutter/material.dart';

/// 全局主题：Material 3 + 蓝色种子色。
abstract final class AppTheme {
  static const Color seed = Color(0xFF2E74B5);

  static ThemeData get light => ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: seed),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(centerTitle: true),
      );
}
