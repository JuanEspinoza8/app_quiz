import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:quiz_daily/data/progress_repository.dart';
import 'package:quiz_daily/data/question_repository.dart';
import 'package:quiz_daily/models/daily_stats.dart';
import 'package:quiz_daily/models/question.dart';
import 'package:quiz_daily/models/user_progress.dart';
import 'package:quiz_daily/services/image_store.dart';
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
  late FileImageStore images;

  Future<ImportResult> import(File file, {ImportMode mode = ImportMode.all}) => ImportService.importBackup(
        file,
        questions: questionRepo,
        progress: progressRepo,
        images: images,
        mode: mode,
      );

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
    images = FileImageStore(Directory('${hiveDir.path}/question_images'));
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

    final result = await import(file);

    expect(result.added, 2);
    expect(result.message, 'Se agregaron 2 preguntas');
    expect(questions.length, 2);
    final q1 = questions.values.firstWhere((q) => q.id == 'q1');
    expect(q1.questionText, '¿Capital de Francia?');
    expect(q1.correctAnswerIndex, 0);
    expect(q1.createdAt, DateTime(2025, 3, 1, 10));
    expect(q1.errorCount, 0);
    expect(q1.totalAttempts, 0);
    expect(q1.correctCount, 0);
    // Sin progreso ni estadísticas en el archivo, no se tocan.
    expect(result.progressRestored, isFalse);
    expect(progress.getAt(0)!.dailyGoal, 5);
    expect(progress.getAt(0)!.streak, 1);
    expect(stats.isEmpty, isTrue);
  });

  test('formato v1: respaldo completo con preguntas, progreso y estadísticas', () async {
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

    final result = await import(file);

    expect(result.message, 'Se agregó 1 pregunta y se restauró tu progreso 📈');
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

  test('el respaldo de la versión que tiene el cliente entra sin imágenes rotas', () async {
    // Formato exacto que exporta la versión de diciembre de 2025: rutas de la
    // caché de la app vieja, sin correctCount, y el editor viejo guardaba
    // siempre 4 opciones aunque algunas quedaran vacías.
    final file = await writeBackup({
      'version': 1,
      'questions': [
        {
          'id': 'a',
          'text': '¿Qué número es par?',
          'options': ['3', '4', '', ''],
          'correct': 1,
          'category': 'Matemática ',
          'createdAt': '2025-11-20T18:00:00.000',
          'imagePath': '/data/user/0/com.example.quiz_daily/cache/scaled_1000.jpg',
          'explanation': null,
          'errorCount': 1,
          'totalAttempts': 3,
        },
        {
          'id': 'b',
          'text': 'Pregunta con la correcta vacía',
          'options': ['Sí', '', 'No', ''],
          'correct': 1,
          'category': 'Varios',
          'createdAt': '2025-11-21T18:00:00.000',
          'imagePath': null,
          'explanation': null,
          'errorCount': 0,
          'totalAttempts': 0,
        },
      ],
      'progress': {'dailyGoal': 5, 'streak': 4, 'lastPlayed': '2025-12-10T20:00:00.000', 'notifHour': 18, 'notifMinute': 0},
      'stats': [],
    });

    final result = await import(file, mode: ImportMode.questionsOnly);

    expect(result.added, 1);
    expect(result.invalid, 1);
    expect(result.message, 'Se agregó 1 pregunta (1 no válida)');
    final q = questions.values.single;
    expect(q.id, 'a');
    expect(q.imagePath, isNull, reason: 'la ruta apunta a la caché de la app vieja');
    expect(q.options, ['3', '4']);
    expect(q.correctAnswerIndex, 1);
    expect(q.category, 'Matemática');
    expect((q.totalAttempts, q.correctCount, q.errorCount), (3, 0, 1));
  });

  test('"Solo preguntas" no toca el progreso ni las estadísticas', () async {
    await stats.add(DailyStats(date: DateTime(2026, 10, 29), questionsAnswered: 5, correctAnswers: 4));
    final file = await writeBackup({
      'questions': [
        {'id': 'q1', 'text': 'Nueva', 'options': ['a', 'b'], 'correct': 0, 'category': 'X'},
      ],
      'progress': {'dailyGoal': 20, 'streak': 99, 'notifHour': 7, 'notifMinute': 15},
      'stats': [],
    });

    final result = await import(file, mode: ImportMode.questionsOnly);

    expect(result.added, 1);
    expect(result.progressRestored, isFalse);
    final p = progress.getAt(0)!;
    expect((p.dailyGoal, p.streak, p.notificationHour), (5, 1, 18));
    expect(stats.length, 1);
  });

  test('no duplica preguntas que ya existen con el mismo id ni repetidas en el archivo', () async {
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
        {'id': 'q2', 'text': 'Nueva otra vez', 'options': ['a', 'b'], 'correct': 0, 'category': 'X'},
      ],
    });

    final result = await import(file);

    expect(result.message, 'Se agregó 1 pregunta (2 ya estaban)');
    expect(questions.length, 2);
    expect(questions.values.firstWhere((q) => q.id == 'q1').questionText, 'Existente');
  });

  test('saltea y cuenta los ítems que no se pueden jugar', () async {
    final file = await writeBackup({
      'questions': [
        'no es un objeto',
        {'text': 'Sin id', 'options': ['a', 'b'], 'correct': 0, 'category': 'X'},
        {'id': 'r', 'text': 'Índice fuera de rango', 'options': ['a', 'b'], 'correct': 5, 'category': 'X'},
        {'id': 's', 'text': 'Sin categoría', 'options': ['a', 'b'], 'correct': 0, 'category': ''},
        {
          'id': 't',
          'type': 'matching',
          'questionText': 'Relacionar sin imágenes',
          'matchLeft': ['1', '2'],
          'matchImages': ['/otro/telefono/1.png', '/otro/telefono/2.png'],
          'category': 'X',
        },
        {'id': 'ok', 'text': 'Válida', 'options': ['a', 'b'], 'correct': 1, 'category': 'X'},
      ],
    });

    final result = await import(file);

    expect(result.added, 1);
    expect(result.invalid, 5);
    expect(questions.values.single.id, 'ok');
  });

  test('un archivo que no es un respaldo no escribe nada', () async {
    final notJson = File('${hiveDir.path}/notas.txt')..writeAsStringSync('esto no es un respaldo');
    final brokenZip = File('${hiveDir.path}/roto.zip')..writeAsBytesSync([0x50, 0x4B, 0x03, 0x04, 1, 2, 3, 4, 5]);
    final number = await writeBackup(42);

    for (final file in [notJson, brokenZip, number]) {
      await expectLater(import(file), throwsA(isA<BackupFormatException>()), reason: file.path);
    }
    expect(questions.isEmpty, isTrue);
    expect(progress.getAt(0)!.dailyGoal, 5);
  });

  test('una meta de 0 en el respaldo se guarda como 1 y los valores fuera de rango se ignoran', () async {
    final file = await writeBackup({
      'questions': [],
      'progress': {'dailyGoal': 0, 'streak': -3, 'notifHour': 25, 'notifMinute': 'diez'},
    });

    await import(file);

    final p = progress.getAt(0)!;
    expect(p.dailyGoal, 1);
    expect(p.streak, 1);
    expect(p.notificationHour, 18);
    expect(p.notificationMinute, 0);
  });

  test('las materias se unen con las existentes aunque cambien las mayúsculas', () async {
    await questions.add(Question(
      id: 'x',
      questionText: 'Existente',
      options: ['a', 'b'],
      correctAnswerIndex: 0,
      category: 'Historia',
      createdAt: DateTime(2025),
    ));
    final file = await writeBackup([
      {'id': 'q1', 'text': 'Nueva', 'options': ['a', 'b'], 'correct': 0, 'category': 'historia'},
    ]);

    await import(file);

    expect(questionRepo.categories, ['Historia']);
  });
}
