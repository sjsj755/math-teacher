import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';

import '../domain/error_book_machine.dart';
import '../domain/models/practice.dart';
import '../domain/models/question.dart';

/// error_book 表仓储。
class ErrorBookRepository {
  ErrorBookRepository(this._db);

  final Database _db;

  static final DateFormat _timeFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
  static final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');

  Future<List<ErrorBookEntry>> listByStatuses(
    List<ErrorBookStatus> statuses, {
    String orderBy = 'id ASC',
  }) async {
    final rows = await _db.query(
      'error_book',
      where: 'status IN (${List.filled(statuses.length, '?').join(',')})',
      whereArgs: statuses.map((s) => s.code).toList(),
      orderBy: orderBy,
    );
    return rows.map(ErrorBookEntry.fromMap).toList();
  }

  Future<List<ErrorBookEntry>> listAll() async {
    final rows = await _db.query('error_book', orderBy: 'id ASC');
    return rows.map(ErrorBookEntry.fromMap).toList();
  }

  Future<ErrorBookEntry?> find(String questionId) async {
    final rows = await _db.query(
      'error_book',
      where: 'question_id = ?',
      whereArgs: [questionId],
      limit: 1,
    );
    return rows.isEmpty ? null : ErrorBookEntry.fromMap(rows.first);
  }

  Future<ErrorBookEntry?> findById(int id) async {
    final rows = await _db.query(
      'error_book',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : ErrorBookEntry.fromMap(rows.first);
  }

  Future<List<String>> allQuestionIds() async {
    final rows = await _db.query('error_book', columns: ['question_id']);
    return rows.map((r) => r['question_id'] as String).toList();
  }

  Future<int> insert({
    required String questionId,
    required LoseType loseType,
    DateTime? now,
  }) async {
    final current = now ?? DateTime.now();
    return _db.insert('error_book', {
      'question_id': questionId,
      'lose_type': loseType.code,
      'status': ErrorBookStatus.pending.code,
      'redo_count': 0,
      'first_wrong_at': _timeFormat.format(current),
    });
  }

  Future<void> applyTransition(int id, ErrorBookTransition transition) async {
    if (transition.redoCountDelta != 0) {
      await _db.rawUpdate(
        'UPDATE error_book SET status = ?, redo_count = redo_count + ?'
        '${transition.lastRedoAt == null ? '' : ', last_redo_at = ?'}'
        '${transition.reviewAt == null ? '' : ', review_at = ?'}'
        ' WHERE id = ?',
        [
          transition.status.code,
          transition.redoCountDelta,
          if (transition.lastRedoAt != null)
            _timeFormat.format(transition.lastRedoAt!),
          if (transition.reviewAt != null)
            _dateFormat.format(transition.reviewAt!),
          id,
        ],
      );
      return;
    }
    await _db.update(
      'error_book',
      {
        'status': transition.status.code,
        if (transition.lastRedoAt != null)
          'last_redo_at': _timeFormat.format(transition.lastRedoAt!),
        if (transition.reviewAt != null)
          'review_at': _dateFormat.format(transition.reviewAt!),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> setReviewDate(int id, DateTime date) async {
    await _db.update(
      'error_book',
      {'review_at': _dateFormat.format(date)},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
