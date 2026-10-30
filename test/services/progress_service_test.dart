import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:quiz_daily/models/daily_stats.dart';
import 'package:quiz_daily/models/user_progress.dart';
import 'package:quiz_daily/services/progress_service.dart';
import 'package:quiz_daily/services/storage_service.dart';

import '../helpers/hive_test_helper.dart';

void main() {
  late Directory hiveDir;
  late Box<UserProgress> progressBox;
  late Box<DailyStats> statsBox;
  late DateTime now;

  ProgressService service() => ProgressService(
        progressBox: progressBox,
        statsBox: statsBox,
        now: () => now,
      );

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
  });

  tearDown(() => tearDownTestHive(hiveDir));

  group('rolloverIfNewDay', () {
    test('el mismo día no cambia nada', () async {
      final p = await givenProgress(lastPlayed: DateTime(2026, 10, 30, 7), answeredToday: 3, streak: 2);

      expect(service().rolloverIfNewDay(), isFalse);
      expect(p.answeredToday, 3);
      expect(p.streak, 2);
    });

    test('al cambiar de día reinicia el contador y guarda la fecha nueva', () async {
      final p = await givenProgress(lastPlayed: DateTime(2026, 10, 29, 22), answeredToday: 3);

      expect(service().rolloverIfNewDay(), isTrue);
      expect(p.answeredToday, 0);
      expect(p.lastPlayedDate, now);
    });

    test('con la meta de ayer cumplida, el quiz de hoy no queda bloqueado', () async {
      // Es el bug original: answeredToday seguía en 5/5 al día siguiente y la
      // pantalla mostraba "Meta diaria cumplida" antes de poder responder.
      final p = await givenProgress(lastPlayed: DateTime(2026, 10, 29, 20), answeredToday: 5, dailyGoal: 5);

      service().rolloverIfNewDay();

      expect(p.answeredToday < p.dailyGoal, isTrue);
    });

    test('racha consecutiva: si ayer cumplió la meta, suma un día', () async {
      final p = await givenProgress(lastPlayed: DateTime(2026, 10, 29, 23, 59), answeredToday: 5, streak: 4);

      service().rolloverIfNewDay();

      expect(p.streak, 5);
    });

    test('racha consecutiva entre meses y entre años', () async {
      now = DateTime(2026, 11, 1, 0, 5);
      final p = await givenProgress(lastPlayed: DateTime(2026, 10, 31, 23), answeredToday: 5, streak: 1);
      service().rolloverIfNewDay();
      expect(p.streak, 2);

      now = DateTime(2027, 1, 1, 8);
      p
        ..lastPlayedDate = DateTime(2026, 12, 31, 21)
        ..answeredToday = 5;
      service().rolloverIfNewDay();
      expect(p.streak, 3);
    });

    test('racha rota: si ayer no llegó a la meta, vuelve a 0', () async {
      final p = await givenProgress(lastPlayed: DateTime(2026, 10, 29, 18), answeredToday: 4, streak: 7);

      service().rolloverIfNewDay();

      expect(p.streak, 0);
    });

    test('racha rota: si pasó más de un día sin jugar, vuelve a 0', () async {
      final p = await givenProgress(lastPlayed: DateTime(2026, 10, 28, 18), answeredToday: 5, streak: 7);

      service().rolloverIfNewDay();

      expect(p.streak, 0);
    });
  });

  group('incrementProgress', () {
    test('meta cumplida: suma respuestas hasta llegar a la meta del día', () async {
      final p = await givenProgress(lastPlayed: DateTime(2026, 10, 30, 8), dailyGoal: 3, streak: 1);
      final s = service();

      for (var i = 0; i < 3; i++) {
        s.incrementProgress(true);
      }

      expect(p.answeredToday, 3);
      expect(p.answeredToday >= p.dailyGoal, isTrue);
      expect(p.streak, 1);
    });

    test('en un día nuevo hace el reinicio antes de sumar', () async {
      final p = await givenProgress(lastPlayed: DateTime(2026, 10, 29, 20), answeredToday: 5, streak: 2);

      service().incrementProgress(true);

      expect(p.answeredToday, 1);
      expect(p.streak, 3);
    });

    test('la primera respuesta con la racha cortada arranca una racha nueva', () async {
      final p = await givenProgress(lastPlayed: DateTime(2000, 1, 1));

      service().incrementProgress(false);

      expect(p.streak, 1);
      expect(p.answeredToday, 1);
      expect(p.lastPlayedDate, now);
    });

    test('registra aciertos y respuestas en el historial del día', () async {
      await givenProgress(lastPlayed: DateTime(2026, 10, 30, 8));
      final s = service();

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
      service().incrementProgress(true);

      now = DateTime(2026, 10, 31, 10);
      service().incrementProgress(false);

      expect(statsBox.length, 2);
      expect(statsBox.getAt(1)!.correctAnswers, 0);
    });
  });
}
