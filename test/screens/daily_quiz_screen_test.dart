import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_daily/models/user_progress.dart';
import 'package:quiz_daily/screens/daily_quiz_screen.dart';

import '../helpers/widget_test_helper.dart';

void main() {
  final today = DateTime(2026, 10, 30, 10);
  final yesterday = DateTime(2026, 10, 29, 21);

  UserProgress progress({required DateTime lastPlayed, required int answeredToday}) => UserProgress(
        dailyGoal: 5,
        answeredToday: answeredToday,
        streak: 3,
        lastPlayedDate: lastPlayed,
        hiddenCategories: [],
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
    expect(repos.progress.progress.streak, 4);
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

    // Deja correr la pausa antes de la siguiente pregunta y el SnackBar.
    await tester.pump(const Duration(seconds: 2));
  });
}
