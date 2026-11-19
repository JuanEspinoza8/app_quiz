import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:quiz_daily/models/daily_stats.dart';
import 'package:quiz_daily/models/user_progress.dart';
import 'package:quiz_daily/data/progress_repository.dart';
import 'package:quiz_daily/services/storage_service.dart';

import '../helpers/hive_test_helper.dart';

void main() {
  late Directory hiveDir;
  late Box<UserProgress> progressBox;
  late Box<DailyStats> statsBox;
  late DateTime now;
  late ProgressRepository repo;

  Future<UserProgress> givenProgress({
    required DateTime lastPlayed,
    int answeredToday = 0,
    int streak = 0,
    int dailyGoal = 5,
    DateTime? lastGoalMet,
    int bestStreak = 0,
  }) async {
    final p = UserProgress(
      dailyGoal: dailyGoal,
      answeredToday: answeredToday,
      streak: streak,
      lastPlayedDate: lastPlayed,
      lastGoalMetDate: lastGoalMet,
      bestStreak: bestStreak,
    );
    await progressBox.add(p);
    return p;
  }

  setUp(() async {
    hiveDir = await setUpTestHive();
    progressBox = Hive.box<UserProgress>(HiveBoxes.progress);
    statsBox = Hive.box<DailyStats>(HiveBoxes.stats);
    now = DateTime(2026, 10, 30, 9, 15);
    // El reloj lee la variable now en cada llamada, así cada test puede moverlo.
    repo = ProgressRepository(progressBox, statsBox, now: () => now);
  });

  tearDown(() async {
    repo.dispose();
    await tearDownTestHive(hiveDir);
  });

  group('rolloverIfNewDay', () {
    test('el mismo día no cambia nada', () async {
      final p = await givenProgress(lastPlayed: DateTime(2026, 10, 30, 7), answeredToday: 3, streak: 2);

      expect(repo.rolloverIfNewDay(), isFalse);
      expect(p.answeredToday, 3);
      expect(p.streak, 2);
    });

    test('al cambiar de día reinicia el contador y guarda la fecha nueva', () async {
      final p = await givenProgress(lastPlayed: DateTime(2026, 10, 29, 22), answeredToday: 3);

      expect(repo.rolloverIfNewDay(), isTrue);
      expect(p.answeredToday, 0);
      expect(p.lastPlayedDate, now);
    });

    test('con la meta de ayer cumplida, el quiz de hoy no queda bloqueado', () async {
      // Es el bug original: answeredToday seguía en 5/5 al día siguiente y la
      // pantalla mostraba "Meta diaria cumplida" antes de poder responder.
      final p = await givenProgress(lastPlayed: DateTime(2026, 10, 29, 20), answeredToday: 5, dailyGoal: 5);

      repo.rolloverIfNewDay();

      expect(p.answeredToday < p.dailyGoal, isTrue);
    });

    test('si ayer cumplió la meta, la racha sigue (hoy todavía no suma)', () async {
      final p = await givenProgress(
        lastPlayed: DateTime(2026, 10, 29, 23, 59),
        answeredToday: 5,
        streak: 4,
        lastGoalMet: DateTime(2026, 10, 29),
      );

      repo.rolloverIfNewDay();

      expect(p.streak, 4);
    });

    test('si ayer no llegó a la meta, la racha vuelve a 0', () async {
      final p = await givenProgress(
        lastPlayed: DateTime(2026, 10, 29, 18),
        answeredToday: 4,
        streak: 7,
        lastGoalMet: DateTime(2026, 10, 28),
      );

      repo.rolloverIfNewDay();

      expect(p.streak, 0);
    });

    test('si pasó más de un día sin jugar, la racha vuelve a 0', () async {
      final p = await givenProgress(
        lastPlayed: DateTime(2026, 10, 28, 18),
        answeredToday: 5,
        streak: 7,
        lastGoalMet: DateTime(2026, 10, 28),
      );

      repo.rolloverIfNewDay();

      expect(p.streak, 0);
    });
  });

  group('racha', () {
    test('cumplir la meta suma un día en ese momento, una sola vez', () async {
      final p = await givenProgress(
        lastPlayed: DateTime(2026, 10, 30, 8),
        dailyGoal: 3,
        streak: 4,
        lastGoalMet: DateTime(2026, 10, 29),
      );

      repo.incrementProgress(true);
      repo.incrementProgress(false);
      expect(p.streak, 4, reason: 'todavía no llegó a la meta');

      repo.incrementProgress(true);
      expect(p.streak, 5);
      expect(p.lastGoalMetDate, DateTime(2026, 10, 30));
      expect(p.bestStreak, 5);

      repo.incrementProgress(true);
      expect(p.streak, 5, reason: 'pasarse de la meta no suma otro día');
    });

    test('quedarse a mitad de la meta no arranca una racha', () async {
      // Antes la primera respuesta del día ya ponía la racha en 1.
      final p = await givenProgress(lastPlayed: DateTime(2000, 1, 1));

      repo.incrementProgress(false);

      expect(p.streak, 0);
      expect(p.answeredToday, 1);
      expect(p.lastPlayedDate, now);
    });

    test('con la racha cortada, cumplir la meta la arranca en 1', () async {
      final p = await givenProgress(
        lastPlayed: DateTime(2026, 10, 30, 8),
        dailyGoal: 2,
        lastGoalMet: DateTime(2026, 10, 20),
        bestStreak: 9,
      );

      repo.incrementProgress(true);
      repo.incrementProgress(true);

      expect(p.streak, 1);
      expect(p.bestStreak, 9, reason: 'la mejor racha no se pierde');
    });

    test('días seguidos entre meses y entre años', () async {
      final p = await givenProgress(lastPlayed: DateTime(2026, 10, 31, 9), dailyGoal: 1);

      for (final day in [DateTime(2026, 10, 31, 10), DateTime(2026, 11, 1, 0, 5), DateTime(2026, 11, 2, 23)]) {
        now = day;
        repo.incrementProgress(true);
      }
      expect(p.streak, 3);

      now = DateTime(2026, 12, 31, 21);
      p
        ..lastGoalMetDate = DateTime(2026, 12, 30)
        ..streak = 10;
      repo.incrementProgress(true);
      now = DateTime(2027, 1, 1, 8);
      repo.incrementProgress(true);
      expect(p.streak, 12);
      expect(p.bestStreak, 12);
    });

    test('bajar la meta por debajo de lo respondido hoy cuenta el día', () async {
      final p = await givenProgress(
        lastPlayed: DateTime(2026, 10, 30, 8),
        answeredToday: 3,
        dailyGoal: 5,
        streak: 2,
        lastGoalMet: DateTime(2026, 10, 29),
      );

      await repo.updateGoals(dailyGoal: 3);

      expect(p.streak, 3);
      expect(p.lastGoalMetDate, DateTime(2026, 10, 30));
    });

    test('migra la racha guardada por la versión anterior', () async {
      // Antes la racha contaba el día de hoy por adelantado.
      final metToday = await givenProgress(
        lastPlayed: DateTime(2026, 10, 30, 8),
        answeredToday: 5,
        streak: 3,
      );
      await repo.ensureInitialized();
      expect(metToday.streak, 3);
      expect(metToday.lastGoalMetDate, DateTime(2026, 10, 30));
      expect(metToday.bestStreak, 3);

      await progressBox.clear();
      final notYet = await givenProgress(
        lastPlayed: DateTime(2026, 10, 30, 8),
        answeredToday: 2,
        streak: 3,
      );
      await repo.ensureInitialized();
      expect(notYet.streak, 2);
      expect(notYet.lastGoalMetDate, DateTime(2026, 10, 29));
    });
  });

  group('incrementProgress', () {
    test('en un día nuevo hace el reinicio antes de sumar', () async {
      final p = await givenProgress(
        lastPlayed: DateTime(2026, 10, 29, 20),
        answeredToday: 5,
        streak: 2,
        lastGoalMet: DateTime(2026, 10, 29),
      );

      repo.incrementProgress(true);

      expect(p.answeredToday, 1);
      expect(p.streak, 2);
    });

    test('registra aciertos y respuestas en el historial del día', () async {
      await givenProgress(lastPlayed: DateTime(2026, 10, 30, 8));
      final s = repo;

      s.incrementProgress(true);
      s.incrementProgress(false);
      s.incrementProgress(true);

      expect(statsBox.length, 1);
      final today = statsBox.getAt(0)!;
      expect(today.questionsAnswered, 3);
      expect(today.correctAnswers, 2);
    });

    test('un día nuevo crea otra entrada en el historial', () async {
      await givenProgress(lastPlayed: DateTime(2026, 10, 30, 8));
      repo.incrementProgress(true);

      now = DateTime(2026, 10, 31, 10);
      repo.incrementProgress(false);

      expect(statsBox.length, 2);
      expect(statsBox.getAt(1)!.correctAnswers, 0);
    });
  });

  group('modo examen', () {
    test('sin materia no hay modo examen', () async {
      await givenProgress(lastPlayed: now);
      expect(repo.activeExamCategory, isNull);
    });

    test('con materia y sin fecha queda activo', () async {
      await givenProgress(lastPlayed: now);
      await repo.updateGoals(dailyGoal: 5, targetCategory: 'Historia');

      expect(repo.activeExamCategory, 'Historia');
      expect(repo.isExamExpired, isFalse);
    });

    test('sigue activo hasta el día del examen inclusive y después se desactiva solo', () async {
      await givenProgress(lastPlayed: now);
      await repo.updateGoals(dailyGoal: 5, targetCategory: 'Historia', targetDate: DateTime(2026, 11, 2));

      now = DateTime(2026, 11, 2, 23, 59);
      expect(repo.activeExamCategory, 'Historia');

      now = DateTime(2026, 11, 3, 0, 1);
      expect(repo.activeExamCategory, isNull);
      expect(repo.isExamExpired, isTrue);
    });
  });

  group('preferencias e historial', () {
    test('ensureInitialized crea el progreso solo si la caja está vacía', () async {
      await repo.ensureInitialized();
      expect(progressBox.length, 1);
      expect(repo.progress.userName, isEmpty);
      expect(repo.progress.dailyGoal, kDefaultDailyGoal);

      await repo.completeOnboarding(userName: 'Juan', dailyGoal: 8);
      await repo.ensureInitialized();

      expect(progressBox.length, 1);
      expect(repo.progress.userName, 'Juan');
      expect(repo.progress.dailyGoal, 8);
    });

    test('updateGoals deja la meta entre 1 y el máximo', () async {
      await givenProgress(lastPlayed: now);

      await repo.updateGoals(dailyGoal: 0, targetCategory: 'Historia', targetDate: DateTime(2026, 12, 1));
      expect(repo.progress.dailyGoal, 1);
      expect(repo.progress.targetCategory, 'Historia');
      expect(repo.progress.targetDate, DateTime(2026, 12, 1));

      await repo.updateGoals(dailyGoal: 500);
      expect(repo.progress.dailyGoal, kMaxDailyGoal);
    });

    test('restoreFromBackup trae la racha con su día y la mejor racha', () async {
      final p = await givenProgress(lastPlayed: now, bestStreak: 2);

      await repo.restoreFromBackup(streak: 6, lastPlayed: DateTime(2026, 10, 29, 20), lastGoalMet: DateTime(2026, 10, 29));
      expect((p.streak, p.lastGoalMetDate, p.bestStreak), (6, DateTime(2026, 10, 29), 6));

      // Un respaldo viejo no trae lastGoalMet: se usa el último día jugado.
      await repo.restoreFromBackup(streak: 3, lastPlayed: DateTime(2026, 10, 28, 20), bestStreak: 10);
      expect((p.streak, p.lastGoalMetDate, p.bestStreak), (3, DateTime(2026, 10, 28, 20), 10));
    });

    test('setCategoryHidden funciona aunque la lista por defecto sea constante', () async {
      // UserProgress usa const [] como valor por defecto: modificarla en el
      // lugar tiraría UnsupportedError.
      await givenProgress(lastPlayed: now);

      await repo.setCategoryHidden('Historia', true);
      await repo.setCategoryHidden('Historia', true);
      await repo.setCategoryHidden('Física', true);
      expect(repo.progress.hiddenCategories, ['Historia', 'Física']);

      await repo.setCategoryHidden('Historia', false);
      expect(repo.progress.hiddenCategories, ['Física']);
    });

    test('totals suma respondidas y acertadas de todo el historial', () async {
      await repo.replaceDailyStats([
        DailyStats(date: DateTime(2026, 10, 28), questionsAnswered: 5, correctAnswers: 4),
        DailyStats(date: DateTime(2026, 10, 29), questionsAnswered: 3, correctAnswers: 1),
      ]);

      expect(repo.totals, (answered: 8, correct: 5));
      expect(repo.statsFor(DateTime(2026, 10, 29, 18))!.questionsAnswered, 3);
      expect(repo.statsFor(DateTime(2026, 10, 30)), isNull);
    });

    test('avisa a los listeners cuando cambia el progreso', () async {
      await givenProgress(lastPlayed: now);
      var notifications = 0;
      repo.addListener(() => notifications++);

      await repo.setDarkMode(true);
      // Los eventos de Hive llegan por un Stream: se procesan en el próximo ciclo.
      await Future<void>.delayed(Duration.zero);

      expect(notifications, greaterThan(0));
    });
  });
}
