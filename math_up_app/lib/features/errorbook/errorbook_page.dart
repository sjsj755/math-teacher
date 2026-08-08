import 'package:flutter/material.dart';

import '../../core/ui/empty_state.dart';

/// 错题本外壳：空状态（平静态小精灵）＋入口说明。
class ErrorbookPage extends StatelessWidget {
  const ErrorbookPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('错题本')),
      body: const EmptyState(
        title: '还没有错题',
        subtitle: '完成练习后，答错的题目会自动收录到这里，支持重做与周清。',
      ),
    );
  }
}
