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
    return Text('${p.answeredToday}/${p.dailyGoal}');
  }
}

void main() {
  testWidgets('al volver a la app otro día, el progreso diario se reinicia', (tester) async {
    var now = DateTime(2026, 10, 29, 22);
    final repos = await createTestRepositories(
      tester,
      progress: UserProgress(dailyGoal: 5, answeredToday: 5, streak: 2, lastPlayedDate: now),
      now: () => now,
    );

    await tester.pumpWidget(repos.wrap(const DayRolloverOnResume(child: _ProgressText())));
    expect(find.text('5/5'), findsOneWidget);

    now = DateTime(2026, 10, 30, 8);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(find.text('0/5'), findsOneWidget);
    expect(repos.progress.progress.streak, 3);
  });
}
