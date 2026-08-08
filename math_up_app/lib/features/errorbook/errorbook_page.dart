import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/application/db_initializer.dart';
import '../../core/domain/models/practice.dart';
import '../../core/domain/models/question.dart';
import '../../core/infrastructure/error_book_repository.dart';
import '../../core/infrastructure/question_repository_impl.dart';
import '../../core/theme.dart';
import '../../core/ui/app_buttons.dart';
import '../../core/ui/app_card.dart';
import '../../core/ui/app_chip.dart';
import '../../core/ui/empty_state.dart';
import '../../core/ui/latex_text.dart';
import '../practice/practice_page.dart';

/// 错题本：状态筛选、错题卡片、重做与周清入口。
class ErrorbookPage extends StatefulWidget {
  const ErrorbookPage({super.key, required this.dbInitController});

  final DbInitController dbInitController;

  @override
  State<ErrorbookPage> createState() => _ErrorbookPageState();
}

class _ErrorbookPageState extends State<ErrorbookPage> {
  List<ErrorBookEntry> _entries = [];
  Map<String, Question> _questionsById = {};
  bool _loading = true;
  String _filter = '全部';

  static const _filters = <String>['全部', '待重做', '观察中', '已掌握'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
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
    final entries = await ErrorBookRepository(db).listAll();
    final questions = await SqliteQuestionRepository(db).all();
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _questionsById = {for (final q in questions) q.id: q};
      _loading = false;
    });
  }

  List<ErrorBookEntry> get _filtered {
    return switch (_filter) {
      '待重做' =>
        _entries
            .where(
              (e) =>
                  e.status == ErrorBookStatus.pending ||
                  e.status == ErrorBookStatus.pendingUpgrade,
            )
            .toList(),
      '观察中' =>
        _entries.where((e) => e.status == ErrorBookStatus.redone).toList(),
      '已掌握' =>
        _entries.where((e) => e.status == ErrorBookStatus.mastered).toList(),
      _ => _entries,
    };
  }

  Future<void> _openPractice(PracticeMode mode) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) =>
            PracticePage(dbInitController: widget.dbInitController, mode: mode),
      ),
    );
    _load();
  }

  bool get _hasRedo => _entries.any(
    (e) =>
        e.status == ErrorBookStatus.pending ||
        e.status == ErrorBookStatus.pendingUpgrade,
  );

  bool get _hasDueReview {
    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    return _entries.any((e) {
      if (e.status != ErrorBookStatus.redone || e.reviewAt == null) {
        return false;
      }
      return !e.reviewAt!.isAfter(today);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('错题本')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _entries.isEmpty
          ? const EmptyState(
              title: '还没有错题',
              subtitle: '完成练习后，答错的题目会自动收录到这里，支持重做与周清。',
            )
          : _buildList(context),
    );
  }

  Widget _buildList(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final filter in _filters)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(filter),
                    selected: _filter == filter,
                    onSelected: (_) => setState(() => _filter = filter),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        for (final entry in _filtered) ...[
          _ErrorCard(entry: entry, question: _questionsById[entry.questionId]),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: AppSoftButton(
                onPressed: _hasRedo
                    ? () => _openPractice(PracticeMode.redo)
                    : null,
                child: const Text('重做错题'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppFilledButton(
                onPressed: _hasDueReview
                    ? () => _openPractice(PracticeMode.weekly)
                    : null,
                child: const Text('周清复测'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.entry, required this.question});

  final ErrorBookEntry entry;
  final Question? question;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (question == null) {
      return const SizedBox.shrink();
    }
    final statusLabel = switch (entry.status) {
      ErrorBookStatus.pending => '待重做',
      ErrorBookStatus.redone => '观察中',
      ErrorBookStatus.mastered => '已掌握',
      ErrorBookStatus.pendingUpgrade => '升级待重做',
    };
    return AppCard(
      onTap: () => _showDetail(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _StatusBadge(status: entry.status, label: statusLabel),
              const Spacer(),
              Text('重做 ${entry.redoCount} 次', style: theme.textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: 8),
          LatexText(
            question!.stem,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium,
          ),
          if (entry.status == ErrorBookStatus.redone &&
              entry.reviewAt != null) ...[
            const SizedBox(height: 6),
            Text(
              '复测日期：${_date(entry.reviewAt!)}',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }

  String _date(DateTime date) {
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '${date.year}-$m-$d';
  }

  Future<void> _showDetail(BuildContext context) async {
    final question = this.question!;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('错题解析'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LatexText(question.stem),
              const SizedBox(height: 12),
              Text('正确答案：${question.answer}'),
              if (question.explain != null && question.explain!.isNotEmpty) ...[
                const SizedBox(height: 8),
                LatexText(question.explain!),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status, required this.label});

  final ErrorBookStatus status;
  final String label;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (status) {
      ErrorBookStatus.pending => (
        AppColors.secondaryContainer,
        AppColors.onSecondaryContainer,
      ),
      ErrorBookStatus.redone => (
        AppColors.tertiaryContainer,
        AppColors.warmIcon,
      ),
      ErrorBookStatus.mastered => (
        AppColors.primaryContainer,
        AppColors.onPrimaryContainer,
      ),
      ErrorBookStatus.pendingUpgrade => (
        const Color(0xFFFFE3E1),
        AppColors.wrong,
      ),
    };
    return AppChip(
      label: label,
      backgroundColor: background,
      foregroundColor: foreground,
    );
  }
}
