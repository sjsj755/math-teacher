import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:math_up_app/core/application/db_initializer.dart';
import 'package:math_up_app/core/theme.dart';
import 'package:math_up_app/core/ui/geo_spirit.dart';
import 'package:math_up_app/features/home/home_page.dart';
import 'package:math_up_app/features/onboarding/onboarding_page.dart';

void main() {
  testWidgets('首页渲染：品牌区＋状态卡＋功能宫格', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final controller = DbInitController();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: HomePage(dbInitController: controller),
      ),
    );

    expect(find.text('数学学习提升'), findsWidgets);
    expect(find.text('清爽学习，每天进步一点点'), findsOneWidget);
    expect(find.text('正在初始化本地题库…'), findsOneWidget);
    expect(find.text('学习功能'), findsOneWidget);
    expect(find.text('诊断测试'), findsOneWidget);
    for (final title in ['练习', '错题本', '学情报告', '设置', '年级选择']) {
      expect(find.text(title), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('GeoSpirit 三种表情正常绘制', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              GeoSpirit(mood: GeoSpiritMood.quiet),
              GeoSpirit(mood: GeoSpiritMood.happy, showBubbles: true),
              GeoSpirit(mood: GeoSpiritMood.cheer),
            ],
          ),
        ),
      ),
    );
    expect(find.byType(GeoSpirit), findsNWidgets(3));
    expect(tester.takeException(), isNull);
  });

  testWidgets('年级选择页渲染：欢迎卡＋三张年级卡', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final controller = DbInitController();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: OnboardingPage(dbInitController: controller),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('欢迎来到数学提升'), findsOneWidget);
    expect(find.text('高一'), findsOneWidget);
    expect(find.text('高二'), findsOneWidget);
    expect(find.text('高三'), findsOneWidget);
    expect(find.byType(GeoSpirit), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
