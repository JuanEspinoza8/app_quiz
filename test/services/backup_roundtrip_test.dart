import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:quiz_daily/data/progress_repository.dart';
import 'package:quiz_daily/data/question_repository.dart';
import 'package:quiz_daily/models/daily_stats.dart';
import 'package:quiz_daily/models/question.dart';
import 'package:quiz_daily/models/user_progress.dart';
import 'package:quiz_daily/services/data_sync_service.dart';
import 'package:quiz_daily/services/image_store.dart';
import 'package:quiz_daily/services/import_service.dart';
import 'package:quiz_daily/services/storage_service.dart';

import '../helpers/hive_test_helper.dart';

void main() {
  late Directory hiveDir;
  late Box<Question> questionBox;
  late Box<UserProgress> progressBox;
  late Box<DailyStats> statsBox;
  late QuestionRepository questions;
  late ProgressRepository progress;

  setUp(() async {
    hiveDir = await setUpTestHive();
    questionBox = Hive.box<Question>(HiveBoxes.questions);
    progressBox = Hive.box<UserProgress>(HiveBoxes.progress);
    statsBox = Hive.box<DailyStats>(HiveBoxes.stats);
    questions = QuestionRepository(questionBox);
    progress = ProgressRepository(progressBox, statsBox);
    await progressBox.add(UserProgress(
      dailyGoal: 7,
      answeredToday: 3,
      streak: 4,
      lastPlayedDate: DateTime(2026, 11, 18, 20),
      notificationHour: 21,
      notificationMinute: 15,
    ));
  });

  tearDown(() async {
    questions.dispose();
    progress.dispose();
    await tearDownTestHive(hiveDir);
  });

  test('exportar e importar en otro teléfono conserva preguntas, imágenes y progreso', () async {
    // --- Teléfono A ---
    final imagesA = FileImageStore(Directory('${hiveDir.path}/a_images'));
    final photo = await imagesA.saveBytes(Uint8List.fromList([1, 1, 1]), extension: 'png');
    final img1 = await imagesA.saveBytes(Uint8List.fromList([2, 2]), extension: 'jpg');
    final img2 = await imagesA.saveBytes(Uint8List.fromList([3]), extension: 'jpg');
    final img3 = await imagesA.saveBytes(Uint8List.fromList([4, 4, 4, 4]), extension: 'webp');

    await questions.addAll([
      Question(
        id: 'mc',
        questionText: '¿Qué animal es?',
        options: ['Perro', 'Gato'],
        correctAnswerIndex: 1,
        category: 'Animales',
        createdAt: DateTime(2026, 11, 1),
        imagePath: photo,
        explanation: 'Tiene bigotes.',
        totalAttempts: 3,
        correctCount: 2,
        errorCount: 1,
      ),
      Question(
        id: 'match',
        type: QuestionType.matching,
        questionText: 'Uní cada número con su imagen',
        options: const [],
        correctAnswerIndex: 0,
        category: 'Números',
        createdAt: DateTime(2026, 11, 2),
        matchLeft: ['1', '2', '3'],
        matchImages: [img1, img2, img3],
      ),
      Question(
        id: 'sin-archivo',
        questionText: 'La imagen ya no está',
        options: ['a', 'b'],
        correctAnswerIndex: 0,
        category: 'Varios',
        createdAt: DateTime(2026, 11, 3),
        imagePath: 'borrada.png',
      ),
    ]);
    await progress.replaceDailyStats([
      DailyStats(date: DateTime(2026, 11, 17), questionsAnswered: 7, correctAnswers: 5),
      DailyStats(date: DateTime(2026, 11, 18), questionsAnswered: 3, correctAnswers: 3),
    ]);

    final zip = await DataSyncService.buildBackupZip(questions: questions, progress: progress, images: imagesA);

    // El zip tiene el json y una copia de cada imagen que existe.
    final archive = ZipDecoder().decodeBytes(zip);
    expect(archive.findFile('backup.json'), isNotNull);
    expect(archive.files.where((f) => f.name.startsWith('images/')), hasLength(4));
    final json = jsonDecode(utf8.decode(archive.findFile('backup.json')!.content)) as Map;
    expect(json['version'], 2);
    expect((json['questions'] as List).first['questionText'], '¿Qué animal es?');

    // --- Teléfono B: datos vacíos y otra carpeta de imágenes ---
    await questionBox.clear();
    await statsBox.clear();
    progressBox.getAt(0)!
      ..dailyGoal = 5
      ..streak = 0
      ..notificationHour = 18
      ..notificationMinute = 0;
    final imagesB = FileImageStore(Directory('${hiveDir.path}/b_images'));
    final file = File('${hiveDir.path}/QuizBackup.zip')..writeAsBytesSync(zip);

    final result = await ImportService.importBackup(file, questions: questions, progress: progress, images: imagesB);

    expect(result.added, 3);
    expect(result.invalid, 0);
    expect(result.progressRestored, isTrue);

    final mc = questionBox.values.firstWhere((q) => q.id == 'mc');
    expect(mc.questionText, '¿Qué animal es?');
    expect(mc.options, ['Perro', 'Gato']);
    expect(mc.correctAnswerIndex, 1);
    expect(mc.explanation, 'Tiene bigotes.');
    expect((mc.totalAttempts, mc.correctCount, mc.errorCount), (3, 2, 1));
    expect(await imagesB.readBytes(mc.imagePath!), [1, 1, 1]);

    final match = questionBox.values.firstWhere((q) => q.id == 'match');
    expect(match.isMatching, isTrue);
    expect(match.matchLeft, ['1', '2', '3']);
    // Cada elemento sigue con su imagen.
    expect([for (final ref in match.matchImages) await imagesB.readBytes(ref)], [
      [2, 2],
      [3],
      [4, 4, 4, 4],
    ]);
    expect(match.matchImages.last, endsWith('.webp'));

    // La que había perdido la imagen se restaura sin ella.
    expect(questionBox.values.firstWhere((q) => q.id == 'sin-archivo').imagePath, isNull);

    final p = progressBox.getAt(0)!;
    expect((p.dailyGoal, p.streak, p.notificationHour, p.notificationMinute), (7, 4, 21, 15));
    expect(statsBox.values.map((s) => s.questionsAnswered), [7, 3]);

    // Restaurar el mismo respaldo otra vez no duplica nada.
    final again = await ImportService.importBackup(file, questions: questions, progress: progress, images: imagesB);
    expect(again.added, 0);
    expect(again.duplicates, 3);
    expect(questionBox.length, 3);
  });

  test('una imagen usada por dos preguntas viaja una sola vez', () async {
    final images = FileImageStore(Directory('${hiveDir.path}/images'));
    final shared = await images.saveBytes(Uint8List.fromList([9]), extension: 'png');
    for (final id in ['a', 'b']) {
      await questions.add(Question(
        id: id,
        questionText: 'Pregunta $id',
        options: ['x', 'y'],
        correctAnswerIndex: 0,
        category: 'C',
        createdAt: DateTime(2026),
        imagePath: shared,
      ));
    }

    final zip = await DataSyncService.buildBackupZip(questions: questions, progress: progress, images: images);

    expect(ZipDecoder().decodeBytes(zip).files.where((f) => f.name.startsWith('images/')), hasLength(1));
  });
}
