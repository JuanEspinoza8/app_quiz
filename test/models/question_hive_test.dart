import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:quiz_daily/models/question.dart';

/// Escribe una Question como lo hacía la versión anterior (campos 0 a 10),
/// para comprobar que las preguntas ya guardadas se siguen leyendo.
class _LegacyQuestionAdapter extends TypeAdapter<Question> {
  @override
  final int typeId = 0;

  @override
  Question read(BinaryReader reader) => throw UnimplementedError();

  @override
  void write(BinaryWriter writer, Question obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.questionText)
      ..writeByte(2)
      ..write(obj.options)
      ..writeByte(3)
      ..write(obj.correctAnswerIndex)
      ..writeByte(4)
      ..write(obj.category)
      ..writeByte(5)
      ..write(obj.createdAt)
      ..writeByte(6)
      ..write(obj.imagePath)
      ..writeByte(7)
      ..write(obj.explanation)
      ..writeByte(8)
      ..write(obj.errorCount)
      ..writeByte(9)
      ..write(obj.totalAttempts)
      ..writeByte(10)
      ..write(obj.correctCount);
  }
}

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('quiz_hive_model_test_');
    Hive.init(dir.path);
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  test('una pregunta de relacionar se guarda y se lee con sus parejas', () async {
    Hive.registerAdapter(QuestionAdapter(), override: true);
    var box = await Hive.openBox<Question>('questions');
    await box.add(Question(
      id: 'm1',
      type: QuestionType.matching,
      questionText: 'Uní cada número con su imagen',
      options: const [],
      correctAnswerIndex: 0,
      category: 'Números',
      createdAt: DateTime(2026, 11, 1),
      matchLeft: ['1', '2', '3'],
      matchImages: ['uno.png', 'dos.png', 'tres.png'],
    ));
    await box.close();

    box = await Hive.openBox<Question>('questions');
    final q = box.getAt(0)!;
    expect(q.isMatching, isTrue);
    expect(q.matchLeft, ['1', '2', '3']);
    expect(q.matchImages, ['uno.png', 'dos.png', 'tres.png']);
    expect(q.imageRefs, ['uno.png', 'dos.png', 'tres.png']);
  });

  test('las preguntas guardadas por la versión anterior se leen como opción múltiple', () async {
    Hive.registerAdapter(_LegacyQuestionAdapter(), override: true);
    var box = await Hive.openBox<Question>('questions');
    await box.add(Question(
      id: 'vieja',
      questionText: '¿2 + 2?',
      options: ['3', '4'],
      correctAnswerIndex: 1,
      category: 'Matemática',
      createdAt: DateTime(2025, 12, 1),
      imagePath: '/data/user/0/app/cache/foto.jpg',
      totalAttempts: 4,
      correctCount: 3,
    ));
    await box.close();

    Hive.registerAdapter(QuestionAdapter(), override: true);
    box = await Hive.openBox<Question>('questions');
    final q = box.getAt(0)!;
    expect(q.type, QuestionType.multipleChoice);
    expect(q.isMatching, isFalse);
    expect(q.matchLeft, isEmpty);
    expect(q.matchImages, isEmpty);
    expect(q.options, ['3', '4']);
    expect(q.totalAttempts, 4);
    expect(q.imageRefs, ['/data/user/0/app/cache/foto.jpg']);
  });

  test('toJson y fromJson conservan todos los campos', () {
    final original = Question(
      id: 'm1',
      type: QuestionType.matching,
      questionText: 'Uní',
      options: const [],
      correctAnswerIndex: 0,
      category: 'Números',
      createdAt: DateTime(2026, 11, 1, 10),
      explanation: 'Porque sí',
      errorCount: 1,
      totalAttempts: 2,
      correctCount: 1,
      matchLeft: ['1', '2'],
      matchImages: ['a.png', 'b.png'],
    );

    final copy = Question.fromJson(original.toJson());

    expect(copy.toJson(), original.toJson());
  });

  test('fromJson acepta las claves del respaldo de la versión 1', () {
    final q = Question.fromJson({
      'id': 'q1',
      'text': '¿Capital de Italia?',
      'options': ['París', 'Roma'],
      'correct': 1,
      'category': 'Geografía',
      'createdAt': '2025-03-01T10:00:00.000',
    });

    expect(q.questionText, '¿Capital de Italia?');
    expect(q.correctAnswerIndex, 1);
    expect(q.type, QuestionType.multipleChoice);
    expect(q.correctCount, 0);
  });

  test('copyWith puede dejar la imagen en null', () {
    final q = Question(
      id: 'q',
      questionText: 'x',
      options: ['a', 'b'],
      correctAnswerIndex: 0,
      category: 'c',
      createdAt: DateTime(2026),
      imagePath: 'foto.png',
    );

    expect(q.copyWith(imagePath: () => null).imagePath, isNull);
    expect(q.copyWith(category: 'd').imagePath, 'foto.png');
  });
}
