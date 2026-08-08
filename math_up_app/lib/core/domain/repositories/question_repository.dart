import '../models/question.dart';

/// 题目仓储接口（内容域扩展点，阶段 3/4 直接调用）。
abstract class QuestionRepository {
  /// 题库题目总数。
  Future<int> count();

  /// 全部题目。
  Future<List<Question>> all();

  /// 按知识点编码取题（支持节编码 A1-3-2，兼容章编码 A1-3）。
  Future<List<Question>> byKnowledge(String code);

  /// 按变式组编码取题。
  Future<List<Question>> byVariantGroup(String code);
}
