import 'package:flutter/material.dart';

/// 诊断测试占位页（阶段 3 实现）。
class DiagnosisPage extends StatelessWidget {
  const DiagnosisPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('诊断测试')),
      body: const Center(child: Text('阶段 3：15 题入项诊断')),
    );
  }
}
