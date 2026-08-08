import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/application/db_initializer.dart';
import '../../core/application/practice_service.dart';
import '../../core/domain/models/practice.dart';
import '../../core/domain/models/question.dart';
import '../../core/theme.dart';
import '../../core/ui/app_buttons.dart';
import '../../core/ui/app_card.dart';
import '../../core/ui/app_progress.dart';
import '../../core/ui/empty_state.dart';
import '../../core/ui/geo_spirit.dart';
import '../../core/ui/latex_text.dart';
import '../../core/ui/question_answer_panel.dart';

/// 练习页：推荐练习 / 错题重做 / 周清复测，逐题限时＋即时反馈。
class PracticePage extends StatefulWidget {
  const PracticePage({
    super.key,
    required this.dbInitController,
    required this.mode,
  });

  final DbInitController dbInitController;
  final PracticeMode mode;

  @override
  State<PracticePage> createState() => _PracticePageState();
}

class _PracticePageState extends State<PracticePage> {
  PracticeSession? _session;
  String? _error;
  bool _loading = true;
  int _index = 0;
  PracticeFeedback? _feedback;

  final Map<String, String> _selectedOption = {};
  final Map<String, String> _fillText = {};

  Timer? _timer;
  int _remaining = 0;
  DateTime? _questionStartedAt;
  int _correctCount = 0;
  int _addedErrorCount = 0;

