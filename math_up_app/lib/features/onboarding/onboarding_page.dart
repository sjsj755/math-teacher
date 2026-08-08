import 'package:flutter/material.dart';

/// 年级选择占位页（阶段 2 实现）。
class OnboardingPage extends StatelessWidget {
  const OnboardingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('年级选择')),
      body: const Center(child: Text('阶段 2：首次诊断流程')),
    );
  }
}
