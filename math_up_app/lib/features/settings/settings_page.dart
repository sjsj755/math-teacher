import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/application/db_initializer.dart';
import '../../core/theme.dart';
import '../../core/ui/app_buttons.dart';
import '../../core/ui/app_card.dart';
import '../../core/ui/section_header.dart';
import 'settings_controller.dart';

/// 设置页：家长通知（服务器地址 / 日报开关 / 推送时间 / 绑定码 / 解绑）与关于。
class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.dbInitController,
    this.controller,
  });

  final DbInitController dbInitController;

  /// 测试可注入控制器；为空时由页面按数据库构建。
  final SettingsController? controller;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  SettingsController? _controller;
  bool _ownsController = false;

  @override
  void initState() {
    super.initState();
    final provided = widget.controller;
    if (provided != null) {
      _controller = provided;
      provided.load();
    } else {
      widget.dbInitController.addListener(_maybeCreateController);
      _maybeCreateController();
    }
  }

  void _maybeCreateController() {
    if (_controller != null) {
      return;
    }
    final db = widget.dbInitController.database;
    if (db == null) {
      return;
    }
    _controller = SettingsController(db: db);
    _ownsController = true;
    _controller!.load();
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    if (!_ownsController) {
      _controller?.dispose();
    }
    widget.dbInitController.removeListener(_maybeCreateController);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: controller == null
          ? const Center(child: CircularProgressIndicator())
          : ListenableBuilder(
              listenable: controller,
              builder: (context, _) => _SettingsBody(controller: controller),
            ),
    );
  }
}

class _SettingsBody extends StatelessWidget {
  const _SettingsBody({required this.controller});

  final SettingsController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (!controller.loading &&
        !controller.bound &&
        controller.serverUrl.isNotEmpty) {
      controller.startPolling();
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        const SectionHeader(title: '家长通知'),
        AppCard(
          child: Column(
            children: [
              _TextSettingRow(
                icon: Icons.dns_rounded,
                title: '服务器地址',
                value: controller.serverUrl,
                hint: '如 http://192.168.1.10:8000/api/v1',
                onSaved: controller.saveServerUrl,
              ),
              const Divider(height: 24),
              _SettingRow(
                icon: Icons.notifications_active_rounded,
                title: '每日日报',
                trailing: Switch(
                  value: controller.dailyEnabled,
                  onChanged: controller.busy
                      ? null
                      : controller.setDailyEnabled,
                ),
              ),
              const Divider(height: 24),
              _SettingRow(
                icon: Icons.schedule_rounded,
                title: '推送时间',
                trailing: Text(
                  controller.pushTime,
                  style: theme.textTheme.bodyMedium,
                ),
                onTap: controller.busy ? null : () => _pickTime(context),
              ),
            ],
          ),
        ),
        if (controller.error != null) ...[
          const SizedBox(height: 12),
          AppCard(
            color: AppColors.wrong.withValues(alpha: 0.06),
            borderColor: AppColors.wrong.withValues(alpha: 0.35),
            child: Text(
              controller.error!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.wrong,
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        const SectionHeader(title: 'QQ 绑定'),
        if (controller.bound)
          _BoundCard(controller: controller)
        else
          _BindCodeCard(controller: controller),
        const SizedBox(height: 24),
        const SectionHeader(title: '关于'),
        AppCard(
          child: _SettingRow(
            icon: Icons.info_outline_rounded,
            title: '版本',
            trailing: Text(
              'v0.6.0',
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickTime(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _parseTime(controller.pushTime),
      helpText: '选择日报推送时间',
    );
    if (picked != null) {
      final value =
          '${picked.hour.toString().padLeft(2, '0')}:'
          '${picked.minute.toString().padLeft(2, '0')}';
      await controller.setPushTime(value);
    }
  }

  TimeOfDay _parseTime(String value) {
    final parts = value.split(':');
    if (parts.length == 2) {
      return TimeOfDay(
        hour: int.tryParse(parts[0]) ?? 21,
        minute: int.tryParse(parts[1]) ?? 30,
      );
    }
    return const TimeOfDay(hour: 21, minute: 30);
  }
}

class _BindCodeCard extends StatelessWidget {
  const _BindCodeCard({required this.controller});

  final SettingsController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final code = controller.bindCode;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('绑定码', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          if (code == null) ...[
            Text(
              controller.serverUrl.isEmpty
                  ? '请先在上方填写服务器地址，再生成绑定码。'
                  : '生成绑定码后，家长在 QQ 中发送“绑定 绑定码”即可关联。',
              style: theme.textTheme.bodySmall,
            ),
          ] else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              ),
              child: Text(
                code,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: AppColors.onPrimaryContainer,
                  letterSpacing: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 6),
            if (controller.bindCodeExpiresAt?.isNotEmpty == true)
              Text(
                '有效期至 ${controller.bindCodeExpiresAt}',
                style: theme.textTheme.bodySmall,
              ),
            const SizedBox(height: 8),
            Text(
              '在 QQ 中发送：绑定 $code',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.primary,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              AppFilledButton(
                onPressed: controller.busy
                    ? null
                    : () => controller.requestBindCode(),
                child: Text(code == null ? '生成绑定码' : '重新生成'),
              ),
              if (code != null) ...[
                AppSoftButton(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: '绑定 $code'));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('已复制，去 QQ 发送吧')),
                    );
                  },
                  child: const Text('复制指令'),
                ),
                AppSoftButton(
                  onPressed: controller.busy
                      ? null
                      : () => controller.confirmBind(),
                  child: const Text('已发送，确认绑定'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _BoundCard extends StatelessWidget {
  const _BoundCard({required this.controller});

  final SettingsController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      borderColor: AppColors.correct.withValues(alpha: 0.4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: AppColors.correct,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text('已绑定', style: theme.textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '家长：${controller.parentNick ?? '家长'}',
            style: theme.textTheme.bodyMedium,
          ),
          if (controller.lastPushAt?.isNotEmpty == true) ...[
            const SizedBox(height: 4),
            Text(
              '最近推送：${controller.lastPushAt}',
              style: theme.textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 14),
          AppSoftButton(
            onPressed: controller.busy ? null : () => _confirmUnbind(context),
            child: const Text('解绑'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmUnbind(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('确认解绑？'),
        content: const Text('解绑后家长将不再收到学习日报，可随时重新绑定。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('解绑'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await controller.unbind();
    }
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.icon,
    required this.title,
    required this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final Widget trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Icon(icon, size: 22, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(title, style: Theme.of(context).textTheme.bodyLarge),
            ),
            trailing,
          ],
        ),
      ),
    );
  }
}

class _TextSettingRow extends StatefulWidget {
  const _TextSettingRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.hint,
    required this.onSaved,
  });

  final IconData icon;
  final String title;
  final String value;
  final String hint;
  final ValueChanged<String> onSaved;

  @override
  State<_TextSettingRow> createState() => _TextSettingRowState();
}

class _TextSettingRowState extends State<_TextSettingRow> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Icon(
            widget.icon,
            size: 22,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            key: const ValueKey('server_url_field'),
            controller: _controller,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: widget.title,
              hintText: widget.hint,
              isDense: true,
            ),
            onSubmitted: widget.onSaved,
          ),
        ),
      ],
    );
  }
}
