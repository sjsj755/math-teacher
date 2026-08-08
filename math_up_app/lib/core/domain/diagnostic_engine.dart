import 'models/diagnosis.dart';
import 'models/question.dart';
import 'answer_grading.dart';

/// 诊断评分规则引擎（纯函数，对应开发文档 4.5）。
abstract final class DiagnosticEngine {
  static const Map<LoseType, String> labels = {
    LoseType.knowledge: '知识性失分',
    LoseType.method: '方法性失分',
    LoseType.calculation: '运算性失分',
    LoseType.standard: '规范性失分',
    LoseType.psychology: '心理性失分',
  };

  static const List<String> _loseOrder = [
    'knowledge',
    'method',
    'calculation',
    'standard',
    'psychology',
  ];

  /// 计算四因子得分、薄弱知识点与归因清单。
  static DiagnosisResult evaluate({
    required List<DiagnosisAnswer> answers,
    required DiagnosisConfig config,
    DateTime? date,
    bool gradeFallback = false,
    int? diagnosisId,
  }) {
    double factor(DiagnosisGroup group) {
      final list = answers.where((a) => a.group == group).toList();
      if (list.isEmpty) return 0;
      final sum = list.fold<double>(0, (acc, a) => acc + _scoreOf(a));
      return sum / list.length;
    }

    final kScore = factor(DiagnosisGroup.k);
    final tScore = factor(DiagnosisGroup.t);
    final sScore = factor(DiagnosisGroup.s);
    final pScore = factor(DiagnosisGroup.p);

    final contentAnswers = answers
        .where(
          (a) =>
              a.question.type == QuestionType.choice ||
              a.question.type == QuestionType.fill,
        )
        .toList();
    final totalQuestions = contentAnswers.length;
    final totalCorrect = contentAnswers.where(isCorrect).length;

    final weakPoints = _weakPoints(
      answers
          .where(
            (a) => a.group == DiagnosisGroup.k || a.group == DiagnosisGroup.t,
          )
          .toList(),
      config.weakThreshold,
    );

    final attribution = _attribution(
      contentAnswers,
      sScore: sScore,
      pScore: pScore,
      weakThreshold: config.weakThreshold,
    );

    return DiagnosisResult(
      diagnosisId: diagnosisId,
      date: date ?? DateTime.now(),
      kScore: kScore,
      tScore: tScore,
      sScore: sScore,
      pScore: pScore,
      weakPoints: weakPoints,
      attribution: attribution,
      totalCorrect: totalCorrect,
      totalQuestions: totalQuestions,
      gradeFallback: gradeFallback,
    );
  }

  /// 单题得分：内容题 0/1，自评题 0/0.5/1。
  static double _scoreOf(DiagnosisAnswer a) {
    if (a.question.type == QuestionType.selfS ||
        a.question.type == QuestionType.selfP) {
      return selfScore(a.selfOption);
    }
    return isCorrect(a) ? 1 : 0;
  }

  /// 内容题是否正确（限时题超时一律计错）。
  static bool isCorrect(DiagnosisAnswer a) {
    return AnswerGrading.isCorrect(
      question: a.question,
      selectedOption: a.selectedOption,
      fillText: a.fillText,
      timedOut: a.timed && a.timedOut,
    );
  }

  /// 自评选项得分：第 0 项 1 分、第 1 项 0.5 分、其余 0 分。
  static double selfScore(int? option) {
    return AnswerGrading.selfScore(option);
  }

  /// 薄弱知识点：按节编码分组，≥2 题且正确率低于阈值，升序。
  static List<WeakPoint> _weakPoints(
    List<DiagnosisAnswer> answers,
    double threshold,
  ) {
    final grouped = <String, List<DiagnosisAnswer>>{};
    for (final a in answers) {
      grouped.putIfAbsent(a.question.variantGroup, () => []).add(a);
    }
    final result = <WeakPoint>[];
    for (final entry in grouped.entries) {
      final list = entry.value;
      if (list.length < 2) {
        continue;
      }
      final correct = list.where(isCorrect).length;
      final accuracy = correct / list.length;
      if (accuracy >= threshold) {
        continue;
      }
      result.add(
        WeakPoint(
          code: entry.key,
          name: list.first.question.knowledgePoint,
          correct: correct,
          total: list.length,
          accuracy: accuracy,
        ),
      );
    }
    result.sort((x, y) {
      final c = x.accuracy.compareTo(y.accuracy);
      return c != 0 ? c : x.code.compareTo(y.code);
    });
    return result;
  }

  /// 归因清单：错题 lose_type 计数前 2；S/P 因子低时补入规范/心理。
  static List<AttributionItem> _attribution(
    List<DiagnosisAnswer> contentAnswers, {
    required double sScore,
    required double pScore,
    required double weakThreshold,
  }) {
    final counts = <LoseType, int>{};
    for (final a in contentAnswers) {
      if (!isCorrect(a)) {
        counts[a.question.loseType] = (counts[a.question.loseType] ?? 0) + 1;
      }
    }
    if (sScore < weakThreshold) {
      counts[LoseType.standard] = (counts[LoseType.standard] ?? 0) + 1;
    }
    if (pScore < weakThreshold) {
      counts[LoseType.psychology] = (counts[LoseType.psychology] ?? 0) + 1;
    }
    final sorted = counts.entries.toList()
      ..sort((x, y) {
        final c = y.value.compareTo(x.value);
        if (c != 0) return c;
        return _loseOrder
            .indexOf(x.key.code)
            .compareTo(_loseOrder.indexOf(y.key.code));
      });
    return sorted
        .take(2)
        .map(
          (e) => AttributionItem(
            loseType: e.key,
            label: labels[e.key]!,
            count: e.value,
          ),
        )
        .toList();
  }
}
