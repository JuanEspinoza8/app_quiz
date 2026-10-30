import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_daily/models/user_progress.dart';
import 'package:quiz_daily/screens/questions_list_screen.dart';

import '../helpers/widget_test_helper.dart';

void main() {
  UserProgress progress() => UserProgress(
        dailyGoal: 5,
        answeredToday: 0,
        streak: 0,
        lastPlayedDate: DateTime(2026, 10, 30),
      );

  testWidgets('borrar una pregunta la saca de la lista y se puede deshacer', (tester) async {
    final repos = await createTestRepositories(
      tester,
      progress: progress(),
      questions: [testQuestion('1'), testQuestion('2'), testQuestion('3')],
    );

    await tester.pumpWidget(repos.wrap(const QuestionsListScreen()));
    expect(find.text('Pregunta 2'), findsOneWidget);

    await tester.tap(find.byTooltip('Borrar pregunta').at(1));
    await tester.pumpAndSettle();

    expect(find.text('Pregunta 2'), findsNothing);
    expect(repos.questions.count, 2);
    expect(find.text('Pregunta borrada'), findsOneWidget);

    await tester.tap(find.text('Deshacer'));
    await tester.pumpAndSettle();

    expect(find.text('Pregunta 2'), findsOneWidget);
    expect(repos.questions.all.map((q) => q.id), ['1', '2', '3']);
  });

  testWidgets('si se borra la última pregunta de la materia filtrada, vuelve a "Todas"', (tester) async {
    final repos = await createTestRepositories(
      tester,
      progress: progress(),
      questions: [testQuestion('1', category: 'Historia'), testQuestion('2', category: 'Física')],
    );

    await tester.pumpWidget(repos.wrap(const QuestionsListScreen()));
    await tester.tap(find.widgetWithText(ChoiceChip, 'Física'));
    await tester.pumpAndSettle();
    expect(find.text('Pregunta 1'), findsNothing);

    await tester.tap(find.byTooltip('Borrar pregunta'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(ChoiceChip, 'Física'), findsNothing);
    expect(find.text('Pregunta 1'), findsOneWidget);
  });
}
