import 'dart:convert';
import 'dart:io';
import 'package:hive/hive.dart';
import '../models/question.dart';
import '../models/user_progress.dart';
import '../models/daily_stats.dart';

class ImportService {
  static Future<String> importBackup(File file) async {
    final content = await file.readAsString();
    dynamic jsonData = jsonDecode(content);

    final qBox = Hive.box<Question>('questionsBox');
    final pBox = Hive.box<UserProgress>('progressBox');
    final sBox = Hive.box<DailyStats>('statsBox');

    int questionsAdded = 0;

    // Detectamos si es un Backup Completo (Map) o solo preguntas viejas (List)
    List<dynamic> questionsList = [];
    Map<String, dynamic>? progressMap;
    List<dynamic>? statsList;

    if (jsonData is List) {
      // Formato viejo (solo preguntas)
      questionsList = jsonData;
    } else {
      // Formato nuevo (Backup completo)
      questionsList = jsonData['questions'] ?? [];
      progressMap = jsonData['progress'];
      statsList = jsonData['stats'];
    }

    // 1. IMPORTAR PREGUNTAS
    for (var item in questionsList) {
      // Evitamos duplicados por ID
      if (qBox.values.any((q) => q.id == item['id'])) continue;

      final q = Question(
        id: item['id'],
        questionText: item['text'] ?? item['questionText'], // Compatibilidad
        options: List<String>.from(item['options']),
        correctAnswerIndex: item['correct'] ?? item['correctAnswerIndex'],
        category: item['category'],
        createdAt: DateTime.tryParse(item['createdAt'] ?? '') ?? DateTime.now(),
        imagePath: item['imagePath'],
        explanation: item['explanation'],
        errorCount: item['errorCount'] ?? 0,
        totalAttempts: item['totalAttempts'] ?? 0,
      );
      await qBox.add(q);
      questionsAdded++;
    }

    // 2. IMPORTAR PROGRESO (Si existe en el archivo)
    if (progressMap != null) {
      final p = pBox.getAt(0)!;
      // Solo restauramos la racha y configuración, NO sobreescribimos la fecha de hoy
      p.dailyGoal = progressMap['dailyGoal'] ?? 3;
      p.streak = progressMap['streak'] ?? 0;
      p.notificationHour = progressMap['notifHour'] ?? 18;
      p.notificationMinute = progressMap['notifMinute'] ?? 0;

      // Opcional: Restaurar última fecha jugada
      if (progressMap['lastPlayed'] != null) {
        p.lastPlayedDate = DateTime.parse(progressMap['lastPlayed']);
      }
      await p.save();
    }

    // 3. IMPORTAR ESTADÍSTICAS (Si existen)
    if (statsList != null) {
      // Limpiamos las stats actuales para no duplicar gráficos
      await sBox.clear();
      for (var item in statsList) {
        final s = DailyStats(
          date: DateTime.parse(item['date']),
          questionsAnswered: item['answered'],
          correctAnswers: item['correct'],
        );
        await sBox.add(s);
      }
    }

    return "Se restauraron $questionsAdded preguntas y tu historial 📈";
  }
}