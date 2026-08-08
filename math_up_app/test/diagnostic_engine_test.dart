import 'package:flutter_test/flutter_test.dart';

import 'package:math_up_app/core/domain/diagnostic_engine.dart';
import 'package:math_up_app/core/domain/models/diagnosis.dart';
import 'package:math_up_app/core/domain/models/question.dart';

Question _question({
  required String id,
  String chapter = 'A1-3',
  String knowledgePoint = '函数单调性',
  QuestionType type = QuestionType.choice,
  int difficulty = 2,
  LoseType loseType = LoseType.knowledge,
  String answer = 'B',
  String variantGroup = 'A1-3-2',
  bool isTimed = false,
  String? thinkingMethod,
}) {
  return Question(
    id: id,
    chapter: chapter,
    knowledgePoint: knowledgePoint,
    type: type,
    difficulty: difficulty,
    loseType: loseType,
    stem: '题干 $id',
    answer: answer,
    variantGroup: variantGroup,
    isTimed: isTimed,
    thinkingMethod: thinkingMethod,
    options: type == QuestionType.choice
        ? const ['A1', 'A2', 'A3', 'A4']
        : const [],
  );
}

DiagnosisAnswer _answer(
  Question q, {
  DiagnosisGroup group = DiagnosisGroup.k,
  bool timed = false,
  String? selectedOption,
  String? fillText,
  int? selfOption,
  bool timedOut = false,
}) {
  return DiagnosisAnswer(
    question: q,
    group: group,
    timed: timed,
    selectedOption: selectedOption,
    fillText: fillText,
    selfOption: selfOption,
    timedOut: timedOut,
  );
}

final _config = DiagnosisConfig.defaults();

