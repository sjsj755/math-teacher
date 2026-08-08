import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/application/db_initializer.dart';
import '../../core/application/diagnosis_assembler.dart';
import '../../core/application/diagnosis_service.dart';
import '../../core/domain/models/diagnosis.dart';
import '../../core/domain/models/question.dart';
import '../../core/infrastructure/app_config_repository.dart';
import '../../core/router.dart';
import '../../core/theme.dart';
import '../../core/ui/app_buttons.dart';
import '../../core/ui/app_card.dart';
import '../../core/ui/app_chip.dart';
import '../../core/ui/app_progress.dart';
import '../../core/ui/geo_spirit.dart';
import '../../core/ui/latex_text.dart';
import '../report/report_page.dart';

/// 诊断页：15 题顺序作答（含填空与限时题），提交后弹完成层再进报告。
class DiagnosisPage extends StatefulWidget {
  const DiagnosisPage({super.key, required this.dbInitController});

  final DbInitController dbInitController;

  @override
  State<DiagnosisPage> createState() => _DiagnosisPageState();
}

class _DiagnosisPageState extends State<DiagnosisPage> {
  DiagnosisSession? _session;
  String? _error;
  bool _starting = true;
  int _index = 0;

  final Map<String, String> _choice = {};
  final Map<String, int> _selfOption = {};
  final Map<String, String> _fillText = {};
  final Map<String, bool> _timedOut = {};
  final Map<String, int> _seconds = {};
  final Map<String, TextEditingController> _fillControllers = {};

  Timer? _timer;
  int _remaining = 0;
  DateTime? _questionStartedAt;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final controller in _fillControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _start() async {
    final db = widget.dbInitController.database;
    if (db == null) {
      widget.dbInitController.addListener(_onDbReady);
      return;
    }
    await _buildSession(db);
  }

  void _onDbReady() {
    final db = widget.dbInitController.database;
    if (db != null) {
      widget.dbInitController.removeListener(_onDbReady);
      _buildSession(db);
    }
  }

