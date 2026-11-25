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
import 'package:quiz_daily/services/image_store.dart';

/// PNG de 1x1 transparente, para imágenes de prueba.
final kTestPng = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, //
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, //
  0x89, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x60, 0x60, 0x60, 0x60, //
  0x00, 0x00, 0x00, 0x05, 0x00, 0x01, 0xA5, 0xF6, 0x45, 0x40, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, //
  0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

/// ImageStore en memoria: los tests de widgets no tocan el disco.
class FakeImageStore implements ImageStore {
  final Map<String, Uint8List> files = {};
  var _counter = 0;

  /// Agrega una imagen con la referencia [ref] (para armar preguntas de prueba).
  String add(String ref) {
    files[ref] = kTestPng;
    return ref;
  }

  @override
  Future<String> saveFromPath(String sourcePath) async => add('img_${_counter++}.png');

  @override
  Future<String> saveBytes(Uint8List bytes, {String extension = 'jpg'}) async {
    final ref = 'img_${_counter++}.$extension';
    files[ref] = bytes;
    return ref;
  }

  @override
  Future<Uint8List?> readBytes(String ref) async => files[ref];

  @override
  bool exists(String ref) => files.containsKey(ref);

  @override
  ImageProvider? providerFor(String ref, {int? cacheWidth}) {
    final bytes = files[ref];
    return bytes == null ? null : MemoryImage(bytes);
  }

  @override
  Future<int> deleteUnreferenced(Set<String> usedRefs) async {
    final unused = files.keys.where((k) => !usedRefs.contains(k)).toList();
    unused.forEach(files.remove);
    return unused.length;
  }
}

/// Repositorios sobre cajas de Hive en memoria. En los tests de widgets el
/// tiempo es simulado y una escritura real a disco no terminaría nunca.
class TestRepositories {
  final QuestionRepository questions;
  final ProgressRepository progress;
  final FakeImageStore images = FakeImageStore();
  TestRepositories(this.questions, this.progress);

  /// Envuelve [screen] en un MaterialApp con los repositorios disponibles.
  Widget wrap(Widget screen) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: questions),
        ChangeNotifierProvider.value(value: progress),
        Provider<ImageStore>.value(value: images),
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

/// Pregunta de relacionar: matchImages[i] es la imagen de [left][i].
Question testMatchingQuestion(String id, {List<String> left = const ['1', '2', '3'], String category = 'Números'}) => Question(
      id: id,
      type: QuestionType.matching,
      questionText: 'Relacionar $id',
      options: const [],
      correctAnswerIndex: 0,
      category: category,
      createdAt: DateTime(2026, 1, 1),
      matchLeft: left,
      matchImages: [for (var i = 0; i < left.length; i++) 'img_${id}_$i.png'],
    );

/// Muestra [screen] encima de una pantalla de inicio, como en la app: así
/// tiene botón para volver y puede cerrarse con Navigator.pop.
Future<void> pushScreen(WidgetTester tester, TestRepositories repos, Widget screen) async {
  await tester.pumpWidget(repos.wrap(Builder(
    builder: (context) => Scaffold(
      body: Center(
        child: TextButton(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => screen)),
          child: const Text('abrir'),
        ),
      ),
    ),
  )));
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
}
