import 'package:sqflite/sqflite.dart';

import '../domain/models/question.dart';
import '../domain/repositories/question_repository.dart';

/// 基于 SQLite 的 [QuestionRepository] 实现。
class SqliteQuestionRepository implements QuestionRepository {
  SqliteQuestionRepository(this._db);

  final Database _db;

  @override
  Future<int> count() async {
    final rows = await _db.rawQuery('SELECT COUNT(*) AS c FROM question');
    return rows.first['c'] as int;
  }

  @override
  Future<List<Question>> all() async {
    final rows = await _db.query('question', orderBy: 'id');
    return rows.map(Question.fromMap).toList();
  }

  @override
  Future<List<Question>> byKnowledge(String code) async {
    final rows = await _db.query(
      'question',
      where: 'chapter = ? OR variant_group = ?',
      whereArgs: [code, code],
      orderBy: 'id',
    );
    return rows.map(Question.fromMap).toList();
  }

  @override
  Future<List<Question>> byVariantGroup(String code) async {
    final rows = await _db.query(
      'question',
      where: 'variant_group = ?',
      whereArgs: [code],
      orderBy: 'id',
    );
    return rows.map(Question.fromMap).toList();
  }
}
