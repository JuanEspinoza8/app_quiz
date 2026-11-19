import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../models/user_progress.dart';
import '../models/daily_stats.dart';

/// Meta diaria con la que arranca la app (y la que se usa si falta el dato).
const kDefaultDailyGoal = 5;

/// Meta diaria máxima que se puede configurar.
const kMaxDailyGoal = 50;

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

  /// Crea el progreso inicial si la caja está vacía (primera ejecución) y
  /// adapta los datos guardados por versiones anteriores.
  Future<void> ensureInitialized() async {
    if (_progressBox.isNotEmpty) {
      await _migrateLegacyStreak();
      return;
    }
    await _progressBox.add(UserProgress(
      dailyGoal: kDefaultDailyGoal,
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

  /// Las versiones anteriores no guardaban el día en que se cumplió la meta y
  /// contaban el día de hoy por adelantado: una racha de N sin la meta de hoy
  /// cumplida eran N - 1 días cumplidos hasta ayer.
  Future<void> _migrateLegacyStreak() async {
    final p = progress;
    if (p.lastGoalMetDate != null || p.streak == 0) return;
    final day = DateTime(p.lastPlayedDate.year, p.lastPlayedDate.month, p.lastPlayedDate.day);
    if (p.answeredToday >= p.dailyGoal) {
      p.lastGoalMetDate = day;
    } else {
      p.streak -= 1;
      p.lastGoalMetDate = p.streak > 0 ? DateTime(day.year, day.month, day.day - 1) : null;
    }
    if (p.streak > p.bestStreak) p.bestStreak = p.streak;
    await p.save();
  }

  // ---------------------------------------------------------------------------
  // Día, racha y respuestas
  // ---------------------------------------------------------------------------

  /// Si cambió el día desde la última vez, reinicia el contador diario y
  /// corta la racha si ayer no se cumplió la meta. Se llama al iniciar la
  /// app, al volver a ella, al abrir el quiz y antes de sumar una respuesta.
  /// Devuelve true si hubo cambio de día.
  bool rolloverIfNewDay() {
    final today = _now();
    final p = progress;
    if (_isSameDay(today, p.lastPlayedDate)) return false;

    if (!_streakIsAlive(p, today)) p.streak = 0;
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

    p.answeredToday += 1;
    _countGoalIfMet(p, today);
    p.save();

    _updateDailyStats(today, isCorrect);
  }

  /// La racha sigue viva si la última meta cumplida fue hoy o ayer.
  bool _streakIsAlive(UserProgress p, DateTime today) {
    final met = p.lastGoalMetDate;
    return met != null && (_isSameDay(met, today) || _isYesterday(met, today));
  }

  /// La primera vez en el día que se llega a la meta, la racha suma un día
  /// (o arranca en 1 si venía cortada).
  void _countGoalIfMet(UserProgress p, DateTime today) {
    if (p.answeredToday < p.dailyGoal) return;
    final met = p.lastGoalMetDate;
    if (met != null && _isSameDay(met, today)) return;

    p.streak = met != null && _isYesterday(met, today) ? p.streak + 1 : 1;
    p.lastGoalMetDate = DateTime(today.year, today.month, today.day);
    if (p.streak > p.bestStreak) p.bestStreak = p.streak;
  }

  // ---------------------------------------------------------------------------
  // Modo examen
  // ---------------------------------------------------------------------------

  /// Si la fecha del modo examen ya pasó.
  bool get isExamExpired {
    final date = progress.targetDate;
    if (date == null) return false;
    final today = _now();
    return DateTime(date.year, date.month, date.day).isBefore(DateTime(today.year, today.month, today.day));
  }

  /// La materia del modo examen si está activo: hay una elegida y, si tiene
  /// fecha, todavía no pasó (el mismo día del examen sigue activo).
  String? get activeExamCategory => isExamExpired ? null : progress.targetCategory;

  // ---------------------------------------------------------------------------
  // Preferencias
  // ---------------------------------------------------------------------------

  Future<void> completeOnboarding({required String userName, required int dailyGoal}) {
    progress
      ..userName = userName
      ..dailyGoal = dailyGoal;
    return progress.save();
  }

  /// Guarda la meta diaria (entre 1 y [kMaxDailyGoal]: con 0 el quiz quedaría
  /// siempre en "Meta diaria cumplida") y el modo examen. Si la meta nueva ya
  /// está cumplida con lo respondido hoy, el día cuenta para la racha.
  Future<void> updateGoals({required int dailyGoal, String? targetCategory, DateTime? targetDate}) {
    final today = _now();
    rolloverIfNewDay();
    final p = progress
      ..dailyGoal = dailyGoal.clamp(1, kMaxDailyGoal)
      ..targetCategory = targetCategory
      ..targetDate = targetDate;
    _countGoalIfMet(p, today);
    return p.save();
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

  /// Aplica los datos de progreso de un respaldo. Lo que no viene (o viene
  /// fuera de rango) queda como estaba. answeredToday no viaja en el
  /// respaldo: con la última fecha jugada, rolloverIfNewDay decide si la
  /// racha sigue o se corta.
  Future<void> restoreFromBackup({
    int? dailyGoal,
    int? streak,
    int? bestStreak,
    int? notificationHour,
    int? notificationMinute,
    DateTime? lastPlayed,
    DateTime? lastGoalMet,
  }) {
    final p = progress;
    // Con meta 0 el quiz quedaría siempre en "Meta diaria cumplida".
    if (dailyGoal != null) p.dailyGoal = dailyGoal.clamp(1, kMaxDailyGoal);
    if (notificationHour != null && notificationHour >= 0 && notificationHour <= 23) {
      p.notificationHour = notificationHour;
    }
    if (notificationMinute != null && notificationMinute >= 0 && notificationMinute <= 59) {
      p.notificationMinute = notificationMinute;
    }
    if (lastPlayed != null) p.lastPlayedDate = lastPlayed;
    if (streak != null && streak >= 0) {
      p.streak = streak;
      // Los respaldos viejos no traen el día de la última meta cumplida: se
      // toma el último día jugado.
      p.lastGoalMetDate = streak == 0 ? null : (lastGoalMet ?? lastPlayed ?? p.lastGoalMetDate);
    }
    final best = [p.bestStreak, p.streak, if (bestStreak != null) bestStreak].reduce((a, b) => a > b ? a : b);
    p.bestStreak = best;
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
