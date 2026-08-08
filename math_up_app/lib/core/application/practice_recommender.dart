import 'dart:math';

import '../domain/models/diagnosis.dart';
import '../domain/models/practice.dart';
import '../domain/models/question.dart';

enum _Tier { easy, medium, hard }

/// 推荐结果。
class RecommendationResult {
  const RecommendationResult({
    required this.questions,
    required this.fallbackUsed,
  });

  final List<Question> questions;
  final bool fallbackUsed;
}

/// 练习推荐器：薄弱知识点前 3＋难度配比 6/3/1（对应文档 6.3）。
class PracticeRecommender {
  PracticeRecommender({Random? random}) : _random = random ?? Random();

  final Random _random;

  RecommendationResult recommend({
    required List<WeakPoint> weakPoints,
    required List<Question> all,
    required PracticeConfig config,
    required Set<String> excludeIds,
    required Set<String> gradeChapterIds,
  }) {
    final content = all
        .where(
          (q) => q.type == QuestionType.choice || q.type == QuestionType.fill,
        )
        .toList();

    // 目标知识点：薄弱点前 3（已按正确率升序），不足时按年级章节补齐，再不足全库补。
    final pointOrder = <String>[
      for (final point in weakPoints.take(3)) point.code,
    ];
    final gradePoints = _pointsOf(content, gradeChapterIds);
    final allPoints = _pointsOf(content, null);
    for (final pool in [gradePoints, allPoints]) {
      final candidates =
          pool.where((code) => !pointOrder.contains(code)).toList()
            ..shuffle(_random);
      for (final code in candidates) {
        if (pointOrder.length >= 3) {
          break;
        }
        pointOrder.add(code);
      }
      if (pointOrder.length >= 3) {
        break;
      }
    }

    // 每个知识点按难度分层建池。
    final pools = <String, Map<_Tier, List<Question>>>{};
    for (final code in pointOrder) {
      final byTier = <_Tier, List<Question>>{
        _Tier.easy: [],
        _Tier.medium: [],
        _Tier.hard: [],
      };
      for (final q in content) {
        if (q.variantGroup == code) {
          byTier[_tierOf(q.difficulty)]!.add(q);
        }
      }
      pools[code] = byTier;
    }

    final chosen = <String>{};
    var fallbackUsed = false;

    List<Question> takeFrom(List<Question> pool, int need) {
      final available =
          pool
              .where(
                (q) => !chosen.contains(q.id) && !excludeIds.contains(q.id),
              )
              .toList()
            ..shuffle(_random);
      final took = available.take(need).toList();
      chosen.addAll(took.map((q) => q.id));
      return took;
    }

    List<Question> fillTier(_Tier tier, int need) {
      final result = <Question>[];
      // 轮转知识点主池。
      var round = 0;
      while (result.length < need && round < pointOrder.length * 2) {
        for (final code in pointOrder) {
          if (result.length >= need) {
            break;
          }
          result.addAll(takeFrom(pools[code]![tier]!, 1));
        }
        round++;
      }
      if (result.length < need) {
        fallbackUsed = true;
        // 回退 1：全库同层。
        final allTier = content
            .where(
              (q) =>
                  _tierOf(q.difficulty) == tier &&
                  !chosen.contains(q.id) &&
                  !excludeIds.contains(q.id),
            )
            .toList();
        result.addAll(takeFrom(allTier, need - result.length));
      }
      if (result.length < need) {
        fallbackUsed = true;
        // 回退 2：全库任意内容题（可含错题本题）。
        final rest = content.where((q) => !chosen.contains(q.id)).toList();
        result.addAll(takeFrom(rest, need - result.length));
      }
      return result;
    }

    final questions = <Question>[
      ...fillTier(_Tier.easy, config.easyCount),
      ...fillTier(_Tier.medium, config.mediumCount),
      ...fillTier(_Tier.hard, config.hardCount),
    ];
    return RecommendationResult(
      questions: questions,
      fallbackUsed: fallbackUsed,
    );
  }

  Set<String> _pointsOf(List<Question> content, Set<String>? chapterIds) {
    return content
        .where((q) => chapterIds == null || chapterIds.contains(q.chapter))
        .map((q) => q.variantGroup)
        .toSet();
  }

  static _Tier _tierOf(int difficulty) {
    if (difficulty <= 2) {
      return _Tier.easy;
    }
    if (difficulty == 3) {
      return _Tier.medium;
    }
    return _Tier.hard;
  }
}
