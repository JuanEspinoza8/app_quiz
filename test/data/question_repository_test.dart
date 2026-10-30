import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:quiz_daily/data/question_repository.dart';
import 'package:quiz_daily/models/question.dart';
import 'package:quiz_daily/services/storage_service.dart';

import '../helpers/hive_test_helper.dart';

Question buildQuestion(String id, {String category = 'Historia'}) => Question(
      id: id,
      questionText: 'Pregunta $id',
      options: ['a', 'b', 'c', 'd'],
      correctAnswerIndex: 0,
      category: category,
      createdAt: DateTime(2026, 1, 1),
    );

void main() {
  late Directory hiveDir;
  late Box<Question> box;
  late QuestionRepository repo;

  setUp(() async {
    hiveDir = await setUpTestHive();
    box = Hive.box<Question>(HiveBoxes.questions);
    repo = QuestionRepository(box);
  });

  tearDown(() async {
    repo.dispose();
    await tearDownTestHive(hiveDir);
  });

  test('categories devuelve las materias sin repetir y en orden de carga', () async {
    await repo.addAll([
      buildQuestion('1', category: 'Historia'),
      buildQuestion('2', category: 'Física'),
      buildQuestion('3', category: 'Historia'),
    ]);

    expect(repo.categories, ['Historia', 'Física']);
    expect(repo.count, 3);
    expect(repo.containsId('2'), isTrue);
    expect(repo.containsId('9'), isFalse);
  });

  test('update reemplaza la pregunta en el mismo lugar', () async {
    await repo.addAll([buildQuestion('1'), buildQuestion('2'), buildQuestion('3')]);
    final original = repo.all[1];

    await repo.update(original, buildQuestion('2')..questionText = 'Editada');

    expect(repo.all.map((q) => q.questionText), ['Pregunta 1', 'Editada', 'Pregunta 3']);
    expect(repo.count, 3);
  });

  test('delete borra la pregunta y restore la vuelve a poner en su lugar', () async {
    await repo.addAll([buildQuestion('1'), buildQuestion('2'), buildQuestion('3')]);
    final deleted = repo.all[1];

    final key = await repo.delete(deleted);
    expect(repo.all.map((q) => q.id), ['1', '3']);

    await repo.restore(key, deleted);
    expect(repo.all.map((q) => q.id), ['1', '2', '3']);
  });

  test('recordAnswer suma intentos, aciertos y ajusta el peso del repaso', () async {
    final q = buildQuestion('1');
    await repo.add(q);

    await repo.recordAnswer(q, correct: false);
    await repo.recordAnswer(q, correct: false);
    expect((q.totalAttempts, q.correctCount, q.errorCount), (2, 0, 2));

    await repo.recordAnswer(q, correct: true);
    expect((q.totalAttempts, q.correctCount, q.errorCount), (3, 1, 1));

    await repo.recordAnswer(q, correct: true);
    await repo.recordAnswer(q, correct: true);
    // El peso nunca baja de 0.
    expect((q.totalAttempts, q.correctCount, q.errorCount), (5, 3, 0));
  });

  test('avisa a los listeners cuando cambia la caja', () async {
    var notifications = 0;
    repo.addListener(() => notifications++);

    await repo.add(buildQuestion('1'));
    await Future<void>.delayed(Duration.zero);

    expect(notifications, greaterThan(0));
  });
}
