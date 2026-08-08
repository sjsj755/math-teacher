import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:math_up_app/core/application/diagnosis_assembler.dart';
import 'package:math_up_app/core/domain/models/diagnosis.dart';
import 'package:math_up_app/core/domain/models/question.dart';

Future<Map<String, dynamic>> _loadJson(String path) async {
  return jsonDecode(await File(path).readAsString()) as Map<String, dynamic>;
}

void main() {
  late List<Question> questions;
  late Map<String, dynamic> chapters;

  setUpAll(() async {
    final raw =
        (await _loadJson('assets/data/questions.json'))['questions']
            as List<dynamic>;
    questions = raw
        .map((e) => Question.fromJson(e as Map<String, dynamic>))
        .toList();
    chapters = await _loadJson('assets/data/chapters.json');
  });

  test('高一：15 题构成 K6/T5/S2/P2，K 来自年级章节基础题', () {
    final session = DiagnosisAssembler(random: Random(1)).assemble(
      grade: '高一',
      all: questions,
      chapters: chapters,
      config: DiagnosisConfig.defaults(),
    );

    expect(session.questions, hasLength(15));
    expect(session.gradeFallback, isFalse);
    expect(
      session.questions.where((q) => q.group == DiagnosisGroup.k),
      hasLength(6),
    );
    expect(
      session.questions.where((q) => q.group == DiagnosisGroup.t),
      hasLength(5),
    );
    expect(
      session.questions.where((q) => q.group == DiagnosisGroup.s),
      hasLength(2),
    );
    expect(
      session.questions.where((q) => q.group == DiagnosisGroup.p),
      hasLength(2),
    );

    for (final item in session.questions.where(
      (q) => q.group == DiagnosisGroup.k,
    )) {
      expect(item.question.chapter, startsWith('A1'));
      expect(item.question.difficulty, lessThanOrEqualTo(2));
      expect(
        item.question.type == QuestionType.choice ||
            item.question.type == QuestionType.fill,
        isTrue,
      );
    }
    for (final item in session.questions.where(
      (q) => q.group == DiagnosisGroup.t,
    )) {
      expect(item.question.difficulty, 3);
      expect(item.question.thinkingMethod, isNotNull);
    }
    expect(
      session.questions
          .where((q) => q.group == DiagnosisGroup.s)
          .map((q) => q.question.id),
      containsAll(['DIAG-S-01', 'DIAG-S-02']),
    );
    final p = session.questions
        .where((q) => q.group == DiagnosisGroup.p)
        .toList();
    expect(p.where((q) => q.timed), hasLength(1));
    expect(p.where((q) => q.timed).single.question.isTimed, isTrue);
    expect(p.where((q) => !q.timed).single.question.id, 'DIAG-P-01');
  });

  test('高二：章节无题时降级补全库基础题，诊断仍可完成', () {
    final session = DiagnosisAssembler(random: Random(2)).assemble(
      grade: '高二',
      all: questions,
      chapters: chapters,
      config: DiagnosisConfig.defaults(),
    );
    expect(session.questions, hasLength(15));
    expect(session.gradeFallback, isTrue);
  });

  test('高三：覆盖全部章节，不触发降级', () {
    final session = DiagnosisAssembler(random: Random(3)).assemble(
      grade: '高三',
      all: questions,
      chapters: chapters,
      config: DiagnosisConfig.defaults(),
    );
    expect(session.questions, hasLength(15));
    expect(session.gradeFallback, isFalse);
  });
}
