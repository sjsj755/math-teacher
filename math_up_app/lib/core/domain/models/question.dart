import 'dart:convert';

/// 题目类型：选择题 / 填空题 / 解答题 / 步骤规范自评 / 临场心态自评。
enum QuestionType {
  choice('choice'),
  fill('fill'),
  essay('essay'),
  selfS('self_s'),
  selfP('self_p');

  const QuestionType(this.code);

  final String code;

  static QuestionType fromCode(String code) {
    return QuestionType.values.firstWhere(
      (type) => type.code == code,
      orElse: () => throw FormatException('未知题目类型：$code'),
    );
  }
}

/// 失分归因：知识 / 方法 / 运算 / 规范 / 心理。
enum LoseType {
  knowledge('knowledge'),
  method('method'),
  calculation('calculation'),
  standard('standard'),
  psychology('psychology');

  const LoseType(this.code);

  final String code;

  static LoseType fromCode(String code) {
    return LoseType.values.firstWhere(
      (type) => type.code == code,
      orElse: () => throw FormatException('未知失分类型：$code'),
    );
  }
}

/// 题库题目实体（对应开发文档 4.2 与 question 表）。
class Question {
  const Question({
    required this.id,
    required this.chapter,
    required this.knowledgePoint,
    required this.type,
    required this.difficulty,
    required this.loseType,
    required this.stem,
    required this.answer,
    required this.variantGroup,
    this.thinkingMethod,
    this.options = const [],
    this.explain,
    this.tags = const [],
  });

  final String id;
  final String chapter;
  final String knowledgePoint;
  final QuestionType type;
  final int difficulty;
  final LoseType loseType;
  final String stem;
  final String answer;
  final String variantGroup;
  final String? thinkingMethod;
  final List<String> options;
  final String? explain;
  final List<String> tags;

  factory Question.fromJson(Map<String, dynamic> json) {
    return Question(
      id: json['id'] as String,
      chapter: json['chapter'] as String,
      knowledgePoint: json['knowledge_point'] as String,
      type: QuestionType.fromCode(json['type'] as String),
      difficulty: json['difficulty'] as int,
      loseType: LoseType.fromCode(json['lose_type'] as String),
      stem: json['stem'] as String,
      answer: (json['answer'] as String?) ?? '',
      variantGroup: json['variant_group'] as String,
      thinkingMethod: json['thinking_method'] as String?,
      options: (json['options'] as List<dynamic>? ?? const [])
          .map((item) => item as String)
          .toList(),
      explain: json['explain'] as String?,
      tags: (json['tags'] as List<dynamic>? ?? const [])
          .map((item) => item as String)
          .toList(),
    );
  }

  factory Question.fromMap(Map<String, Object?> map) {
    return Question(
      id: map['id'] as String,
      chapter: map['chapter'] as String,
      knowledgePoint: map['knowledge_point'] as String,
      type: QuestionType.fromCode(map['type'] as String),
      difficulty: map['difficulty'] as int,
      loseType: LoseType.fromCode(map['lose_type'] as String),
      stem: map['stem'] as String,
      answer: map['answer'] as String,
      variantGroup: map['variant_group'] as String,
      thinkingMethod: map['thinking_method'] as String?,
      options: _decodeStringList(map['options'] as String?),
      explain: map['explain'] as String?,
      tags: _decodeStringList(map['tags'] as String?),
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'chapter': chapter,
      'knowledge_point': knowledgePoint,
      'type': type.code,
      'difficulty': difficulty,
      'thinking_method': thinkingMethod,
      'lose_type': loseType.code,
      'stem': stem,
      'options': jsonEncode(options),
      'answer': answer,
      'explain': explain,
      'variant_group': variantGroup,
      'tags': jsonEncode(tags),
    };
  }

  static List<String> _decodeStringList(String? raw) {
    if (raw == null || raw.isEmpty) {
      return const [];
    }
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded.map((item) => item as String).toList();
  }
}
