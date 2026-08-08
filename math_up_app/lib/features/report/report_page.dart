import 'package:flutter/material.dart';

/// 学情报告占位页（阶段 3 实现）。
class ReportPage extends StatelessWidget {
  const ReportPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('学情报告')),
      body: const Center(child: Text('阶段 3：四因子雷达图与薄弱点')),
    );
  }
}
