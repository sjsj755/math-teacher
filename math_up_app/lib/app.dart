import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/application/db_initializer.dart';
import 'core/router.dart';
import 'core/theme.dart';

/// App 根组件：主题、中文本地化与路由入口。
class MathUpApp extends StatelessWidget {
  const MathUpApp({super.key, required this.dbInitController});

  final DbInitController dbInitController;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '数学学习提升',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      locale: const Locale('zh', 'CN'),
      supportedLocales: const <Locale>[Locale('zh', 'CN'), Locale('en')],
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      initialRoute: AppRoutes.home,
      onGenerateRoute: AppRouter(dbInitController).onGenerateRoute,
    );
  }
}
