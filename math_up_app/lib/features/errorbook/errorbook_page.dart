import 'package:flutter/material.dart';

/// 错题本占位页（阶段 4 实现）。
class ErrorbookPage extends StatelessWidget {
  const ErrorbookPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('错题本')),
      body: const Center(child: Text('阶段 4：错题记录与重做')),
    );
  }
}
