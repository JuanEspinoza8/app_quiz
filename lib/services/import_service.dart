import 'dart:convert';
import 'dart:io';
import '../data/progress_repository.dart';
import '../data/question_repository.dart';
import '../models/question.dart';
import '../models/daily_stats.dart';

class ImportService {
  static Future<String> importBackup(
    File file, {
    required QuestionRepository questions,
    required ProgressRepository progress,
  }) async {
    final content = await file.readAsString();
    dynamic jsonData = jsonDecode(content);

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
      if (questions.containsId(item['id'])) continue;

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
        correctCount: item['correctCount'] ?? 0,
      );
      await questions.add(q);
      questionsAdded++;
    }

    // 2. IMPORTAR PROGRESO (Si existe en el archivo)
    if (progressMap != null) {
      final lastPlayed = progressMap['lastPlayed'];
      await progress.restoreFromBackup(
        dailyGoal: progressMap['dailyGoal'] ?? 3,
        streak: progressMap['streak'] ?? 0,
        notificationHour: progressMap['notifHour'] ?? 18,
        notificationMinute: progressMap['notifMinute'] ?? 0,
        lastPlayed: lastPlayed != null ? DateTime.parse(lastPlayed) : null,
      );
    }

    // 3. IMPORTAR ESTADÍSTICAS (Si existen): reemplazan a las actuales para
    // no duplicar días en los gráficos.
    if (statsList != null) {
      await progress.replaceDailyStats([
        for (var item in statsList)
          DailyStats(
            date: DateTime.parse(item['date']),
            questionsAnswered: item['answered'],
            correctAnswers: item['correct'],
          ),
      ]);
    }

    return "Se restauraron $questionsAdded preguntas y tu historial 📈";
  }
}
