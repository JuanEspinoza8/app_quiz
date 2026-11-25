import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_daily/models/question.dart';
import 'package:quiz_daily/models/user_progress.dart';
import 'package:quiz_daily/screens/add_question_screen.dart';

import '../helpers/widget_test_helper.dart';

void main() {
  UserProgress progress() => UserProgress(
        dailyGoal: 5,
        answeredToday: 0,
        streak: 0,
        lastPlayedDate: DateTime(2026, 10, 30),
      );

  /// El selector de imágenes de prueba: siempre "elige" el mismo archivo.
  Future<String?> fakePicker() async => '/galeria/foto.jpg';

  Future<void> enter(WidgetTester tester, String key, String text) async {
    await tester.enterText(find.byKey(ValueKey(key)), text);
    await tester.pump();
  }

  Future<void> save(WidgetTester tester) async {
    await tester.ensureVisible(find.text('GUARDAR PREGUNTA'));
    await tester.tap(find.text('GUARDAR PREGUNTA'));
    await tester.pumpAndSettle();
  }

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('sin enunciado no guarda y avisa qué falta', (tester) async {
    final repos = await createTestRepositories(tester, progress: progress());
    await pushScreen(tester, repos, AddQuestionScreen(pickImage: fakePicker));

    await save(tester);

    expect(find.text('Falta el enunciado.'), findsOneWidget);
    expect(repos.questions.count, 0);
    expect(find.text('Nueva Pregunta'), findsOneWidget);
  });

  testWidgets('opción múltiple: no acepta opciones vacías; se pueden quitar las que sobran', (tester) async {
    final repos = await createTestRepositories(tester, progress: progress());
    await pushScreen(tester, repos, AddQuestionScreen(pickImage: fakePicker));

    await enter(tester, 'question-text', '¿Capital de Francia?');
    await enter(tester, 'category', 'Geografía');
    await enter(tester, 'option-0', 'París');
    await enter(tester, 'option-1', 'Roma');
    await save(tester);
    expect(find.text('Completá todas las opciones (o quitá las que sobran).'), findsOneWidget);

    // Quedan dos opciones: las vacías se quitan.
    await tapVisible(tester, find.byTooltip('Quitar opción 4'));
    await tapVisible(tester, find.byTooltip('Quitar opción 3'));
    expect(find.byTooltip('Quitar opción 1'), findsNothing, reason: 'con 2 opciones no se puede quitar más');

    await save(tester);

    final q = repos.questions.all.single;
    expect(q.options, ['París', 'Roma']);
    expect(q.correctAnswerIndex, 0);
    expect(q.type, QuestionType.multipleChoice);
    expect(find.text('abrir'), findsOneWidget, reason: 'al guardar vuelve a la pantalla anterior');
  });

  testWidgets('opción múltiple: se pueden agregar hasta 6 opciones y marcar la correcta', (tester) async {
    final repos = await createTestRepositories(tester, progress: progress());
    await pushScreen(tester, repos, AddQuestionScreen(pickImage: fakePicker));

    await tapVisible(tester, find.text('Agregar opción'));
    await tapVisible(tester, find.text('Agregar opción'));
    expect(find.text('Agregar opción'), findsNothing);

    await enter(tester, 'question-text', '¿Cuál es par?');
    await enter(tester, 'category', 'Matemática');
    for (var i = 0; i < 6; i++) {
      await enter(tester, 'option-$i', '${i + 1}');
    }
    await tapVisible(tester, find.byType(Radio<int>).at(3));
    await save(tester);

    final q = repos.questions.all.single;
    expect(q.options, ['1', '2', '3', '4', '5', '6']);
    expect(q.correctAnswerIndex, 3);
  });

  testWidgets('relacionar: guarda cada texto con su imagen en el mismo orden', (tester) async {
    final repos = await createTestRepositories(tester, progress: progress());
    await pushScreen(tester, repos, AddQuestionScreen(pickImage: fakePicker));

    await tester.tap(find.text('Relacionar'));
    await tester.pumpAndSettle();
    await enter(tester, 'question-text', 'Uní cada número con su imagen');
    await enter(tester, 'category', 'Números');
    for (var i = 0; i < 3; i++) {
      await enter(tester, 'pair-text-$i', '${i + 1}');
      await tapVisible(tester, find.byKey(ValueKey('pair-image-$i')).first);
    }
    await save(tester);

    final q = repos.questions.all.single;
    expect(q.isMatching, isTrue);
    expect(q.matchLeft, ['1', '2', '3']);
    expect(q.matchImages, ['img_0.png', 'img_1.png', 'img_2.png']);
    expect(q.options, isEmpty);
    expect(q.imagePath, isNull);
    // La imagen se copió al almacenamiento de la app, no se guardó la ruta de la galería.
    expect(repos.images.files.keys, containsAll(q.matchImages));
  });

  testWidgets('relacionar: avisa si a una pareja le falta la imagen', (tester) async {
    final repos = await createTestRepositories(tester, progress: progress());
    await pushScreen(tester, repos, AddQuestionScreen(pickImage: fakePicker));

    await tester.tap(find.text('Relacionar'));
    await tester.pumpAndSettle();
    await enter(tester, 'question-text', 'Uní');
    await enter(tester, 'category', 'Números');
    for (var i = 0; i < 3; i++) {
      await enter(tester, 'pair-text-$i', '${i + 1}');
    }
    await tapVisible(tester, find.byKey(const ValueKey('pair-image-0')).first);
    await save(tester);

    expect(find.text('Falta la imagen de la pareja 2.'), findsOneWidget);
    expect(repos.questions.count, 0);
  });

  testWidgets('relacionar: se pueden agregar y quitar parejas (de 2 a 6)', (tester) async {
    final repos = await createTestRepositories(tester, progress: progress());
    await pushScreen(tester, repos, AddQuestionScreen(pickImage: fakePicker));
    await tester.tap(find.text('Relacionar'));
    await tester.pumpAndSettle();

    for (var i = 0; i < 3; i++) {
      await tapVisible(tester, find.text('Agregar pareja'));
    }
    expect(find.byKey(const ValueKey('pair-text-5')), findsOneWidget);
    expect(find.text('Agregar pareja'), findsNothing);

    for (var i = 6; i > 2; i--) {
      await tapVisible(tester, find.byTooltip('Quitar pareja $i'));
    }
    expect(find.byKey(const ValueKey('pair-text-2')), findsNothing);
    expect(find.byTooltip('Quitar pareja 1'), findsNothing);
  });

  testWidgets('editar conserva el tipo y las estadísticas, y no deja cambiar el tipo', (tester) async {
    final original = testMatchingQuestion('m1')
      ..totalAttempts = 4
      ..correctCount = 3
      ..errorCount = 1;
    final repos = await createTestRepositories(tester, progress: progress(), questions: [original]);
    await pushScreen(tester, repos, AddQuestionScreen(editQuestion: original, pickImage: fakePicker));

    expect(find.text('Editar Pregunta'), findsOneWidget);
    await tester.tap(find.text('Opción múltiple'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('pair-text-0')), findsOneWidget, reason: 'sigue en relacionar');

    await enter(tester, 'pair-text-1', 'Dos');
    await save(tester);

    final q = repos.questions.all.single;
    expect(q.id, 'm1');
    expect(q.isMatching, isTrue);
    expect(q.matchLeft, ['1', 'Dos', '3']);
    expect(q.matchImages, original.matchImages);
    expect((q.totalAttempts, q.correctCount, q.errorCount), (4, 3, 1));
  });

  testWidgets('se puede quitar la imagen del enunciado', (tester) async {
    final original = testQuestion('1')..imagePath = 'foto.png';
    final repos = await createTestRepositories(tester, progress: progress(), questions: [original]);
    repos.images.add('foto.png');
    await pushScreen(tester, repos, AddQuestionScreen(editQuestion: original, pickImage: fakePicker));

    await tester.tap(find.byTooltip('Quitar imagen'));
    await tester.pumpAndSettle();
    await save(tester);

    expect(repos.questions.all.single.imagePath, isNull);
  });

  testWidgets('una materia escrita con otras mayúsculas se guarda como la existente', (tester) async {
    final repos = await createTestRepositories(tester, progress: progress(), questions: [testQuestion('1', category: 'Historia')]);
    await pushScreen(tester, repos, AddQuestionScreen(pickImage: fakePicker));

    await enter(tester, 'question-text', '¿Año de la Revolución de Mayo?');
    await enter(tester, 'category', ' historia ');
    for (var i = 0; i < 4; i++) {
      await enter(tester, 'option-$i', '${1806 + i * 2}');
    }
    await save(tester);

    expect(repos.questions.categories, ['Historia']);
  });
}
