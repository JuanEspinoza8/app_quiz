import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_daily/models/daily_stats.dart';
import 'package:quiz_daily/models/user_progress.dart';
import 'package:quiz_daily/screens/profile_screen.dart';

import '../helpers/widget_test_helper.dart';

void main() {
  testWidgets('un día con más respuestas que la escala vieja (20) se dibuja sin errores', (tester) async {
    final repos = await createTestRepositories(
      tester,
      progress: UserProgress(dailyGoal: 5, answeredToday: 0, streak: 0, lastPlayedDate: DateTime.now()),
      questions: [testQuestion('1')],
    );
    await tester.runAsync(() => repos.progress.replaceDailyStats([
          DailyStats(date: DateTime.now(), questionsAnswered: 30, correctAnswers: 25),
        ]));

    await tester.pumpWidget(repos.wrap(const ProfileScreen()));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('30'), findsOneWidget); // total respondidas
  });

  testWidgets('los logros de racha usan la mejor racha y no se pierden si se corta', (tester) async {
    final repos = await createTestRepositories(
      tester,
      progress: UserProgress(dailyGoal: 5, answeredToday: 0, streak: 0, bestStreak: 5, lastPlayedDate: DateTime.now()),
    );
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(repos.wrap(const ProfileScreen()));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Leyenda'));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('En llamas: desbloqueado'), findsOneWidget);
    expect(find.bySemanticsLabel('Leyenda: bloqueado'), findsOneWidget);
    expect(find.text('Racha (mejor: 5)'), findsOneWidget);
    semantics.dispose();
  });
}