void main() {
  test('全对：四因子均为 1，无薄弱点，无归因', () {
    final answers = <DiagnosisAnswer>[
      for (var i = 0; i < 6; i++)
        _answer(
          _question(id: 'k$i', answer: 'B'),
          selectedOption: 'B',
        ),
      for (var i = 0; i < 5; i++)
        _answer(
          _question(
            id: 't$i',
            difficulty: 3,
            loseType: LoseType.method,
            thinkingMethod: '数形结合',
            variantGroup: 'A1-3-3',
          ),
          group: DiagnosisGroup.t,
          selectedOption: 'B',
        ),
      _answer(
        _question(id: 's1', type: QuestionType.selfS),
        group: DiagnosisGroup.s,
        selfOption: 0,
      ),
      _answer(
        _question(id: 's2', type: QuestionType.selfS),
        group: DiagnosisGroup.s,
        selfOption: 0,
      ),
      _answer(
        _question(id: 'p1', answer: 'B', isTimed: true),
        group: DiagnosisGroup.p,
        timed: true,
        selectedOption: 'B',
      ),
      _answer(
        _question(id: 'p2', type: QuestionType.selfP),
        group: DiagnosisGroup.p,
        selfOption: 0,
      ),
    ];

    final result = DiagnosticEngine.evaluate(answers: answers, config: _config);
    expect(result.kScore, 1);
    expect(result.tScore, 1);
    expect(result.sScore, 1);
    expect(result.pScore, 1);
    expect(result.overall, 1);
    expect(result.weakPoints, isEmpty);
    expect(result.attribution, isEmpty);
    expect(result.totalCorrect, 12);
    expect(result.totalQuestions, 12);
  });

  test('全错：四因子为 0，薄弱点与归因正确', () {
    final answers = <DiagnosisAnswer>[
      for (var i = 0; i < 6; i++)
        _answer(
          _question(id: 'k$i', answer: 'B'),
          selectedOption: 'A',
        ),
      for (var i = 0; i < 5; i++)
        _answer(
          _question(
            id: 't$i',
            difficulty: 3,
            loseType: LoseType.method,
            thinkingMethod: '数形结合',
            variantGroup: 'A1-3-3',
          ),
          group: DiagnosisGroup.t,
          selectedOption: 'A',
        ),
      _answer(
        _question(id: 's1', type: QuestionType.selfS),
        group: DiagnosisGroup.s,
        selfOption: 2,
      ),
      _answer(
        _question(id: 's2', type: QuestionType.selfS),
        group: DiagnosisGroup.s,
        selfOption: 2,
      ),
      _answer(
        _question(id: 'p1', answer: 'B', isTimed: true),
        group: DiagnosisGroup.p,
        timed: true,
        selectedOption: 'B',
        timedOut: true,
      ),
      _answer(
        _question(id: 'p2', type: QuestionType.selfP),
        group: DiagnosisGroup.p,
        selfOption: 2,
      ),
    ];

    final result = DiagnosticEngine.evaluate(answers: answers, config: _config);
    expect(result.kScore, 0);
    expect(result.tScore, 0);
    expect(result.sScore, 0);
    expect(result.pScore, 0);
    expect(result.totalCorrect, 0);
    expect(result.weakPoints, hasLength(2));
    expect(result.weakPoints.first.accuracy, 0);
    expect(result.attribution.first.loseType, LoseType.knowledge);
    expect(result.attribution[1].loseType, LoseType.method);
  });

  test('薄弱点边界：2 题 1 对为薄弱、2 题全对不为薄弱、1 题不参与', () {
    final answers = <DiagnosisAnswer>[
      _answer(
        _question(id: 'k1', variantGroup: 'A1-1-1', answer: 'B'),
        selectedOption: 'B',
      ),
      _answer(
        _question(id: 'k2', variantGroup: 'A1-1-1', answer: 'B'),
        selectedOption: 'A',
      ),
      _answer(
        _question(id: 'k3', variantGroup: 'A1-1-2', answer: 'B'),
        selectedOption: 'B',
      ),
      _answer(
        _question(id: 'k4', variantGroup: 'A1-1-2', answer: 'B'),
        selectedOption: 'B',
      ),
      _answer(
        _question(id: 'k5', variantGroup: 'A1-1-3', answer: 'B'),
        selectedOption: 'A',
      ),
      _answer(
        _question(id: 'k6', variantGroup: 'A1-1-4', answer: 'B'),
        selectedOption: 'B',
      ),
      for (var i = 0; i < 5; i++)
        _answer(
          _question(
            id: 't$i',
            difficulty: 3,
            thinkingMethod: '数形结合',
            variantGroup: 'A1-3-2',
          ),
          group: DiagnosisGroup.t,
          selectedOption: 'B',
        ),
      _answer(
        _question(id: 's1', type: QuestionType.selfS),
        group: DiagnosisGroup.s,
        selfOption: 0,
      ),
      _answer(
        _question(id: 's2', type: QuestionType.selfS),
        group: DiagnosisGroup.s,
        selfOption: 0,
      ),
      _answer(
        _question(id: 'p1', answer: 'B', isTimed: true),
        group: DiagnosisGroup.p,
        timed: true,
        selectedOption: 'B',
      ),
      _answer(
        _question(id: 'p2', type: QuestionType.selfP),
        group: DiagnosisGroup.p,
        selfOption: 0,
      ),
    ];

    final result = DiagnosticEngine.evaluate(answers: answers, config: _config);
    expect(result.weakPoints, hasLength(1));
    expect(result.weakPoints.single.code, 'A1-1-1');
    expect(result.weakPoints.single.accuracy, closeTo(0.5, 1e-9));
  });

  test('自评得分映射与混合因子', () {
    final answers = [
      _answer(
        _question(id: 's1', type: QuestionType.selfS),
        group: DiagnosisGroup.s,
        selfOption: 0,
      ),
      _answer(
        _question(id: 's2', type: QuestionType.selfS),
        group: DiagnosisGroup.s,
        selfOption: 1,
      ),
      _answer(
        _question(id: 'p1', answer: 'B', isTimed: true),
        group: DiagnosisGroup.p,
        timed: true,
        selectedOption: 'B',
      ),
      _answer(
        _question(id: 'p2', type: QuestionType.selfP),
        group: DiagnosisGroup.p,
        selfOption: 2,
      ),
    ];
    final result = DiagnosticEngine.evaluate(answers: answers, config: _config);
    expect(result.sScore, closeTo(0.75, 1e-9));
    expect(result.pScore, closeTo(0.5, 1e-9));
  });

  test('限时题超时计错', () {
    final answers = [
      _answer(
        _question(id: 'p1', answer: 'B', isTimed: true),
        group: DiagnosisGroup.p,
        timed: true,
        selectedOption: 'B',
        timedOut: true,
      ),
      _answer(
        _question(id: 'p2', type: QuestionType.selfP),
        group: DiagnosisGroup.p,
        selfOption: 0,
      ),
    ];
    final result = DiagnosticEngine.evaluate(answers: answers, config: _config);
    expect(result.pScore, closeTo(0.5, 1e-9));
    expect(result.totalCorrect, 0);
  });

  test('填空判分：精确/小数等价/空白容差/错误', () {
    Question fill(String answer) =>
        _question(id: 'f', type: QuestionType.fill, answer: answer);
    bool judge(String answer, String input) {
      return DiagnosticEngine.isCorrect(_answer(fill(answer), fillText: input));
    }

    expect(judge('5/2', '5/2'), isTrue);
    expect(judge('5/2', '2.5'), isTrue);
    expect(judge('5/2', ' 5 / 2 '), isTrue);
    expect(judge('5/2', '3'), isFalse);
    expect(judge('4', '4.0'), isTrue);
    expect(judge('4', '3.9'), isFalse);
    expect(judge('4', ''), isFalse);
  });

  test('归因：计数排序与 S 因子低时补入规范项', () {
    final answers = [
      for (var i = 0; i < 2; i++)
        _answer(
          _question(
            id: 't$i',
            difficulty: 3,
            loseType: LoseType.method,
            thinkingMethod: '转化与化归',
            variantGroup: 'A1-3-2',
          ),
          group: DiagnosisGroup.t,
          selectedOption: 'A',
        ),
      _answer(
        _question(
          id: 'k1',
          loseType: LoseType.knowledge,
          variantGroup: 'A1-1-1',
        ),
        selectedOption: 'A',
      ),
      _answer(
        _question(id: 's1', type: QuestionType.selfS),
        group: DiagnosisGroup.s,
        selfOption: 1,
      ),
      _answer(
        _question(id: 's2', type: QuestionType.selfS),
        group: DiagnosisGroup.s,
        selfOption: 0,
      ),
      _answer(
        _question(id: 'p1', answer: 'B', isTimed: true),
        group: DiagnosisGroup.p,
        timed: true,
        selectedOption: 'B',
      ),
      _answer(
        _question(id: 'p2', type: QuestionType.selfP),
        group: DiagnosisGroup.p,
        selfOption: 0,
      ),
    ];
    final result = DiagnosticEngine.evaluate(answers: answers, config: _config);
    expect(result.attribution, hasLength(2));
    expect(result.attribution[0].loseType, LoseType.method);
    expect(result.attribution[1].loseType, LoseType.knowledge);
  });
}
