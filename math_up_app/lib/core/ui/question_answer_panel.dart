import 'package:flutter/material.dart';

import '../domain/models/question.dart';
import '../theme.dart';
import 'app_card.dart';
import 'latex_text.dart';

/// 共享作答面板：选择题选项卡、自评选项、填空输入（诊断与练习复用）。
class QuestionAnswerPanel extends StatefulWidget {
  const QuestionAnswerPanel({
    super.key,
    required this.question,
    this.initialOption,
    this.initialSelfOption,
    this.initialFillText,
    this.onOptionChanged,
    this.onSelfOptionChanged,
    this.onFillChanged,
    this.onFillSubmitted,
  });

  final Question question;
  final String? initialOption;
  final int? initialSelfOption;
  final String? initialFillText;
  final ValueChanged<String>? onOptionChanged;
  final ValueChanged<int>? onSelfOptionChanged;
  final ValueChanged<String>? onFillChanged;
  final ValueChanged<String>? onFillSubmitted;

  @override
  State<QuestionAnswerPanel> createState() => _QuestionAnswerPanelState();
}

class _QuestionAnswerPanelState extends State<QuestionAnswerPanel> {
  String? _selectedOption;
  int? _selfOption;
  TextEditingController? _fillController;

  @override
  void initState() {
    super.initState();
    _selectedOption = widget.initialOption;
    _selfOption = widget.initialSelfOption;
    if (widget.question.type == QuestionType.fill) {
      _fillController = TextEditingController(
        text: widget.initialFillText ?? '',
      );
      _fillController!.addListener(_onFillChanged);
    }
  }

  void _onFillChanged() {
    widget.onFillChanged?.call(_fillController!.text);
  }

  @override
  void dispose() {
    _fillController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final question = widget.question;
    switch (question.type) {
      case QuestionType.choice:
      case QuestionType.selfS:
      case QuestionType.selfP:
        return Column(
          children: [
            for (var i = 0; i < question.options.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _AnswerOptionCard(
                  label: String.fromCharCode(65 + i),
                  text: question.options[i],
                  selected: question.type == QuestionType.choice
                      ? _selectedOption == String.fromCharCode(65 + i)
                      : _selfOption == i,
                  onTap: () => setState(() {
                    if (question.type == QuestionType.choice) {
                      _selectedOption = String.fromCharCode(65 + i);
                      widget.onOptionChanged?.call(_selectedOption!);
                    } else {
                      _selfOption = i;
                      widget.onSelfOptionChanged?.call(i);
                    }
                  }),
                ),
              ),
          ],
        );
      case QuestionType.fill:
        return TextField(
          controller: _fillController,
          keyboardType: TextInputType.text,
          style: Theme.of(context).textTheme.bodyLarge,
          decoration: const InputDecoration(
            hintText: '请输入你的答案',
            prefixIcon: Icon(Icons.edit_rounded),
          ),
          onSubmitted: widget.onFillSubmitted,
        );
      case QuestionType.essay:
        return const SizedBox.shrink();
    }
  }
}

class _AnswerOptionCard extends StatelessWidget {
  const _AnswerOptionCard({
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
