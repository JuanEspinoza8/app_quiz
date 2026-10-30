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
  }) async {
    final p = UserProgress(
      dailyGoal: dailyGoal,
      answeredToday: answeredToday,
      streak: streak,
      lastPlayedDate: lastPlayed,
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

    test('racha consecutiva: si ayer cumplió la meta, suma un día', () async {
      final p = await givenProgress(lastPlayed: DateTime(2026, 10, 29, 23, 59), answeredToday: 5, streak: 4);

      repo.rolloverIfNewDay();

      expect(p.streak, 5);
    });

    test('racha consecutiva entre meses y entre años', () async {
      now = DateTime(2026, 11, 1, 0, 5);
      final p = await givenProgress(lastPlayed: DateTime(2026, 10, 31, 23), answeredToday: 5, streak: 1);
      repo.rolloverIfNewDay();
      expect(p.streak, 2);

      now = DateTime(2027, 1, 1, 8);
      p
        ..lastPlayedDate = DateTime(2026, 12, 31, 21)
        ..answeredToday = 5;
      repo.rolloverIfNewDay();
      expect(p.streak, 3);
    });

    test('racha rota: si ayer no llegó a la meta, vuelve a 0', () async {
      final p = await givenProgress(lastPlayed: DateTime(2026, 10, 29, 18), answeredToday: 4, streak: 7);

      repo.rolloverIfNewDay();

      expect(p.streak, 0);
    });

    test('racha rota: si pasó más de un día sin jugar, vuelve a 0', () async {
      final p = await givenProgress(lastPlayed: DateTime(2026, 10, 28, 18), answeredToday: 5, streak: 7);

      repo.rolloverIfNewDay();

      expect(p.streak, 0);
    });
  });

  group('incrementProgress', () {
    test('meta cumplida: suma respuestas hasta llegar a la meta del día', () async {
      final p = await givenProgress(lastPlayed: DateTime(2026, 10, 30, 8), dailyGoal: 3, streak: 1);
      final s = repo;

      for (var i = 0; i < 3; i++) {
        s.incrementProgress(true);
      }

      expect(p.answeredToday, 3);
      expect(p.answeredToday >= p.dailyGoal, isTrue);
      expect(p.streak, 1);
    });

    test('en un día nuevo hace el reinicio antes de sumar', () async {
      final p = await givenProgress(lastPlayed: DateTime(2026, 10, 29, 20), answeredToday: 5, streak: 2);

      repo.incrementProgress(true);

      expect(p.answeredToday, 1);
      expect(p.streak, 3);
    });

    test('la primera respuesta con la racha cortada arranca una racha nueva', () async {
      final p = await givenProgress(lastPlayed: DateTime(2000, 1, 1));

      repo.incrementProgress(false);

      expect(p.streak, 1);
      expect(p.answeredToday, 1);
      expect(p.lastPlayedDate, now);
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

  group('preferencias e historial', () {
    test('ensureInitialized crea el progreso solo si la caja está vacía', () async {
      await repo.ensureInitialized();
      expect(progressBox.length, 1);
      expect(repo.progress.userName, isEmpty);

      await repo.completeOnboarding(userName: 'Juan', dailyGoal: 8);
      await repo.ensureInitialized();

      expect(progressBox.length, 1);
      expect(repo.progress.userName, 'Juan');
      expect(repo.progress.dailyGoal, 8);
    });

    test('updateGoals no acepta una meta menor a 1', () async {
      await givenProgress(lastPlayed: now);

      await repo.updateGoals(dailyGoal: 0, targetCategory: 'Historia', targetDate: DateTime(2026, 12, 1));

      expect(repo.progress.dailyGoal, 1);
      expect(repo.progress.targetCategory, 'Historia');
      expect(repo.progress.targetDate, DateTime(2026, 12, 1));
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