  Future<void> _buildSession(Database db) async {
    final grade = await AppConfigRepository(db).get('grade');
    if (grade == null || grade.isEmpty) {
      if (mounted) {
        Navigator.pushReplacementNamed(context, AppRoutes.onboarding);
      }
      return;
    }
    try {
      final session = await DiagnosisService(db: db).startSession(grade);
      if (!mounted) return;
      setState(() {
        _session = session;
        _starting = false;
      });
      _startQuestionTimer();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _starting = false;
      });
    }
  }

  DiagnosisQuestion get _current => _session!.questions[_index];

  void _startQuestionTimer() {
    _timer?.cancel();
    final current = _current;
    _questionStartedAt = DateTime.now();
    if (!current.timed) {
      setState(() {});
      return;
    }
    _remaining = _session!.config.choiceLimitSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _remaining--);
      if (_remaining <= 0) {
        timer.cancel();
        _timedOut[current.question.id] = true;
        _seconds[current.question.id] = _session!.config.choiceLimitSeconds;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('时间到，本题计为错误')));
        _goNext();
      }
    });
  }

  bool get _currentAnswered {
    final question = _current.question;
    switch (question.type) {
      case QuestionType.choice:
        return _choice[question.id] != null;
      case QuestionType.fill:
        return (_fillText[question.id] ?? '').trim().isNotEmpty;
      case QuestionType.selfS:
      case QuestionType.selfP:
        return _selfOption[question.id] != null;
      case QuestionType.essay:
        return true;
    }
  }

  void _recordSeconds() {
    final current = _current;
    if (_seconds.containsKey(current.question.id)) {
      return;
    }
    final start = _questionStartedAt;
    _seconds[current.question.id] = start == null
        ? 0
        : DateTime.now().difference(start).inSeconds;
  }

  void _goPrev() {
    if (_index == 0) return;
    _recordSeconds();
    _timer?.cancel();
    setState(() => _index--);
    _startQuestionTimer();
  }

  void _goNext() {
    if (!_currentAnswered && !(_timedOut[_current.question.id] ?? false)) {
      return;
    }
    _recordSeconds();
    _timer?.cancel();
    if (_index == _session!.questions.length - 1) {
      _submit();
    } else {
      setState(() => _index++);
      _startQuestionTimer();
    }
  }

  Future<void> _submit() async {
    final session = _session!;
    final answers = <DiagnosisAnswer>[
      for (final item in session.questions)
        DiagnosisAnswer(
          question: item.question,
          group: item.group,
          timed: item.timed,
          selectedOption: _choice[item.question.id],
          fillText: _fillText[item.question.id],
          selfOption: _selfOption[item.question.id],
          timedOut: _timedOut[item.question.id] ?? false,
          seconds: _seconds[item.question.id] ?? 0,
        ),
    ];
    try {
      final result = await DiagnosisService(
        db: widget.dbInitController.database!,
      ).submitDiagnosis(answers, gradeFallback: session.gradeFallback);
      if (!mounted) return;
      _showCompletion(result);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('提交失败：$e')));
    }
  }

  Future<void> _showCompletion(DiagnosisResult result) async {
    final theme = Theme.of(context);
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const GeoSpirit(
                size: 110,
                mood: GeoSpiritMood.happy,
                showBubbles: true,
              ),
              const SizedBox(height: 12),
              Text('诊断完成', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                '综合得分 ${(result.overall * 100).round()}%',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  AppChip(label: '知识 ${(result.kScore * 100).round()}%'),
                  AppChip(
                    label: '思维 ${(result.tScore * 100).round()}%',
                    backgroundColor: AppColors.secondaryContainer,
                    foregroundColor: AppColors.onSecondaryContainer,
                  ),
                  AppChip(
                    label: '规范 ${(result.sScore * 100).round()}%',
                    backgroundColor: AppColors.tertiaryContainer,
                    foregroundColor: AppColors.warmIcon,
                  ),
                  AppChip(
                    label: '临场 ${(result.pScore * 100).round()}%',
                    backgroundColor: const Color(0xFFE8F1F5),
                    foregroundColor: const Color(0xFF3B6E8F),
                  ),
                ],
              ),
              if (result.weakPoints.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  '发现 ${result.weakPoints.length} 个薄弱知识点',
                  style: theme.textTheme.bodySmall,
                ),
              ],
              if (result.gradeFallback) ...[
                const SizedBox(height: 6),
                Text(
                  '部分年级题库未覆盖，本次使用现有题目',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.warmIcon,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              AppFilledButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => ReportPage(
                        dbInitController: widget.dbInitController,
                        result: result,
                      ),
                    ),
                  );
                },
                child: const Text('查看报告'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_starting) {
      return Scaffold(
        appBar: AppBar(title: const Text('诊断测试')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('诊断测试')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: AppColors.wrong,
                  size: 48,
                ),
                const SizedBox(height: 12),
                Text('诊断加载失败', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                AppFilledButton(
                  onPressed: () {
                    setState(() {
                      _error = null;
                      _starting = true;
                    });
                    _start();
                  },
                  child: const Text('重试'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final session = _session!;
    final current = _current;
    final theme = Theme.of(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final abandon = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('放弃本次诊断？'),
            content: const Text('当前进度不会保存。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('继续诊断'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('放弃'),
              ),
            ],
          ),
        );
        if (abandon != true) return;
        if (!context.mounted) return;
        Navigator.pop(context);
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('诊断测试')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            AppProgressBar(value: (_index + 1) / session.questions.length),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  '第 ${_index + 1} / ${session.questions.length} 题',
                  style: theme.textTheme.bodySmall,
                ),
                const Spacer(),
                AppChip(
                  label: _groupLabel(current.group),
                  icon: _groupIcon(current.group),
                ),
                if (current.timed) ...[
                  const SizedBox(width: 8),
                  _TimerChip(remaining: _remaining),
                ],
              ],
            ),
            const SizedBox(height: 12),
            AppCard(
              child: LatexText(
                current.question.stem,
                style: theme.textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: 16),
            ..._answerArea(current),
            const SizedBox(height: 20),
            Row(
              children: [
                if (_index > 0)
                  AppSoftButton(
                    onPressed: _goPrev,
                    expanded: false,
                    child: const Text('上一题'),
                  ),
                const Spacer(),
                AppFilledButton(
                  onPressed:
                      (_currentAnswered ||
                          (_timedOut[current.question.id] ?? false))
                      ? _goNext
                      : null,
                  expanded: false,
                  child: Text(
                    _index == session.questions.length - 1 ? '提交' : '下一题',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _answerArea(DiagnosisQuestion item) {
    final question = item.question;
    switch (question.type) {
      case QuestionType.choice:
      case QuestionType.selfS:
      case QuestionType.selfP:
        return [
          for (var i = 0; i < question.options.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _OptionCard(
                label: String.fromCharCode(65 + i),
                text: question.options[i],
                selected: question.type == QuestionType.choice
                    ? _choice[question.id] == String.fromCharCode(65 + i)
                    : _selfOption[question.id] == i,
                onTap: () => setState(() {
                  if (question.type == QuestionType.choice) {
                    _choice[question.id] = String.fromCharCode(65 + i);
                  } else {
                    _selfOption[question.id] = i;
                  }
                }),
              ),
            ),
        ];
      case QuestionType.fill:
        final controller = _fillControllers.putIfAbsent(question.id, () {
          final textController = TextEditingController(
            text: _fillText[question.id] ?? '',
          );
          textController.addListener(() {
            _fillText[question.id] = textController.text;
          });
          return textController;
        });
        return [
          TextField(
            controller: controller,
            keyboardType: TextInputType.text,
            style: Theme.of(context).textTheme.bodyLarge,
            decoration: const InputDecoration(
              hintText: '请输入你的答案',
              prefixIcon: Icon(Icons.edit_rounded),
            ),
            onSubmitted: (_) => _goNext(),
          ),
        ];
      case QuestionType.essay:
        return const [];
    }
  }

  String _groupLabel(DiagnosisGroup group) {
    return switch (group) {
      DiagnosisGroup.k => '知识 K',
      DiagnosisGroup.t => '思维 T',
      DiagnosisGroup.s => '规范 S',
      DiagnosisGroup.p => '临场 P',
    };
  }

  IconData _groupIcon(DiagnosisGroup group) {
    return switch (group) {
      DiagnosisGroup.k => Icons.lightbulb_rounded,
      DiagnosisGroup.t => Icons.psychology_rounded,
      DiagnosisGroup.s => Icons.rule_rounded,
      DiagnosisGroup.p => Icons.timer_rounded,
    };
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.label,
    required this.text,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String text;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      onTap: onTap,
      borderColor: selected ? AppColors.primary : null,
      color: selected ? AppColors.primaryContainer : AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 13,
            backgroundColor: selected
                ? AppColors.primary
                : AppColors.background,
            child: Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                fontSize: 13,
                color: selected ? Colors.white : AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: LatexText(text, style: theme.textTheme.bodyLarge)),
          if (selected)
            const Padding(
              padding: EdgeInsets.only(left: 6, top: 2),
              child: Icon(
                Icons.check_circle_rounded,
                size: 18,
                color: AppColors.primary,
              ),
            ),
        ],
      ),
    );
  }
}

class _TimerChip extends StatelessWidget {
  const _TimerChip({required this.remaining});

  final int remaining;

  @override
  Widget build(BuildContext context) {
    final minutes = (remaining ~/ 60).toString().padLeft(2, '0');
    final seconds = (remaining % 60).toString().padLeft(2, '0');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.tertiaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timer_outlined, size: 14, color: AppColors.warmIcon),
          const SizedBox(width: 4),
          Text(
            '$minutes:$seconds',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.warmIcon,
            ),
          ),
        ],
      ),
    );
  }
}
