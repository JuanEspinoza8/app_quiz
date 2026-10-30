import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../models/user_progress.dart';
import '../models/daily_stats.dart';

/// Progreso del usuario (meta, racha, preferencias) y el historial diario.
/// Concentra la lógica de cambio de día y racha, y avisa a la UI cuando
/// cambia cualquiera de las dos cajas.
class ProgressRepository extends ChangeNotifier {
  final Box<UserProgress> _progressBox;
  final Box<DailyStats> _statsBox;
  final DateTime Function() _now;
  late final List<StreamSubscription<BoxEvent>> _subscriptions;

  /// [now] permite fijar la fecha en los tests; por defecto es el reloj del sistema.
  ProgressRepository(this._progressBox, this._statsBox, {DateTime Function()? now})
      : _now = now ?? DateTime.now {
    _subscriptions = [
      _progressBox.watch().listen((_) => notifyListeners()),
      _statsBox.watch().listen((_) => notifyListeners()),
    ];
  }

  UserProgress get progress => _progressBox.getAt(0)!;

  /// Crea el progreso inicial si la caja está vacía (primera ejecución).
  Future<void> ensureInitialized() async {
    if (_progressBox.isNotEmpty) return;
    await _progressBox.add(UserProgress(
      dailyGoal: 5,
      answeredToday: 0,
      streak: 0,
      lastPlayedDate: DateTime(2000, 1, 1),
      notificationHour: 18,
      notificationMinute: 0,
      isDarkMode: false,
      userName: '',
      hiddenCategories: [],
    ));
  }

  // ---------------------------------------------------------------------------
  // Día, racha y respuestas
  // ---------------------------------------------------------------------------

  /// Si cambió el día desde la última vez, actualiza la racha y reinicia el
  /// contador diario. Se llama al iniciar la app, al volver a ella, al abrir
  /// el quiz y antes de sumar una respuesta. Devuelve true si hubo cambio de día.
  bool rolloverIfNewDay() {
    final today = _now();
    final p = progress;
    if (_isSameDay(today, p.lastPlayedDate)) return false;

    // La racha sigue solo si el último día jugado fue ayer y se cumplió la meta.
    if (_isYesterday(p.lastPlayedDate, today) && p.answeredToday >= p.dailyGoal) {
      p.streak += 1;
    } else {
      p.streak = 0;
    }

    p.answeredToday = 0;
    p.lastPlayedDate = today;
    p.save();
    return true;
  }

  /// Llamar cada vez que el usuario responde una pregunta
  void incrementProgress(bool isCorrect) {
    final today = _now();
    rolloverIfNewDay();
    final p = progress;

    // Primera respuesta del día con la racha cortada: empieza una nueva.
    if (p.streak == 0 && p.answeredToday == 0) {
      p.streak = 1;
    }

    p.answeredToday += 1;
    p.save();

    _updateDailyStats(today, isCorrect);
  }

  // ---------------------------------------------------------------------------
  // Preferencias
  // ---------------------------------------------------------------------------

  Future<void> completeOnboarding({required String userName, required int dailyGoal}) {
    progress
      ..userName = userName
      ..dailyGoal = dailyGoal;
    return progress.save();
  }

  /// Guarda la meta diaria (mínimo 1: con 0 el quiz quedaría siempre en
  /// "Meta diaria cumplida") y el modo examen.
  Future<void> updateGoals({required int dailyGoal, String? targetCategory, DateTime? targetDate}) {
    progress
      ..dailyGoal = dailyGoal < 1 ? 1 : dailyGoal
      ..targetCategory = targetCategory
      ..targetDate = targetDate;
    return progress.save();
  }

  Future<void> setDarkMode(bool enabled) {
    progress.isDarkMode = enabled;
    return progress.save();
  }

  Future<void> setReminderTime(int hour, int minute) {
    progress
      ..notificationHour = hour
      ..notificationMinute = minute;
    return progress.save();
  }

  /// Activa o desactiva una materia para el quiz diario.
  Future<void> setCategoryHidden(String category, bool hidden) {
    final p = progress;
    // Se crea una lista nueva: la que trae el modelo por defecto es constante.
    p.hiddenCategories = hidden
        ? {...p.hiddenCategories, category}.toList()
        : p.hiddenCategories.where((c) => c != category).toList();
    return p.save();
  }

  /// Aplica los datos de progreso de un respaldo. answeredToday no viaja en
  /// el respaldo: con la última fecha jugada, rolloverIfNewDay decide si la
  /// racha sigue o se corta.
  Future<void> restoreFromBackup({
    required int dailyGoal,
    required int streak,
    required int notificationHour,
    required int notificationMinute,
    DateTime? lastPlayed,
  }) {
    final p = progress
      ..dailyGoal = dailyGoal
      ..streak = streak
      ..notificationHour = notificationHour
      ..notificationMinute = notificationMinute;
    if (lastPlayed != null) p.lastPlayedDate = lastPlayed;
    return p.save();
  }

  // ---------------------------------------------------------------------------
  // Historial diario
  // ---------------------------------------------------------------------------

  List<DailyStats> get dailyStats => _statsBox.values.toList();

  DailyStats? statsFor(DateTime day) {
    for (final s in _statsBox.values) {
      if (_isSameDay(s.date, day)) return s;
    }
    return null;
  }

  /// Respondidas y acertadas en todo el historial.
  ({int answered, int correct}) get totals {
    var answered = 0;
    var correct = 0;
    for (final s in _statsBox.values) {
      answered += s.questionsAnswered;
      correct += s.correctAnswers;
    }
    return (answered: answered, correct: correct);
  }

  /// Reemplaza todo el historial (lo usa la restauración de un respaldo para
  /// no duplicar días).
  Future<void> replaceDailyStats(Iterable<DailyStats> stats) async {
    await _statsBox.clear();
    await _statsBox.addAll(stats);
  }

  /// Suma la respuesta al historial del día (una entrada de DailyStats por día).
  void _updateDailyStats(DateTime date, bool isCorrect) {
    final todaysStats = statsFor(date);
    if (todaysStats != null) {
      todaysStats.questionsAnswered += 1;
      if (isCorrect) todaysStats.correctAnswers += 1;
      todaysStats.save();
    } else {
      _statsBox.add(DailyStats(
        date: date,
        questionsAnswered: 1,
        correctAnswers: isCorrect ? 1 : 0,
      ));
    }
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  // Compara días de calendario en UTC para que un cambio de horario de verano
  // no convierta "ayer" en una diferencia de 23 horas.
  bool _isYesterday(DateTime last, DateTime now) {
    final lastDay = DateTime.utc(last.year, last.month, last.day);
    final today = DateTime.utc(now.year, now.month, now.day);
    return today.difference(lastDay).inDays == 1;
  }

  @override
  void dispose() {
    for (final s in _subscriptions) {
      s.cancel();
    }
    super.dispose();
  }
}
