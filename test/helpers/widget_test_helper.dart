import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'package:quiz_daily/data/progress_repository.dart';
import 'package:quiz_daily/data/question_repository.dart';
import 'package:quiz_daily/models/daily_stats.dart';
import 'package:quiz_daily/models/question.dart';
import 'package:quiz_daily/models/user_progress.dart';

/// Repositorios sobre cajas de Hive en memoria. En los tests de widgets el
/// tiempo es simulado y una escritura real a disco no terminaría nunca.
class TestRepositories {
  final QuestionRepository questions;
  final ProgressRepository progress;
  TestRepositories(this.questions, this.progress);

  /// Envuelve [screen] en un MaterialApp con los repositorios disponibles.
  Widget wrap(Widget screen) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: questions),
        ChangeNotifierProvider.value(value: progress),
      ],
      child: MaterialApp(home: screen),
    );
  }
}

var _boxCounter = 0;

Future<TestRepositories> createTestRepositories(
  WidgetTester tester, {
  required UserProgress progress,
  List<Question> questions = const [],
  DateTime Function()? now,
}) async {
  if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(QuestionAdapter());
  if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(UserProgressAdapter());
  if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(DailyStatsAdapter());

  // Abrir y cargar las cajas fuera del tiempo simulado.
  final suffix = _boxCounter++;
  final boxes = await tester.runAsync(() async {
    final q = await Hive.openBox<Question>('questions_$suffix', bytes: Uint8List(0));
    final p = await Hive.openBox<UserProgress>('progress_$suffix', bytes: Uint8List(0));
    final s = await Hive.openBox<DailyStats>('stats_$suffix', bytes: Uint8List(0));
    await q.addAll(questions);
    await p.add(progress);
    return (q, p, s);
  });

  final (questionBox, progressBox, statsBox) = boxes!;
  return TestRepositories(
    QuestionRepository(questionBox),
    ProgressRepository(progressBox, statsBox, now: now),
  );
}

Question testQuestion(String id, {String category = 'Historia', int correct = 0}) => Question(
      id: id,
      questionText: 'Pregunta $id',
      options: ['Opción A $id', 'Opción B $id', 'Opción C $id', 'Opción D $id'],
      correctAnswerIndex: correct,
      category: category,
      createdAt: DateTime(2026, 1, 1),
    );
