import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_daily/models/user_progress.dart';
import 'package:quiz_daily/screens/daily_goal_screen.dart';

import '../helpers/widget_test_helper.dart';

void main() {
  UserProgress progress({String? category, DateTime? date}) => UserProgress(
        dailyGoal: 5,
        answeredToday: 0,
        streak: 0,
        lastPlayedDate: DateTime.now(),
        targetCategory: category,
        targetDate: date,
      );

  Future<void> save(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Guardar Cambios'));
    await tester.tap(find.text('Guardar Cambios'));
    await tester.pumpAndSettle();
  }

  testWidgets('con la fecha del examen vencida, avisa y el calendario abre sin errores', (tester) async {
    // Antes showDatePicker recibía una fecha inicial anterior a firstDate.
    final repos = await createTestRepositories(
      tester,
      progress: progress(category: 'Historia', date: DateTime(2020, 3, 10)),
      questions: [testQuestion('1', category: 'Historia')],
    );
    await pushScreen(tester, repos, const DailyGoalScreen());

    expect(find.textContaining('Vencido'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const ValueKey('exam-date')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('exam-date')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(DatePickerDialog), findsOneWidget);
  });

  testWidgets('elegir solo la materia activa el modo examen', (tester) async {
    final repos = await createTestRepositories(
      tester,
      progress: progress(),
      questions: [testQuestion('1', category: 'Historia'), testQuestion('2', category: 'Física')],
    );
    await pushScreen(tester, repos, const DailyGoalScreen());

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Física').last);
    await tester.pumpAndSettle();
    await save(tester);

    expect(repos.progress.progress.targetCategory, 'Física');
    expect(repos.progress.progress.targetDate, isNull);
    expect(repos.progress.activeExamCategory, 'Física');
  });

  testWidgets('la meta acepta solo números y nunca queda en 0', (tester) async {
    final repos = await createTestRepositories(tester, progress: progress());
    await pushScreen(tester, repos, const DailyGoalScreen());

    await tester.enterText(find.byKey(const ValueKey('daily-goal')), 'a1b2');
    await tester.pump();
    expect(find.text('12'), findsOneWidget);
    await save(tester);
    expect(repos.progress.progress.dailyGoal, 12);

    // Espera a que se vaya el aviso de "Objetivos actualizados".
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await pushScreen(tester, repos, const DailyGoalScreen());
    await tester.enterText(find.byKey(const ValueKey('daily-goal')), '0');
    await save(tester);
    expect(repos.progress.progress.dailyGoal, 1);
  });
}
