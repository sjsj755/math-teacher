/// 每日日报摘要（对应开发文档 5.3.3 的 daily-digest 载荷）。
class DailyDigest {
  const DailyDigest({
    required this.date,
    required this.practiceCount,
    required this.correctCount,
    required this.errorCount,
    required this.minutes,
    required this.weakPoints,
    required this.weakPointNames,
    required this.streakDays,
  });

  final DateTime date;
  final int practiceCount;
  final int correctCount;
  final int errorCount;
  final int minutes;

  /// 薄弱点编码（节编码，如 A1-3-2）。
  final List<String> weakPoints;

  /// 薄弱点名称（用于日报正文，如“函数单调性”）。
  final List<String> weakPointNames;

  final int streakDays;

  Map<String, dynamic> toJson() {
    final dateText =
        '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    return {
      'date': dateText,
      'practice_count': practiceCount,
      'correct_count': correctCount,
      'error_count': errorCount,
      'minutes': minutes,
      'weak_points': weakPoints,
      'weak_point_names': weakPointNames,
      'streak_days': streakDays,
    };
  }

  factory DailyDigest.fromJson(Map<String, dynamic> json) {
    return DailyDigest(
      date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
      practiceCount: json['practice_count'] as int? ?? 0,
      correctCount: json['correct_count'] as int? ?? 0,
      errorCount: json['error_count'] as int? ?? 0,
      minutes: json['minutes'] as int? ?? 0,
      weakPoints:
          (json['weak_points'] as List<dynamic>? ?? const [])
              .cast<String>(),
      weakPointNames:
          (json['weak_point_names'] as List<dynamic>? ?? const [])
              .cast<String>(),
      streakDays: json['streak_days'] as int? ?? 0,
    );
  }
}
