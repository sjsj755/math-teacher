import 'models/practice.dart';

/// 状态迁移结果。
class ErrorBookTransition {
  const ErrorBookTransition({
    required this.status,
    required this.redoCountDelta,
    this.reviewAt,
    this.lastRedoAt,
  });

  final ErrorBookStatus status;
  final int redoCountDelta;
  final DateTime? reviewAt;
  final DateTime? lastRedoAt;
}

/// 错题状态机（对应开发文档表 10）。
abstract final class ErrorBookMachine {
  static const Duration observationPeriod = Duration(days: 7);

  /// 根据当前状态、作答结果与练习模式计算新状态与时间戳。
  static ErrorBookTransition transition({
    required ErrorBookStatus current,
    required bool correct,
    required PracticeMode mode,
    DateTime? now,
  }) {
    final currentTime = now ?? DateTime.now();
    final redoTime = currentTime;

    if (mode == PracticeMode.recommend) {
      // 练习答错：已收录时仅重做次数 +1，状态不变。
      return ErrorBookTransition(
        status: current,
        redoCountDelta: correct ? 0 : 1,
      );
    }

    if (mode == PracticeMode.redo) {
      if (correct) {
        // 重做正确：进入观察期（7 天后复测）。
        return ErrorBookTransition(
          status: ErrorBookStatus.redone,
          redoCountDelta: 0,
          reviewAt: currentTime.add(observationPeriod),
          lastRedoAt: redoTime,
        );
      }
      // 重做再错：升级为待重做（升级）。
      return ErrorBookTransition(
        status: ErrorBookStatus.pendingUpgrade,
        redoCountDelta: 1,
        lastRedoAt: redoTime,
      );
    }

    // 周清复测。
    if (correct) {
      return ErrorBookTransition(
        status: ErrorBookStatus.mastered,
        redoCountDelta: 0,
        lastRedoAt: redoTime,
      );
    }
    return ErrorBookTransition(
      status: ErrorBookStatus.pendingUpgrade,
      redoCountDelta: 1,
      lastRedoAt: redoTime,
    );
  }
}
