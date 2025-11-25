import 'package:hive/hive.dart';
import '../models/user_progress.dart';
import '../models/daily_stats.dart'; // 👈 Importamos el nuevo modelo

class ProgressService {
  final Box<UserProgress> _progressBox = Hive.box<UserProgress>('progressBox');
  final Box<DailyStats> _statsBox = Hive.box<DailyStats>('statsBox');

  UserProgress get progress => _progressBox.getAt(0)!;

  /// Llamar cada vez que el usuario responde una pregunta
  void incrementProgress(bool isCorrect) { // 👈 Ahora recibimos si acertó o no
    final today = DateTime.now();
    final p = progress;

    // --- 1. LÓGICA DE RACHA Y PROGRESO GENERAL ---

    // Si es la primera vez histórica
    if (p.lastPlayedDate.year < 2020) {
      p.lastPlayedDate = today;
      p.streak = 1;
      p.answeredToday = 1;
      p.save();
      _updateDailyStats(today, isCorrect); // Guardar en historial
      return;
    }

    // Si es un nuevo día
    if (!_isSameDay(today, p.lastPlayedDate)) {
      final wasConsecutive = _isYesterday(p.lastPlayedDate, today);

      // Si jugó ayer y cumplió meta, suma racha. Si no, a cero.
      if (wasConsecutive && p.answeredToday >= p.dailyGoal) {
        p.streak += 1;
      } else {
        // Opcional: Podrías ser buena onda y no resetear si solo faltó un día,
        // pero la lógica estricta es resetear.
        p.streak = 0;
      }

      p.answeredToday = 0;
      p.lastPlayedDate = today;
    }

    // Recuperar racha si estaba en 0 y empieza hoy
    if (p.streak == 0 && p.answeredToday == 0) {
      p.streak = 1;
    }

    p.answeredToday += 1;
    p.save();

    // --- 2. ACTUALIZAR HISTORIAL DE ESTADÍSTICAS ---
    _updateDailyStats(today, isCorrect);
  }

  // 👇 Función auxiliar para guardar el historial diario
  void _updateDailyStats(DateTime date, bool isCorrect) {
    // Normalizamos la fecha (solo año, mes, día) para usarla de ID/Key
    final dateKey = DateTime(date.year, date.month, date.day).toString();

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

  bool _isYesterday(DateTime last, DateTime now) {
    final diff = now.difference(DateTime(last.year, last.month, last.day)).inDays;
    return diff == 1;
  }
}