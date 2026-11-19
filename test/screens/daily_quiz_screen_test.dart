import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_daily/models/user_progress.dart';
import 'package:quiz_daily/screens/daily_quiz_screen.dart';
import 'package:quiz_daily/widgets/matching_board.dart';

import '../helpers/widget_test_helper.dart';

void main() {
  final today = DateTime(2026, 10, 30, 10);
  final yesterday = DateTime(2026, 10, 29, 21);

  UserProgress progress({
    required DateTime lastPlayed,
    required int answeredToday,
    int dailyGoal = 5,
    List<String> hiddenCategories = const [],
    String? examCategory,
  }) =>
      UserProgress(
        dailyGoal: dailyGoal,
        answeredToday: answeredToday,
        streak: 3,
        lastPlayedDate: lastPlayed,
        lastGoalMetDate: DateTime(lastPlayed.year, lastPlayed.month, lastPlayed.day),
        hiddenCategories: hiddenCategories,
        targetCategory: examCategory,
      );

  testWidgets('si hoy ya cumplió la meta, muestra "Meta diaria cumplida"', (tester) async {
    final repos = await createTestRepositories(
      tester,
      progress: progress(lastPlayed: today, answeredToday: 5),
      questions: [testQuestion('1')],
      now: () => today,
    );

    await tester.pumpWidget(repos.wrap(const DailyQuizScreen()));

    expect(find.text('¡Meta diaria cumplida!'), findsOneWidget);
    expect(find.text('Pregunta 1'), findsNothing);
  });

  testWidgets('al día siguiente de cumplir la meta, el quiz deja responder', (tester) async {
    // Bug original: answeredToday seguía en 5/5 y la pantalla quedaba bloqueada.
    final repos = await createTestRepositories(
      tester,
      progress: progress(lastPlayed: yesterday, answeredToday: 5),
      questions: [testQuestion('1')],
      now: () => today,
    );

    await tester.pumpWidget(repos.wrap(const DailyQuizScreen()));

    expect(find.text('¡Meta diaria cumplida!'), findsNothing);
    expect(find.text('Pregunta 1'), findsOneWidget);
    expect(find.text('0/5'), findsOneWidget);
    // Ayer se cumplió la meta: la racha sigue, y suma cuando se cumpla la de hoy.
    expect(repos.progress.progress.streak, 3);
  });

  testWidgets('en modo examen solo salen preguntas de esa materia', (tester) async {
    final repos = await createTestRepositories(
      tester,
      progress: progress(lastPlayed: today, answeredToday: 0, dailyGoal: 20, examCategory: 'Física'),
      questions: [testQuestion('h1', category: 'Historia'), testQuestion('f1', category: 'Física'), testQuestion('f2', category: 'Física')],
      now: () => today,
    );

    await tester.pumpWidget(repos.wrap(DailyQuizScreen(random: Random(1))));
    expect(find.text('📚 Modo Examen: Física'), findsOneWidget);

    for (var i = 0; i < 6; i++) {
      expect(find.text('Pregunta h1'), findsNothing);
      await tester.tap(find.textContaining('Opción A').first);
      await tester.pump();
      await tester.tap(find.text('Continuar'));
      await tester.pump();
    }
  });

  testWidgets('responder suma al progreso del día y a las estadísticas de la pregunta', (tester) async {
    final question = testQuestion('1', correct: 2);
    final repos = await createTestRepositories(
      tester,
      progress: progress(lastPlayed: today, answeredToday: 0),
      questions: [question],
      now: () => today,
    );

    await tester.pumpWidget(repos.wrap(const DailyQuizScreen()));
    await tester.tap(find.text('Opción C 1'));
    await tester.pump();

    expect(find.text('1/5'), findsOneWidget);
    expect(question.totalAttempts, 1);
    expect(question.correctCount, 1);
    expect(find.text('¡Correcto!'), findsOneWidget);

    // La corrección queda hasta tocar "Continuar"; después sigue el quiz.
    await tester.tap(find.text('Continuar'));
    await tester.pump();
    expect(find.text('¡Correcto!'), findsNothing);
    expect(find.text('Continuar'), findsNothing);
    expect(find.text('Pregunta 1'), findsOneWidget);
  });

  testWidgets('la última pregunta del día muestra la corrección antes del trofeo', (tester) async {
    // Bug original: al llegar a la meta saltaba directo al trofeo y no se
    // veía si la respuesta estaba bien.
    final repos = await createTestRepositories(
      tester,
      progress: progress(lastPlayed: today, answeredToday: 0, dailyGoal: 1),
      questions: [testQuestion('1', correct: 2)],
      now: () => today,
    );

    await tester.pumpWidget(repos.wrap(const DailyQuizScreen()));
    await tester.tap(find.text('Opción A 1')); // incorrecta
    await tester.pump();

    expect(find.text('¡Meta diaria cumplida!'), findsNothing);
    expect(find.text('Pregunta 1'), findsOneWidget);
    expect(find.text('Incorrecto'), findsOneWidget);
    // La elegida en rojo y la correcta en verde.
    expect(find.byIcon(Icons.cancel), findsNWidgets(2));
    expect(find.byIcon(Icons.check_circle), findsOneWidget);

    await tester.tap(find.text('Continuar'));
    await tester.pump();

    expect(find.text('¡Meta diaria cumplida!'), findsOneWidget);
  });

  testWidgets('la explicación se muestra debajo de la pregunta al responder', (tester) async {
    final question = testQuestion('1')..explanation = 'Porque lo dice el libro.';
    final repos = await createTestRepositories(
      tester,
      progress: progress(lastPlayed: today, answeredToday: 0),
      questions: [question],
      now: () => today,
    );

    await tester.pumpWidget(repos.wrap(const DailyQuizScreen()));
    expect(find.text('Porque lo dice el libro.'), findsNothing);

    await tester.tap(find.text('Opción B 1'));
    await tester.pump();

    expect(find.text('Porque lo dice el libro.'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('las opciones se muestran mezcladas y se corrige por la opción, no por la posición', (tester) async {
    final repos = await createTestRepositories(
      tester,
      progress: progress(lastPlayed: today, answeredToday: 0),
      questions: [testQuestion('1', correct: 2)],
      now: () => today,
    );

    await tester.pumpWidget(repos.wrap(DailyQuizScreen(random: Random(7))));

    // El mismo azar que usa la pantalla: un número para elegir la pregunta y
    // después la mezcla de las cuatro opciones.
    final random = Random(7)..nextInt(1);
    final expectedOrder = [0, 1, 2, 3]..shuffle(random);
    expect(expectedOrder, isNot([0, 1, 2, 3]));

    const labels = ['Opción A 1', 'Opción B 1', 'Opción C 1', 'Opción D 1'];
    final byPosition = [...labels]..sort((a, b) => tester.getTopLeft(find.text(a)).dy.compareTo(tester.getTopLeft(find.text(b)).dy));
    expect(byPosition, [for (final i in expectedOrder) labels[i]]);

    await tester.tap(find.text('Opción C 1'));
    await tester.pump();
    expect(find.text('¡Correcto!'), findsOneWidget);
  });

  testWidgets('con más de una pregunta, nunca sale la misma dos veces seguidas', (tester) async {
    final repos = await createTestRepositories(
      tester,
      progress: progress(lastPlayed: today, answeredToday: 0, dailyGoal: 20),
      questions: [testQuestion('1'), testQuestion('2')],
      now: () => today,
    );

    await tester.pumpWidget(repos.wrap(DailyQuizScreen(random: Random(3))));

    String shown() => find.text('Pregunta 1').evaluate().isNotEmpty ? '1' : '2';
    var previous = shown();
    for (var i = 0; i < 8; i++) {
      await tester.tap(find.textContaining('Opción A').first);
      await tester.pump();
      await tester.tap(find.text('Continuar'));
      await tester.pump();
      final current = shown();
      expect(current, isNot(previous));
      previous = current;
    }
  });

  group('pregunta de relacionar', () {
    /// Une el elemento [left] con la imagen [image] tocando uno y después la otra.
    Future<void> connect(WidgetTester tester, int left, int image) async {
      final order = tester.widget<MatchingBoard>(find.byType(MatchingBoard)).order;
      for (final key in ['matching-left-$left', 'matching-slot-${order.indexOf(image)}']) {
        await tester.ensureVisible(find.byKey(ValueKey(key)));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(ValueKey(key)));
        await tester.pump();
      }
    }

    testWidgets('todas las parejas bien cuenta como acierto', (tester) async {
      final question = testMatchingQuestion('m1');
      final repos = await createTestRepositories(
        tester,
        progress: progress(lastPlayed: today, answeredToday: 0),
        questions: [question],
        now: () => today,
      );

      await tester.pumpWidget(repos.wrap(DailyQuizScreen(random: Random(5))));
      expect(find.text('Relacionar m1'), findsOneWidget);
      expect(find.byType(MatchingBoard), findsOneWidget);

      for (var i = 0; i < 3; i++) {
        await connect(tester, i, i);
      }
      await tester.ensureVisible(find.text('Confirmar'));
      await tester.tap(find.text('Confirmar'));
      await tester.pump();

      expect(find.text('¡Correcto!'), findsOneWidget);
      expect(find.text('3 de 3 correctas'), findsOneWidget);
      expect(question.correctCount, 1);
      expect(question.errorCount, 0);
      expect(find.text('1/5'), findsOneWidget);
      expect(repos.progress.dailyStats.single.correctAnswers, 1);
    });

    testWidgets('una pareja mal cuenta como error y marca cuál', (tester) async {
      final question = testMatchingQuestion('m1');
      final repos = await createTestRepositories(
        tester,
        progress: progress(lastPlayed: today, answeredToday: 0, dailyGoal: 1),
        questions: [question],
        now: () => today,
      );

      await tester.pumpWidget(repos.wrap(DailyQuizScreen(random: Random(5))));
      await connect(tester, 0, 1);
      await connect(tester, 1, 0);
      await connect(tester, 2, 2);
      await tester.ensureVisible(find.text('Confirmar'));
      await tester.tap(find.text('Confirmar'));
      await tester.pump();

      // Es la última del día: igual se ve la corrección antes del trofeo.
      expect(find.text('Incorrecto'), findsOneWidget);
      expect(find.text('1 de 3 correctas'), findsOneWidget);
      expect(question.errorCount, 1);
      expect(question.correctCount, 0);

      await tester.tap(find.text('Continuar'));
      await tester.pump();
      expect(find.text('¡Meta diaria cumplida!'), findsOneWidget);
    });

    testWidgets('las imágenes nunca salen en el mismo orden que los elementos', (tester) async {
      for (var seed = 0; seed < 10; seed++) {
        final repos = await createTestRepositories(
          tester,
          progress: progress(lastPlayed: today, answeredToday: 0),
          questions: [testMatchingQuestion('m$seed')],
          now: () => today,
        );
        await tester.pumpWidget(repos.wrap(DailyQuizScreen(random: Random(seed))));

        expect(tester.widget<MatchingBoard>(find.byType(MatchingBoard)).order, isNot([0, 1, 2]));
      }
    });
  });

  testWidgets('sin preguntas habilitadas avisa y deja volver', (tester) async {
    final repos = await createTestRepositories(
      tester,
      progress: progress(lastPlayed: today, answeredToday: 0, hiddenCategories: ['Historia']),
      questions: [testQuestion('1', category: 'Historia')],
      now: () => today,
    );

    await tester.pumpWidget(repos.wrap(Builder(
      builder: (context) => TextButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DailyQuizScreen())),
        child: const Text('abrir'),
      ),
    )));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    expect(find.textContaining('No hay preguntas habilitadas'), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('abrir'), findsOneWidget);
  });
}
