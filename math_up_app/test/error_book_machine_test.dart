import 'package:flutter_test/flutter_test.dart';

import 'package:math_up_app/core/domain/error_book_machine.dart';
import 'package:math_up_app/core/domain/models/practice.dart';

void main() {
  test('练习答错：已收录时重做次数 +1，状态不变', () {
    final transition = ErrorBookMachine.transition(
      current: ErrorBookStatus.pending,
      correct: false,
      mode: PracticeMode.recommend,
    );
    expect(transition.status, ErrorBookStatus.pending);
    expect(transition.redoCountDelta, 1);
    expect(transition.reviewAt, isNull);
  });

  test('练习答对：不改变错题状态', () {
    final transition = ErrorBookMachine.transition(
      current: ErrorBookStatus.pending,
      correct: true,
      mode: PracticeMode.recommend,
    );
    expect(transition.status, ErrorBookStatus.pending);
    expect(transition.redoCountDelta, 0);
  });

  test('重做答对：进入观察期，7 天后复测', () {
    final now = DateTime(2026, 8, 8, 12);
    final transition = ErrorBookMachine.transition(
      current: ErrorBookStatus.pending,
      correct: true,
      mode: PracticeMode.redo,
      now: now,
    );
    expect(transition.status, ErrorBookStatus.redone);
    expect(transition.redoCountDelta, 0);
    expect(transition.reviewAt, DateTime(2026, 8, 15, 12));
    expect(transition.lastRedoAt, now);
  });

  test('升级类重做答对：回到观察期', () {
    final transition = ErrorBookMachine.transition(
      current: ErrorBookStatus.pendingUpgrade,
      correct: true,
      mode: PracticeMode.redo,
    );
    expect(transition.status, ErrorBookStatus.redone);
    expect(transition.redoCountDelta, 0);
  });

  test('重做答错：升级为待重做且次数 +1', () {
    final transition = ErrorBookMachine.transition(
      current: ErrorBookStatus.pending,
      correct: false,
      mode: PracticeMode.redo,
    );
    expect(transition.status, ErrorBookStatus.pendingUpgrade);
    expect(transition.redoCountDelta, 1);
  });

  test('升级类重做再错：保持升级状态，次数继续 +1', () {
    final transition = ErrorBookMachine.transition(
      current: ErrorBookStatus.pendingUpgrade,
      correct: false,
      mode: PracticeMode.redo,
    );
    expect(transition.status, ErrorBookStatus.pendingUpgrade);
    expect(transition.redoCountDelta, 1);
  });

  test('复测答对：已掌握', () {
    final transition = ErrorBookMachine.transition(
      current: ErrorBookStatus.redone,
      correct: true,
      mode: PracticeMode.weekly,
    );
    expect(transition.status, ErrorBookStatus.mastered);
    expect(transition.redoCountDelta, 0);
  });

  test('复测答错：升级为待重做且次数 +1', () {
    final transition = ErrorBookMachine.transition(
      current: ErrorBookStatus.redone,
      correct: false,
      mode: PracticeMode.weekly,
    );
    expect(transition.status, ErrorBookStatus.pendingUpgrade);
    expect(transition.redoCountDelta, 1);
  });
}
