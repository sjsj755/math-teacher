import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';

import '../domain/diagnostic_engine.dart';
import '../domain/models/diagnosis.dart';
import '../domain/models/question.dart';
import '../infrastructure/question_repository_impl.dart';
import 'diagnosis_assembler.dart';

/// 诊断用例编排：装配会话、保存作答与诊断结果、读取最近一次诊断。
class DiagnosisService {
  DiagnosisService({
    required this.db,
    Future<String> Function(String path)? assetLoader,
  }) : assetLoader = assetLoader ?? _rootBundleLoader;

  final Database db;
  final Future<String> Function(String path) assetLoader;

  static Future<String> _rootBundleLoader(String path) {
    return rootBundle.loadString(path);
  }

  Future<DiagnosisSession> startSession(String grade) async {
    final configJson =
        jsonDecode(await assetLoader('assets/data/config.json'))
            as Map<String, dynamic>;
    final chapters =
        jsonDecode(await assetLoader('assets/data/chapters.json'))
            as Map<String, dynamic>;
    final questions = await SqliteQuestionRepository(db).all();
    return DiagnosisAssembler().assemble(
      grade: grade,
      all: questions,
      chapters: chapters,
      config: DiagnosisConfig.fromJson(configJson),
    );
  }

  Future<DiagnosisResult> submitDiagnosis(
    List<DiagnosisAnswer> answers, {
    DateTime? date,
    bool gradeFallback = false,
  }) async {
    final config = await _loadConfig();
    final result = DiagnosticEngine.evaluate(
      answers: answers,
      config: config,
      date: date,
      gradeFallback: gradeFallback,
    );
    final dateStr = _dateString(result.date);
    var diagnosisId = 0;

    await db.transaction((txn) async {
      diagnosisId = await txn.insert('diagnosis', {
        'date': dateStr,
        'k_score': result.kScore,
        't_score': result.tScore,
        's_score': result.sScore,
        'p_score': result.pScore,
        'weak_points': jsonEncode(
          result.weakPoints.map((w) => w.toJson()).toList(),
        ),
        'attribution': jsonEncode(
          result.attribution.map((a) => a.toJson()).toList(),
        ),
      });
      for (final a in answers) {
        final isSelf =
            a.question.type == QuestionType.selfS ||
            a.question.type == QuestionType.selfP;
        await txn.insert('answer_record', {
          'question_id': a.question.id,
          'result': isSelf
              ? (DiagnosticEngine.selfScore(a.selfOption) >= 0.5 ? 1 : 0)
              : (DiagnosticEngine.isCorrect(a) ? 1 : 0),
          'seconds': a.seconds,
          'date': dateStr,
          'diagnosis_id': diagnosisId,
          'self_option': a.selfOption,
        });
      }
    });

    return result.copyWith(diagnosisId: diagnosisId);
  }

  /// 读取最近一次诊断结果（报告页独立进入时使用）。
  Future<DiagnosisResult?> latestResult() async {
    final rows = await db.query('diagnosis', orderBy: 'id DESC', limit: 1);
    if (rows.isEmpty) {
      return null;
    }
    final row = rows.first;
    final id = row['id'] as int;
    final records = await db.rawQuery(
      '''
      SELECT ar.result AS result, q.type AS type
      FROM answer_record ar
      JOIN question q ON q.id = ar.question_id
      WHERE ar.diagnosis_id = ?
      ''',
      [id],
    );
    final content = records
        .where((r) => r['type'] != 'self_s' && r['type'] != 'self_p')
        .toList();
    return DiagnosisResult(
      diagnosisId: id,
      date: DateTime.parse(row['date'] as String),
      kScore: (row['k_score'] as num).toDouble(),
      tScore: (row['t_score'] as num).toDouble(),
      sScore: (row['s_score'] as num).toDouble(),
      pScore: (row['p_score'] as num).toDouble(),
      weakPoints: _decodeList(
        row['weak_points'] as String?,
        WeakPoint.fromJson,
      ),
      attribution: _decodeList(
        row['attribution'] as String?,
        AttributionItem.fromJson,
      ),
      totalCorrect: content.where((r) => (r['result'] as int) == 1).length,
      totalQuestions: content.length,
    );
  }

  Future<DiagnosisConfig> _loadConfig() async {
    final json =
        jsonDecode(await assetLoader('assets/data/config.json'))
            as Map<String, dynamic>;
    return DiagnosisConfig.fromJson(json);
  }

  static List<T> _decodeList<T>(
    String? raw,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    if (raw == null || raw.isEmpty) {
      return const [];
    }
    return (jsonDecode(raw) as List<dynamic>)
        .map((e) => fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static String _dateString(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }
}
