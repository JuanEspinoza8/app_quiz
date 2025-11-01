import 'package:hive/hive.dart';
import '../models/user_progress.dart';

class ProgressService {
  final Box<UserProgress> _box = Hive.box<UserProgress>('progressBox');

  UserProgress get progress => _box.getAt(0)!;

  /// Llamar cada vez que el usuario responde una pregunta
  void incrementProgress() {
    final today = DateTime.now();
    final p = progress;

    // 📌 Si es la primera vez que juega
    if (p.lastPlayedDate.year < 2020) {
      p.lastPlayedDate = today;
      p.streak = 1;
      p.answeredToday = 1;
      p.save();
      return;
    }

    // 📅 Si es un nuevo día
    if (!_isSameDay(today, p.lastPlayedDate)) {
      final wasConsecutive = _isYesterday(p.lastPlayedDate, today);

      // 🔥 Si jugó ayer y cumplió la meta, suma la racha
      if (wasConsecutive && p.answeredToday >= p.dailyGoal) {
        p.streak += 1;
      } else {
        p.streak = 0; // perdió la racha
      }

      // Reinicia el contador diario
      p.answeredToday = 0;
      p.lastPlayedDate = today;
    }

    // 💡 Si arranca de nuevo una racha después de perderla
    if (p.streak == 0 && p.answeredToday == 0) {
      p.streak = 1;
    }

    // ➕ Suma una respuesta
    p.answeredToday += 1;

    // 💾 Guarda cambios
    p.save();
  }

  // ✅ Lógica auxiliar
  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _isYesterday(DateTime last, DateTime now) {
    final diff = now
        .difference(DateTime(last.year, last.month, last.day))
        .inDays;
    return diff == 1;
  }
}
