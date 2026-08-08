import 'question.dart';

/// 练习模式：推荐练习 / 错题重做 / 周清复测。
enum PracticeMode { recommend, redo, weekly }

/// 错题状态（对应 error_book.status）。
enum ErrorBookStatus {
  pending('pending'),
  redone('redone'),
  mastered('mastered'),
  pendingUpgrade('pending_upgrade');

  const ErrorBookStatus(this.code);

  final String code;

  static ErrorBookStatus fromCode(String code) {
    return ErrorBookStatus.values.firstWhere(
      (status) => status.code == code,
      orElse: () => throw FormatException('未知错题状态：$code'),
    );
  }
}

/// 练习配置（config.json practice＋timing）。
class PracticeConfig {
  const PracticeConfig({
    required this.size,
    required this.easyRatio,
    required this.mediumRatio,
    required this.hardRatio,
    required this.choiceLimitSeconds,
    required this.fillLimitSeconds,
  });

  final int size;
  final double easyRatio;
  final double mediumRatio;
  final double hardRatio;
  final int choiceLimitSeconds;
  final int fillLimitSeconds;

  int get easyCount => (size * easyRatio).round();
  int get mediumCount => (size * mediumRatio).round();
  int get hardCount => size - easyCount - mediumCount;

  factory PracticeConfig.defaults() {
    return const PracticeConfig(
      size: 10,
      easyRatio: 0.6,
      mediumRatio: 0.3,
      hardRatio: 0.1,
      choiceLimitSeconds: 120,
      fillLimitSeconds: 180,
    );
  }

  factory PracticeConfig.fromJson(Map<String, dynamic> json) {
    final practice = (json['practice'] as Map<String, dynamic>?) ?? const {};
    final timing = (json['timing'] as Map<String, dynamic>?) ?? const {};
    return PracticeConfig(
      size: practice['size'] as int? ?? 10,
      easyRatio: (practice['easy'] as num?)?.toDouble() ?? 0.6,
      mediumRatio: (practice['medium'] as num?)?.toDouble() ?? 0.3,
      hardRatio: (practice['hard'] as num?)?.toDouble() ?? 0.1,
      choiceLimitSeconds: timing['choice'] as int? ?? 120,
      fillLimitSeconds: timing['fill'] as int? ?? 180,
    );
  }
}

/// 练习会话中的一道题。
class PracticeQuestion {
  const PracticeQuestion({
    required this.question,
    this.errorBookId,
    this.similar = false,
  });

  final Question question;

  /// 重做/复测模式下对应的错题条目 id。
  final int? errorBookId;

  /// 升级类重做是否使用了同类题。
  final bool similar;
}

/// 一次练习会话。
class PracticeSession {
  const PracticeSession({
    required this.mode,
    required this.questions,
    required this.config,
  });

  final PracticeMode mode;
  final List<PracticeQuestion> questions;
  final PracticeConfig config;
}

/// 一道练习题的作答输入。
class PracticeAnswer {
  const PracticeAnswer({
    required this.question,
    this.selectedOption,
    this.fillText,
    this.timedOut = false,
    this.seconds = 0,
  });

  final Question question;
  final String? selectedOption;
  final String? fillText;
  final bool timedOut;
  final int seconds;
}

/// 练习题提交后的即时反馈。
class PracticeFeedback {
  const PracticeFeedback({
    required this.correct,
    required this.answerText,
    required this.explain,
    this.addedToErrorBook = false,
    this.newErrorStatus,
    this.statusMessage,
  });

  final bool correct;
  final String answerText;
  final String explain;
  final bool addedToErrorBook;
  final ErrorBookStatus? newErrorStatus;
  final String? statusMessage;
}

/// 错题条目（error_book 行）。
class ErrorBookEntry {
  const ErrorBookEntry({
    required this.id,
    required this.questionId,
    required this.status,
    required this.redoCount,
    this.loseType,
    this.firstWrongAt,
    this.lastRedoAt,
    this.reviewAt,
    this.createdAt,
  });

  final int id;
  final String questionId;
  final ErrorBookStatus status;
  final int redoCount;
  final LoseType? loseType;
  final DateTime? firstWrongAt;
  final DateTime? lastRedoAt;
  final DateTime? reviewAt;
  final DateTime? createdAt;

  factory ErrorBookEntry.fromMap(Map<String, Object?> map) {
    return ErrorBookEntry(
      id: map['id'] as int,
      questionId: map['question_id'] as String,
      status: ErrorBookStatus.fromCode(map['status'] as String),
      redoCount: map['redo_count'] as int,
      loseType: map['lose_type'] == null
          ? null
          : LoseType.fromCode(map['lose_type'] as String),
      firstWrongAt: _parseTime(map['first_wrong_at'] as String?),
      lastRedoAt: _parseTime(map['last_redo_at'] as String?),
      reviewAt: _parseDate(map['review_at'] as String?),
      createdAt: _parseTime(map['created_at'] as String?),
    );
  }

  static DateTime? _parseTime(String? raw) {
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return DateTime.tryParse(raw.replaceFirst(' ', 'T'));
  }

  static DateTime? _parseDate(String? raw) {
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return DateTime.tryParse(raw);
  }
}