  String get _title => switch (widget.mode) {
    PracticeMode.recommend => '练习',
    PracticeMode.redo => '错题重做',
    PracticeMode.weekly => '周清复测',
  };

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _timer?.cancel();
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
    try {
      final service = PracticeService(db: db);
      final session = switch (widget.mode) {
        PracticeMode.recommend => await service.startRecommendSession(
          await _readGrade(db),
        ),
        PracticeMode.redo => await service.startRedoSession(),
        PracticeMode.weekly => await service.startWeeklySession(),
      };
      if (!mounted) return;
      setState(() {
        _session = session;
        _loading = false;
      });
      _startQuestionTimer();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<String> _readGrade(Database db) async {
    final rows = await db.query(
      'app_config',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: ['grade'],
      limit: 1,
    );
    final grade = rows.isEmpty ? null : rows.first['value'] as String;
    return (grade == null || grade.isEmpty) ? '高一' : grade;
  }

  PracticeQuestion get _current => _session!.questions[_index];

  int get _questionLimit {
    return _current.question.type == QuestionType.fill
        ? _session!.config.fillLimitSeconds
        : _session!.config.choiceLimitSeconds;
  }

  void _startQuestionTimer() {
    _timer?.cancel();
    _questionStartedAt = DateTime.now();
    _remaining = _questionLimit;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _remaining--);
      if (_remaining <= 0) {
        timer.cancel();
        _submit(timedOut: true);
      }
    });
  }

  bool get _currentAnswered {
    final question = _current.question;
    switch (question.type) {
      case QuestionType.choice:
        return _selectedOption[question.id] != null;
      case QuestionType.fill:
        return (_fillText[question.id] ?? '').trim().isNotEmpty;
      default:
        return false;
    }
  }

  Future<void> _submit({bool timedOut = false}) async {
    final current = _current;
    final start = _questionStartedAt;
    final seconds = timedOut
        ? _questionLimit
        : (start == null ? 0 : DateTime.now().difference(start).inSeconds);
    final answer = PracticeAnswer(
      question: current.question,
      selectedOption: _selectedOption[current.question.id],
      fillText: _fillText[current.question.id],
      timedOut: timedOut,
      seconds: seconds,
    );
    try {
      final feedback = await PracticeService(
        db: widget.dbInitController.database!,
      ).submitAnswer(_session!, answer);
      if (!mounted) return;
      _timer?.cancel();
      setState(() {
        _feedback = feedback;
        if (feedback.correct) {
          _correctCount++;
        }
        if (feedback.addedToErrorBook) {
          _addedErrorCount++;
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('提交失败：$e')));
    }
  }

  void _next() {
    _timer?.cancel();
    if (_index == _session!.questions.length - 1) {
      _showCompletion();
    } else {
      setState(() {
        _index++;
        _feedback = null;
      });
      _startQuestionTimer();
    }
  }

  Future<void> _showCompletion() async {
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
              Text('练习完成', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                '答对 $_correctCount / ${_session!.questions.length}',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: AppColors.primary,
                ),
              ),
              if (_addedErrorCount > 0) ...[
                const SizedBox(height: 6),
                Text(
                  '新增错题 $_addedErrorCount 道，已收录错题本',
                  style: theme.textTheme.bodySmall,
                ),
              ] else ...[
                const SizedBox(height: 6),
                Text('继续保持，没有新增错题', style: theme.textTheme.bodySmall),
              ],
              const SizedBox(height: 20),
              AppFilledButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  Navigator.pop(context);
                },
                child: const Text('返回'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(_title)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: Text(_title)),
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
                Text('加载失败', style: Theme.of(context).textTheme.titleMedium),
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
                      _loading = true;
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
    if (_session!.questions.isEmpty) {
      final (title, subtitle) = switch (widget.mode) {
        PracticeMode.recommend => ('暂无可推荐题目', '请先完成一次诊断，或稍后再来。'),
        PracticeMode.redo => ('没有待重做的错题', '完成练习后，答错的题目会自动收录到这里。'),
        PracticeMode.weekly => ('本周没有到期复测', '观察期（7 天）到期的错题会自动进入周清。'),
      };
      return Scaffold(
        appBar: AppBar(title: Text(_title)),
        body: Column(
          children: [
            Expanded(
              child: EmptyState(title: title, subtitle: subtitle),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: AppSoftButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('返回'),
              ),
            ),
          ],
        ),
      );
    }

    final session = _session!;
    final current = _current;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(_title)),
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
              if (_feedback == null) _TimerChip(remaining: _remaining),
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
          if (_feedback == null)
            ..._answeringArea(current)
          else
            _FeedbackCard(feedback: _feedback!),
          const SizedBox(height: 20),
          if (_feedback == null)
            AppFilledButton(
              onPressed: _currentAnswered ? () => _submit() : null,
              child: const Text('提交答案'),
            )
          else
            AppFilledButton(
              onPressed: _next,
              child: Text(
                _index == session.questions.length - 1 ? '查看结果' : '下一题',
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _answeringArea(PracticeQuestion item) {
    final question = item.question;
    return [
      QuestionAnswerPanel(
        key: ValueKey(question.id),
        question: question,
        initialOption: _selectedOption[question.id],
        initialFillText: _fillText[question.id],
        onOptionChanged: (letter) =>
            setState(() => _selectedOption[question.id] = letter),
        onFillChanged: (text) => setState(() => _fillText[question.id] = text),
        onFillSubmitted: (_) {
          if (_currentAnswered) {
            _submit();
          }
        },
      ),
    ];
  }
}

class _FeedbackCard extends StatelessWidget {
  const _FeedbackCard({required this.feedback});

  final PracticeFeedback feedback;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = feedback.correct ? AppColors.correct : AppColors.wrong;
    return AppCard(
      borderColor: color.withValues(alpha: 0.45),
      color: color.withValues(alpha: 0.06),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                feedback.correct
                    ? Icons.check_circle_rounded
                    : Icons.cancel_rounded,
                color: color,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                feedback.correct ? '回答正确' : '回答错误',
                style: theme.textTheme.titleMedium?.copyWith(color: color),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(feedback.answerText, style: theme.textTheme.bodyMedium),
          if (feedback.explain.isNotEmpty) ...[
            const SizedBox(height: 6),
            LatexText(feedback.explain, style: theme.textTheme.bodyMedium),
          ],
          if (feedback.statusMessage != null) ...[
            const SizedBox(height: 10),
            Text(
              feedback.statusMessage!,
              style: theme.textTheme.labelMedium?.copyWith(
                color: AppColors.primary,
              ),
            ),
          ] else if (feedback.addedToErrorBook) ...[
            const SizedBox(height: 10),
            Text(
              '已收录错题本，可在“错题本”中重做',
              style: theme.textTheme.labelMedium?.copyWith(
                color: AppColors.primary,
              ),
            ),
          ],
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
