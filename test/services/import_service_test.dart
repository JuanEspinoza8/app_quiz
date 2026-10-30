import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:quiz_daily/data/progress_repository.dart';
import 'package:quiz_daily/data/question_repository.dart';
import 'package:quiz_daily/models/daily_stats.dart';
import 'package:quiz_daily/models/question.dart';
import 'package:quiz_daily/models/user_progress.dart';
import 'package:quiz_daily/services/import_service.dart';
import 'package:quiz_daily/services/storage_service.dart';

import '../helpers/hive_test_helper.dart';

void main() {
  late Directory hiveDir;
  late Box<Question> questions;
  late Box<UserProgress> progress;
  late Box<DailyStats> stats;
  late QuestionRepository questionRepo;
  late ProgressRepository progressRepo;

  Future<String> import(File file) =>
      ImportService.importBackup(file, questions: questionRepo, progress: progressRepo);

  Future<File> writeBackup(Object json) async {
    final file = File('${hiveDir.path}/backup.json');
    await file.writeAsString(jsonEncode(json));
    return file;
  }

  setUp(() async {
    hiveDir = await setUpTestHive();
    questions = Hive.box<Question>(HiveBoxes.questions);
    progress = Hive.box<UserProgress>(HiveBoxes.progress);
    stats = Hive.box<DailyStats>(HiveBoxes.stats);
    questionRepo = QuestionRepository(questions);
    progressRepo = ProgressRepository(progress, stats);
    await progress.add(UserProgress(
      dailyGoal: 5,
      answeredToday: 2,
      streak: 1,
      lastPlayedDate: DateTime(2026, 10, 30),
    ));
  });

  tearDown(() async {
    questionRepo.dispose();
    progressRepo.dispose();
    await tearDownTestHive(hiveDir);
  });

  test('formato viejo: una lista de preguntas con las claves del modelo', () async {
    final file = await writeBackup([
      {
        'id': 'q1',
        'questionText': '¿Capital de Francia?',
        'options': ['París', 'Roma', 'Madrid', 'Lisboa'],
        'correctAnswerIndex': 0,
        'category': 'Geografía',
        'createdAt': '2025-03-01T10:00:00.000',
      },
      {
        'id': 'q2',
        'questionText': '2 + 2',
        'options': ['3', '4', '5', '22'],
        'correctAnswerIndex': 1,
        'category': 'Matemática',
      },
    ]);

    final message = await import(file);

    expect(message, contains('2 preguntas'));
    expect(questions.length, 2);
    final q1 = questions.values.firstWhere((q) => q.id == 'q1');
    expect(q1.questionText, '¿Capital de Francia?');
    expect(q1.correctAnswerIndex, 0);
    expect(q1.createdAt, DateTime(2025, 3, 1, 10));
    expect(q1.errorCount, 0);
    expect(q1.totalAttempts, 0);
    expect(q1.correctCount, 0);
    // Sin progreso ni estadísticas en el archivo, no se tocan.
    expect(progress.getAt(0)!.dailyGoal, 5);
    expect(progress.getAt(0)!.streak, 1);
    expect(stats.isEmpty, isTrue);
  });

  test('formato nuevo: respaldo completo con preguntas, progreso y estadísticas', () async {
    await stats.add(DailyStats(date: DateTime(2026, 1, 1), questionsAnswered: 9, correctAnswers: 9));
    final file = await writeBackup({
      'version': 1,
      'questions': [
        {
          'id': 'q1',
          'text': '¿Capital de Italia?',
          'options': ['París', 'Roma', 'Madrid', 'Lisboa'],
          'correct': 1,
          'category': 'Geografía',
          'createdAt': '2025-03-01T10:00:00.000',
          'imagePath': null,
          'explanation': 'Roma es la capital desde 1871.',
          'errorCount': 2,
          'totalAttempts': 5,
          'correctCount': 3,
        },
      ],
      'progress': {
        'dailyGoal': 8,
        'streak': 12,
        'lastPlayed': '2026-10-29T21:00:00.000',
        'notifHour': 20,
        'notifMinute': 30,
      },
      'stats': [
        {'date': '2026-10-28T00:00:00.000', 'answered': 8, 'correct': 6},
        {'date': '2026-10-29T00:00:00.000', 'answered': 10, 'correct': 7},
      ],
    });

    await import(file);

    final q = questions.getAt(0)!;
    expect(q.questionText, '¿Capital de Italia?');
    expect(q.correctAnswerIndex, 1);
    expect(q.explanation, 'Roma es la capital desde 1871.');
    expect(q.errorCount, 2);
    expect(q.totalAttempts, 5);
    expect(q.correctCount, 3);

    final p = progress.getAt(0)!;
    expect(p.dailyGoal, 8);
    expect(p.streak, 12);
    expect(p.lastPlayedDate, DateTime(2026, 10, 29, 21));
    expect(p.notificationHour, 20);
    expect(p.notificationMinute, 30);

    // Las estadísticas se reemplazan, no se suman a las que había.
    expect(stats.length, 2);
    expect(stats.values.map((s) => s.questionsAnswered), [8, 10]);
    expect(stats.values.map((s) => s.correctAnswers), [6, 7]);
  });

  test('no duplica preguntas que ya existen con el mismo id', () async {
    await questions.add(Question(
      id: 'q1',
      questionText: 'Existente',
      options: ['a', 'b', 'c', 'd'],
      correctAnswerIndex: 0,
      category: 'X',
      createdAt: DateTime(2025),
    ));
    final file = await writeBackup({
      'questions': [
        {'id': 'q1', 'text': 'Duplicada', 'options': ['a', 'b', 'c', 'd'], 'correct': 0, 'category': 'X'},
        {'id': 'q2', 'text': 'Nueva', 'options': ['a', 'b', 'c', 'd'], 'correct': 2, 'category': 'X'},
      ],
    });

    final message = await import(file);

    expect(message, contains('1 preguntas'));
    expect(questions.length, 2);
    expect(questions.values.firstWhere((q) => q.id == 'q1').questionText, 'Existente');
  });
}
