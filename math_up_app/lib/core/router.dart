import 'package:flutter/material.dart';

import 'application/db_initializer.dart';
import '../features/diagnosis/diagnosis_page.dart';
import '../features/errorbook/errorbook_page.dart';
import '../features/home/home_page.dart';
import '../features/onboarding/onboarding_page.dart';
import '../features/practice/practice_page.dart';
import '../features/report/report_page.dart';
import '../features/settings/settings_page.dart';

/// 路由常量（阶段 1 全部为占位页）。
abstract final class AppRoutes {
  static const String home = '/';
  static const String onboarding = '/onboarding';
  static const String diagnosis = '/diagnosis';
  static const String report = '/report';
  static const String practice = '/practice';
  static const String errorbook = '/errorbook';
  static const String settings = '/settings';
}

/// 路由表（携带数据层初始化控制器）。
class AppRouter {
  AppRouter(this._dbInitController);

  final DbInitController _dbInitController;

  Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.onboarding:
        return _page(OnboardingPage(dbInitController: _dbInitController));
      case AppRoutes.diagnosis:
        return _page(DiagnosisPage(dbInitController: _dbInitController));
      case AppRoutes.report:
        return _page(ReportPage(dbInitController: _dbInitController));
      case AppRoutes.practice:
        return _page(const PracticePage());
      case AppRoutes.errorbook:
        return _page(const ErrorbookPage());
      case AppRoutes.settings:
        return _page(const SettingsPage());
      case AppRoutes.home:
      default:
        return _page(HomePage(dbInitController: _dbInitController));
    }
  }

  MaterialPageRoute<dynamic> _page(Widget page) {
    return MaterialPageRoute<dynamic>(builder: (_) => page);
  }
}
