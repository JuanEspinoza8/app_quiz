import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:quiz_daily/data/progress_repository.dart';
import 'package:quiz_daily/models/user_progress.dart';
import 'package:quiz_daily/widgets/day_rollover_on_resume.dart';

import '../helpers/widget_test_helper.dart';

/// Muestra el progreso del día, como la tarjeta del inicio.
class _ProgressText extends StatelessWidget {
  const _ProgressText();

  @override
  Widget build(BuildContext context) {
    final p = context.watch<ProgressRepository>().progress;
    return Text('${p.answeredToday}/${p.dailyGoal} racha ${p.streak}');
  }
}

void main() {
  Future<void> resume(WidgetTester tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
  }

  testWidgets('al volver a la app otro día, el progreso diario se reinicia y la racha sigue', (tester) async {
    var now = DateTime(2026, 10, 29, 22);
    final repos = await createTestRepositories(
      tester,
      progress: UserProgress(
        dailyGoal: 5,
        answeredToday: 5,
        streak: 2,
        lastPlayedDate: now,
        lastGoalMetDate: DateTime(2026, 10, 29),
      ),
      now: () => now,
    );

    await tester.pumpWidget(repos.wrap(const DayRolloverOnResume(child: _ProgressText())));
    expect(find.text('5/5 racha 2'), findsOneWidget);

    now = DateTime(2026, 10, 30, 8);
    await resume(tester);

    expect(find.text('0/5 racha 2'), findsOneWidget);
  });

  testWidgets('si se saltea un día, al volver la racha queda en 0', (tester) async {
    var now = DateTime(2026, 10, 29, 22);
    final repos = await createTestRepositories(
      tester,
      progress: UserProgress(
        dailyGoal: 5,
        answeredToday: 5,
        streak: 2,
        lastPlayedDate: now,
        lastGoalMetDate: DateTime(2026, 10, 29),
      ),
      now: () => now,
    );

    await tester.pumpWidget(repos.wrap(const DayRolloverOnResume(child: _ProgressText())));
    now = DateTime(2026, 10, 31, 8);
    await resume(tester);

    expect(find.text('0/5 racha 0'), findsOneWidget);
  });
}
