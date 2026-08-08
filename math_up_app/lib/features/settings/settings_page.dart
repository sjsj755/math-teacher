import 'package:flutter/material.dart';

/// 设置占位页（阶段 5 实现家长通知）。
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: const Center(child: Text('阶段 5：家长通知与绑定')),
    );
  }
}
