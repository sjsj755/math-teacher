import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:math_up_app/core/application/practice_recommender.dart';
import 'package:math_up_app/core/domain/models/diagnosis.dart';
import 'package:math_up_app/core/domain/models/practice.dart';
import 'package:math_up_app/core/domain/models/question.dart';

Future<List<Question>> _loadQuestions() async {
  final raw =
      (jsonDecode(await File('assets/data/questions.json').readAsString())
              as Map<String, dynamic>)['questions']
          as List<dynamic>;
  return raw.map((e) => Question.fromJson(e as Map<String, dynamic>)).toList();
}

void main() {
  late List<Question> questions;

  setUpAll(() async {
    questions = await _loadQuestions();
  });

  test('推荐：10 题且难度配比 6/3/1，知识点取薄弱点前 3', () {
    final result = PracticeRecommender(random: Random(1)).recommend(
      weakPoints: const [
        WeakPoint(
          code: 'A1-1-1',
          name: '集合概念',
          correct: 1,
          total: 3,
          accuracy: 0.33,
        ),
        WeakPoint(
          code: 'A1-1-2',
          name: '集合关系',
          correct: 2,
          total: 4,
          accuracy: 0.5,
        ),
        WeakPoint(
          code: 'A1-1-3',
          name: '集合运算',
          correct: 3,
          total: 4,
          accuracy: 0.75,
        ),
      ],
      all: questions,
      config: PracticeConfig.defaults(),
      excludeIds: const {},
      gradeChapterIds: const {},
    );

    expect(result.questions, hasLength(10));
    final easy = result.questions.where((q) => q.difficulty <= 2).length;
    final medium = result.questions.where((q) => q.difficulty == 3).length;
    final hard = result.questions.where((q) => q.difficulty >= 4).length;
    expect(easy, 6);
    expect(medium, 3);
    expect(hard, 1);
    final ids = result.questions.map((q) => q.id).toSet();
    expect(ids.length, 10);
  });

  test('推荐：排除错题本已有题，不足时回退不报错', () {
    final exclude = questions
        .where((q) => q.variantGroup == 'A1-1-1' && q.difficulty <= 2)
        .map((q) => q.id)
        .toSet();
    expect(exclude, isNotEmpty);

    final result = PracticeRecommender(random: Random(2)).recommend(
      weakPoints: const [
        WeakPoint(
          code: 'A1-1-1',
          name: '集合概念',
          correct: 0,
          total: 3,
          accuracy: 0,
        ),
      ],
      all: questions,
      config: PracticeConfig.defaults(),
      excludeIds: exclude,
      gradeChapterIds: const {},
    );

    expect(result.questions, hasLength(10));
    expect(result.questions.any((q) => exclude.contains(q.id)), isFalse);
  });

  test('推荐：无薄弱点时按年级章节补齐，仍可完成 10 题', () {
    final result = PracticeRecommender(random: Random(3)).recommend(
      weakPoints: const [],
      all: questions,
      config: PracticeConfig.defaults(),
      excludeIds: const {},
      gradeChapterIds: {'A1-1', 'A1-2', 'A1-3', 'A1-4', 'A1-5'},
    );
    expect(result.questions, hasLength(10));
    expect(result.questions.every((q) => q.chapter.startsWith('A1')), isTrue);
  });
}
