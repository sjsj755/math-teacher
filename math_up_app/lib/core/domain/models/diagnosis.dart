import 'question.dart';

/// 诊断分组：知识 / 思维 / 规范 / 临场。
enum DiagnosisGroup { k, t, s, p }

/// 诊断会话中的一道题（题目＋所属组＋是否限时）。
class DiagnosisQuestion {
  const DiagnosisQuestion({
    required this.question,
    required this.group,
    this.timed = false,
  });

  final Question question;
  final DiagnosisGroup group;
  final bool timed;
}

/// 诊断配置（来自 assets/data/config.json，缺失时用默认值）。
class DiagnosisConfig {
  const DiagnosisConfig({
    required this.total,
    required this.k,
    required this.t,
    required this.s,
    required this.p,
    required this.weakThreshold,
    required this.choiceLimitSeconds,
    required this.fillLimitSeconds,
    required this.essayLimitSeconds,
  });

  final int total;
  final int k;
  final int t;
  final int s;
  final int p;
  final double weakThreshold;
  final int choiceLimitSeconds;
  final int fillLimitSeconds;
  final int essayLimitSeconds;

  factory DiagnosisConfig.defaults() {
    return const DiagnosisConfig(
      total: 15,
      k: 6,
      t: 5,
      s: 2,
      p: 2,
      weakThreshold: 0.6,
      choiceLimitSeconds: 120,
      fillLimitSeconds: 180,
      essayLimitSeconds: 600,
    );
  }

  factory DiagnosisConfig.fromJson(Map<String, dynamic> json) {
    final diagnosis = (json['diagnosis'] as Map<String, dynamic>?) ?? const {};
    final timing = (json['timing'] as Map<String, dynamic>?) ?? const {};
    return DiagnosisConfig(
      total: diagnosis['total'] as int? ?? 15,
      k: diagnosis['k'] as int? ?? 6,
      t: diagnosis['t'] as int? ?? 5,
      s: diagnosis['s'] as int? ?? 2,
      p: diagnosis['p'] as int? ?? 2,
      weakThreshold: (diagnosis['weak_threshold'] as num?)?.toDouble() ?? 0.6,
      choiceLimitSeconds: timing['choice'] as int? ?? 120,
      fillLimitSeconds: timing['fill'] as int? ?? 180,
      essayLimitSeconds: timing['essay'] as int? ?? 600,
    );
  }
}

/// 一道题的作答输入。
class DiagnosisAnswer {
  const DiagnosisAnswer({
    required this.question,
    required this.group,
    required this.timed,
    this.selectedOption,
    this.fillText,
    this.selfOption,
    this.timedOut = false,
    this.seconds = 0,
  });

  final Question question;
  final DiagnosisGroup group;
  final bool timed;

  /// 选择题作答：A–D。
  final String? selectedOption;

  /// 填空题作答文本。
  final String? fillText;

  /// 自评题选项序号（0/1/2）。
  final int? selfOption;

  /// 限时题是否超时（超时计错）。
  final bool timedOut;

  /// 本题用时（秒）。
  final int seconds;
}

/// 薄弱知识点。
class WeakPoint {
  const WeakPoint({
    required this.code,
    required this.name,
    required this.correct,
    required this.total,
    required this.accuracy,
  });

  final String code;
  final String name;
  final int correct;
  final int total;
  final double accuracy;

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'name': name,
      'correct': correct,
      'total': total,
      'accuracy': accuracy,
    };
  }

  factory WeakPoint.fromJson(Map<String, dynamic> json) {
    return WeakPoint(
      code: json['code'] as String,
      name: json['name'] as String,
      correct: json['correct'] as int,
      total: json['total'] as int,
      accuracy: (json['accuracy'] as num).toDouble(),
    );
  }
}

/// 归因条目。
class AttributionItem {
  const AttributionItem({
    required this.loseType,
    required this.label,
    required this.count,
  });

  final LoseType loseType;
  final String label;
  final int count;

  Map<String, dynamic> toJson() {
    return {'lose_type': loseType.code, 'label': label, 'count': count};
  }

  factory AttributionItem.fromJson(Map<String, dynamic> json) {
    return AttributionItem(
      loseType: LoseType.fromCode(json['lose_type'] as String),
      label: json['label'] as String,
      count: json['count'] as int,
    );
  }
}

/// 一次诊断的结果。
class DiagnosisResult {
  const DiagnosisResult({
    this.diagnosisId,
    required this.date,
    required this.kScore,
    required this.tScore,
    required this.sScore,
    required this.pScore,
    required this.weakPoints,
    required this.attribution,
    required this.totalCorrect,
    required this.totalQuestions,
    this.gradeFallback = false,
  });

  final int? diagnosisId;
  final DateTime date;
  final double kScore;
  final double tScore;
  final double sScore;
  final double pScore;
  final List<WeakPoint> weakPoints;
  final List<AttributionItem> attribution;
  final int totalCorrect;
  final int totalQuestions;
  final bool gradeFallback;

  /// 综合得分：四因子平均。
  double get overall => (kScore + tScore + sScore + pScore) / 4;

  DiagnosisResult copyWith({int? diagnosisId}) {
    return DiagnosisResult(
      diagnosisId: diagnosisId ?? this.diagnosisId,
      date: date,
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
}
