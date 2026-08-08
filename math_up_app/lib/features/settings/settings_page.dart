import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/ui/app_card.dart';
import '../../core/ui/section_header.dart';

/// 设置页外壳：家长通知与关于，统一卡片样式（功能逻辑阶段 5 实现）。
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          const SectionHeader(title: '家长通知'),
          AppCard(
            child: Column(
              children: [
                _SettingRow(
                  icon: Icons.notifications_active_rounded,
                  title: '每日日报',
                  trailing: Switch(value: true, onChanged: (_) {}),
                ),
                const Divider(height: 24),
                _SettingRow(
                  icon: Icons.schedule_rounded,
                  title: '推送时间',
                  trailing: Text('21:30', style: theme.textTheme.bodyMedium),
                ),
                const Divider(height: 24),
                _SettingRow(
                  icon: Icons.link_rounded,
                  title: '绑定状态',
                  trailing: Text('未绑定', style: theme.textTheme.bodyMedium),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const SectionHeader(title: '关于'),
          AppCard(
            child: _SettingRow(
              icon: Icons.info_outline_rounded,
              title: '版本',
              trailing: Text('v0.3.0', style: theme.textTheme.bodyMedium),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.icon,
    required this.title,
    required this.trailing,
  });

  final IconData icon;
  final String title;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 22, color: AppColors.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.bodyLarge),
        ),
        trailing,
      ],
    );
  }
}
