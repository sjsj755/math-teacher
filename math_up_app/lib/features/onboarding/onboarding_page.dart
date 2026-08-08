import 'package:flutter/material.dart';

import '../../core/application/db_initializer.dart';
import '../../core/infrastructure/app_config_repository.dart';
import '../../core/router.dart';
import '../../core/theme.dart';
import '../../core/ui/app_buttons.dart';
import '../../core/ui/app_card.dart';
import '../../core/ui/geo_spirit.dart';
import '../../core/ui/section_header.dart';

/// 年级选择页：欢迎卡＋开心态小精灵＋三张年级卡。
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key, required this.dbInitController});

  final DbInitController dbInitController;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  static const _grades = [
    (title: '高一', subtitle: '必修第一、二册', icon: Icons.one_k_rounded),
    (title: '高二', subtitle: '选择性必修三册', icon: Icons.two_k_rounded),
    (title: '高三', subtitle: '全部章节＋综合复习', icon: Icons.workspace_premium_rounded),
  ];

  String? _selected;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentGrade();
  }

  Future<void> _loadCurrentGrade() async {
    final db = widget.dbInitController.database;
    String? grade;
    if (db != null) {
      grade = await AppConfigRepository(db).get('grade');
    }
    if (!mounted) return;
    setState(() {
      _selected = (grade == null || grade.isEmpty) ? null : grade;
      _loading = false;
    });
  }

  Future<void> _start() async {
    final grade = _selected;
    if (grade == null) return;
    final db = widget.dbInitController.database;
    if (db != null) {
      await AppConfigRepository(db).set('grade', grade);
    }
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, AppRoutes.diagnosis);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('年级选择')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                AppCard(
                  color: AppColors.cream,
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      const GeoSpirit(
                        size: 96,
                        mood: GeoSpiritMood.happy,
                        showBubbles: true,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('欢迎来到数学提升', style: theme.textTheme.titleLarge),
                            const SizedBox(height: 6),
                            Text(
                              '先选择你的年级，\n诊断和练习会按年级出题',
                              style: theme.textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const SectionHeader(title: '选择你的年级'),
                for (final grade in _grades)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _GradeCard(
                      title: grade.title,
                      subtitle: grade.subtitle,
                      icon: grade.icon,
                      selected: _selected == grade.title,
                      onTap: () => setState(() => _selected = grade.title),
                    ),
                  ),
                const SizedBox(height: 8),
                AppFilledButton(
                  onPressed: _selected == null ? null : _start,
                  child: const Text('开始诊断'),
                ),
              ],
            ),
    );
  }
}

class _GradeCard extends StatelessWidget {
  const _GradeCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      borderColor: selected ? AppColors.primary : null,
      color: selected ? AppColors.primaryContainer : AppColors.surface,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: selected ? AppColors.primary : AppColors.primaryContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              color: selected ? Colors.white : AppColors.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          if (selected)
            const Icon(
              Icons.check_circle_rounded,
              color: AppColors.primary,
              size: 24,
            ),
        ],
      ),
    );
  }
}
