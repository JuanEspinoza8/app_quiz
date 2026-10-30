import 'package:hive/hive.dart';
import '../models/user_progress.dart';
import '../models/daily_stats.dart';

class ProgressService {
  final Box<UserProgress> _progressBox = Hive.box<UserProgress>('progressBox');
  final Box<DailyStats> _statsBox = Hive.box<DailyStats>('statsBox');

  UserProgress get progress => _progressBox.getAt(0)!;

  /// Si cambió el día desde la última vez, actualiza la racha y reinicia el
  /// contador diario. Se llama al iniciar la app, al abrir el quiz y antes de
  /// sumar una respuesta. Devuelve true si hubo cambio de día.
  bool rolloverIfNewDay() {
    final today = DateTime.now();
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
    final today = DateTime.now();
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

  /// Suma la respuesta al historial del día (una entrada de DailyStats por día).
  void _updateDailyStats(DateTime date, bool isCorrect) {
    DailyStats? todaysStats;

    // Buscamos si ya existe entrada para hoy
    try {
      // Filtramos buscando la fecha (podría optimizarse usando la fecha como key directa)
      todaysStats = _statsBox.values.firstWhere(
            (s) => _isSameDay(s.date, date),
      );
    } catch (e) {
      // Si no encuentra nada, firstWhere lanza error, así que todaysStats queda null
      todaysStats = null;
    }

    if (todaysStats != null) {
      // Si ya existe, actualizamos
      todaysStats.questionsAnswered += 1;
      if (isCorrect) todaysStats.correctAnswers += 1;
      todaysStats.save();
    } else {
      // Si no existe (es la primera del día), creamos nueva
      final newStats = DailyStats(
        date: date,
        questionsAnswered: 1,
        correctAnswers: isCorrect ? 1 : 0,
      );
      _statsBox.add(newStats);
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
}