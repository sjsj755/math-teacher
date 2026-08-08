import 'models/question.dart';

/// 共享判分规则：选择题字母比对、填空精确/小数等价、超时计错。
abstract final class AnswerGrading {
  /// 内容题是否作答正确（超时一律计错）。
  static bool isCorrect({
    required Question question,
    String? selectedOption,
    String? fillText,
    bool timedOut = false,
  }) {
    if (timedOut) {
      return false;
    }
    switch (question.type) {
      case QuestionType.choice:
        return selectedOption == question.answer;
      case QuestionType.fill:
        return _fillMatch(fillText, question.answer);
      case QuestionType.essay:
      case QuestionType.selfS:
      case QuestionType.selfP:
        return false;
    }
  }

  /// 自评选项得分：第 0 项 1 分、第 1 项 0.5 分、其余 0 分。
  static double selfScore(int? option) {
    return switch (option) {
      0 => 1,
      1 => 0.5,
      _ => 0,
    };
  }

  /// 填空判分：去空白后精确匹配，或分数/小数等价比较。
  static bool _fillMatch(String? input, String answer) {
    if (input == null) {
      return false;
    }
    final a = input.trim().replaceAll(RegExp(r'\s+'), '');
    final b = answer.trim().replaceAll(RegExp(r'\s+'), '');
    if (a == b) {
      return true;
    }
    final fa = _toNumber(a);
    final fb = _toNumber(b);
    if (fa != null && fb != null) {
      return (fa - fb).abs() < 1e-6;
    }
    return false;
  }

  static double? _toNumber(String s) {
    final direct = double.tryParse(s);
    if (direct != null) {
      return direct;
    }
    if (!s.contains('/')) {
      return null;
    }
    final parts = s.split('/');
    if (parts.length != 2) {
      return null;
    }
    final n = double.tryParse(parts[0]);
    final d = double.tryParse(parts[1]);
    if (n == null || d == null || d == 0) {
      return null;
    }
    return n / d;
  }
}
