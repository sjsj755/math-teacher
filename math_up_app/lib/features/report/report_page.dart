import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/application/db_initializer.dart';
import '../../core/application/diagnosis_service.dart';
import '../../core/domain/models/diagnosis.dart';
import '../../core/router.dart';
import '../../core/theme.dart';
import '../../core/ui/app_buttons.dart';
import '../../core/ui/app_card.dart';
import '../../core/ui/app_chip.dart';
import '../../core/ui/empty_state.dart';
import '../../core/ui/section_header.dart';

/// 报告页：得分摘要＋四因子雷达图＋薄弱点＋归因。
class ReportPage extends StatefulWidget {
  const ReportPage({super.key, required this.dbInitController, this.result});

  final DbInitController dbInitController;
  final DiagnosisResult? result;

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  DiagnosisResult? _result;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    if (widget.result != null) {
      _result = widget.result;
      _loading = false;
    } else {
      _loadLatest();
    }
  }

  Future<void> _loadLatest() async {
    final db = widget.dbInitController.database;
    if (db == null) {
      widget.dbInitController.addListener(_onDbReady);
      return;
    }
    await _loadFrom(db);
  }

  void _onDbReady() {
    final db = widget.dbInitController.database;
    if (db != null) {
      widget.dbInitController.removeListener(_onDbReady);
      _loadFrom(db);
    }
  }

  Future<void> _loadFrom(Database db) async {
    final result = await DiagnosisService(db: db).latestResult();
    if (!mounted) return;
    setState(() {
      _result = result;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('学情报告')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _result == null
          ? const EmptyState(title: '还没有诊断记录', subtitle: '完成一次诊断后，这里会生成你的学情报告。')
          : _ReportContent(result: _result!),
    );
  }
}

class _ReportContent extends StatelessWidget {
  const _ReportContent({required this.result});

  final DiagnosisResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('综合得分', style: theme.textTheme.bodySmall),
              const SizedBox(height: 4),
              Text(
                '${(result.overall * 100).round()}%',
                style: theme.textTheme.displaySmall?.copyWith(
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _factorChip('知识', result.kScore, Icons.lightbulb_rounded),
                  _factorChip('思维', result.tScore, Icons.psychology_rounded),
                  _factorChip('规范', result.sScore, Icons.rule_rounded),
                  _factorChip('临场', result.pScore, Icons.timer_rounded),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const SectionHeader(title: '四因子雷达图'),
        AppCard(child: SizedBox(height: 280, child: RadarChart(_radarData()))),
        const SizedBox(height: 24),
        const SectionHeader(title: '薄弱知识点'),
        AppCard(
          child: result.weakPoints.isEmpty
              ? Text('本次诊断没有薄弱点，继续保持', style: theme.textTheme.bodyMedium)
              : Column(
                  children: [
                    for (final point in result.weakPoints)
                      _WeakPointRow(point: point),
                  ],
                ),
        ),
        const SizedBox(height: 24),
        const SectionHeader(title: '归因清单'),
        AppCard(
          child: result.attribution.isEmpty
              ? Text('暂无归因', style: theme.textTheme.bodyMedium)
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final item in result.attribution)
                      AppChip(
                        label: '${item.label} ×${item.count}',
                        icon: Icons.flag_rounded,
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 24),
        AppFilledButton(
          onPressed: () => Navigator.pushNamed(context, AppRoutes.practice),
          child: const Text('开始练习'),
        ),
      ],
    );
  }

  Widget _factorChip(String name, double score, IconData icon) {
    return AppChip(label: '$name ${(score * 100).round()}%', icon: icon);
  }

  RadarChartData _radarData() {
    return RadarChartData(
      dataSets: [
        RadarDataSet(
          dataEntries: [
            RadarEntry(value: result.kScore * 100),
            RadarEntry(value: result.tScore * 100),
            RadarEntry(value: result.sScore * 100),
            RadarEntry(value: result.pScore * 100),
          ],
          fillColor: AppColors.primary.withValues(alpha: 0.18),
          borderColor: AppColors.primary,
          borderWidth: 2,
        ),
      ],
      radarShape: RadarShape.polygon,
      getTitle: (index, angle) {
        const titles = ['知识', '思维', '规范', '临场'];
        return RadarChartTitle(text: titles[index]);
      },
      titleTextStyle: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      titlePositionPercentageOffset: 0.12,
      tickCount: 4,
      gridBorderData: const BorderSide(color: Color(0xFFE6F0EE), width: 1),
      radarBorderData: const BorderSide(color: AppColors.outline, width: 1.5),
      tickBorderData: const BorderSide(color: Color(0xFFE6F0EE), width: 1),
    );
  }
}

class _WeakPointRow extends StatelessWidget {
  const _WeakPointRow({required this.point});

  final WeakPoint point;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(point.name, style: theme.textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(
                  '${point.code} · 答对 ${point.correct}/${point.total}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Text(
            '${(point.accuracy * 100).round()}%',
            style: theme.textTheme.titleMedium?.copyWith(
              color: point.accuracy < 0.4
                  ? AppColors.wrong
                  : AppColors.warmIcon,
            ),
          ),
        ],
      ),
    );
  }
}
