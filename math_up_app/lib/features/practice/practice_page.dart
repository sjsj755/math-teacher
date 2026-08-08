import 'package:flutter/material.dart';

/// 练习占位页（阶段 4 实现）。
class PracticePage extends StatelessWidget {
  const PracticePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('练习')),
      body: const Center(child: Text('阶段 4：按薄弱知识点推荐练习')),
    );
  }
}
