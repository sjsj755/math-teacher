import 'dart:math';

import '../domain/models/diagnosis.dart';
import '../domain/models/question.dart';

/// 一次诊断会话：题目序列＋配置＋是否发生年级降级。
class DiagnosisSession {
  const DiagnosisSession({
    required this.questions,
    required this.config,
    this.gradeFallback = false,
  });

  final List<DiagnosisQuestion> questions;
  final DiagnosisConfig config;
  final bool gradeFallback;
}

/// 诊断 15 题装配器：K（年级基础）＋T（中档带思维方法）＋S（自评）＋P（限时＋心态）。
class DiagnosisAssembler {
  DiagnosisAssembler({Random? random}) : _random = random ?? Random();

  final Random _random;

  DiagnosisSession assemble({
    required String grade,
    required List<Question> all,
    required Map<String, dynamic> chapters,
    required DiagnosisConfig config,
  }) {
    final byId = {for (final q in all) q.id: q};
    bool isContent(Question q) =>
        q.type == QuestionType.choice || q.type == QuestionType.fill;

    final gradeChapterIds = _gradeChapterIds(grade, chapters);

    // K 组：年级章节、难度 1–2、选择/填空；不足时降级补全库基础题。
    var gradeFallback = false;
    var kPool =
        all
            .where(
              (q) =>
                  isContent(q) &&
                  q.difficulty <= 2 &&
                  gradeChapterIds.contains(q.chapter),
            )
            .toList()
          ..shuffle(_random);
    final kPicked = <Question>[];
    if (kPool.length >= config.k) {
      kPicked.addAll(kPool.take(config.k));
    } else {
      gradeFallback = true;
      kPicked.addAll(kPool);
      final fallback =
          all
              .where(
                (q) =>
                    isContent(q) && q.difficulty <= 2 && !kPicked.contains(q),
              )
              .toList()
            ..shuffle(_random);
      kPicked.addAll(fallback.take(config.k - kPicked.length));
    }
    kPicked.shuffle(_random);

    // T 组：难度 3、带思维方法、选择/填空。
    final tPool =
        all
            .where(
              (q) =>
                  isContent(q) && q.difficulty == 3 && q.thinkingMethod != null,
            )
            .toList()
          ..shuffle(_random);
    final tPicked = tPool.take(config.t).toList();
    if (tPicked.length < config.t) {
      gradeFallback = true;
    }

    // S 组：步骤规范自评模板。
    final sPicked = <Question>[
      for (final id in const ['DIAG-S-01', 'DIAG-S-02'])
        if (byId[id] != null) byId[id]!,
    ];

    // P 组：随机 1 道限时选择题＋心态自评。
    final timedPool =
        all.where((q) => q.isTimed && q.type == QuestionType.choice).toList()
          ..shuffle(_random);
    final timed = timedPool.isEmpty ? null : timedPool.first;
    final pSelf = byId['DIAG-P-01'];

    final questions = <DiagnosisQuestion>[
      for (final q in kPicked)
        DiagnosisQuestion(question: q, group: DiagnosisGroup.k),
      for (final q in tPicked)
        DiagnosisQuestion(question: q, group: DiagnosisGroup.t),
      for (final q in sPicked)
        DiagnosisQuestion(question: q, group: DiagnosisGroup.s),
      if (timed != null)
        DiagnosisQuestion(
          question: timed,
          group: DiagnosisGroup.p,
          timed: true,
        ),
      if (pSelf != null)
        DiagnosisQuestion(question: pSelf, group: DiagnosisGroup.p),
    ];

    return DiagnosisSession(
      questions: questions,
      config: config,
      gradeFallback: gradeFallback,
    );
  }

  /// 年级 → 章节编码集合：高三取全部章节，否则取该年级各册的章节。
  Set<String> _gradeChapterIds(String grade, Map<String, dynamic> chapters) {
    final books = (chapters['books'] as List<dynamic>? ?? const []);
    final ids = <String>{};
    for (final book in books.cast<Map<String, dynamic>>()) {
      final grades = (book['grades'] as List<dynamic>? ?? const [])
          .cast<String>();
      if (grade != '高三' && !grades.contains(grade)) {
        continue;
      }
      for (final chapter
          in (book['chapters'] as List<dynamic>? ?? const [])
              .cast<Map<String, dynamic>>()) {
        ids.add(chapter['id'] as String);
      }
    }
    return ids;
  }
}
