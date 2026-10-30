import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../data/progress_repository.dart';
import '../data/question_repository.dart';

class DataSyncService {
  static Future<String> exportFullBackup({
    required QuestionRepository questions,
    required ProgressRepository progress,
  }) async {
    // 1. Exportar Preguntas
    final questionsData = questions.all.map((q) => {
      "id": q.id,
      "text": q.questionText,
      "options": q.options,
      "correct": q.correctAnswerIndex,
      "category": q.category,
      "createdAt": q.createdAt.toIso8601String(),
      "imagePath": q.imagePath,
      "explanation": q.explanation,
      "errorCount": q.errorCount,
      "totalAttempts": q.totalAttempts,
      "correctCount": q.correctCount,
    }).toList();

    // 2. Exportar Progreso Usuario
    final p = progress.progress;
    final progressData = {
      "dailyGoal": p.dailyGoal,
      "streak": p.streak,
      "lastPlayed": p.lastPlayedDate.toIso8601String(),
      "notifHour": p.notificationHour,
      "notifMinute": p.notificationMinute,
      // answeredToday no se exporta: al restaurar otro día no tiene sentido
    };

    // 3. Exportar Estadísticas Diarias
    final statsData = progress.dailyStats.map((s) => {
      "date": s.date.toIso8601String(),
      "answered": s.questionsAnswered,
      "correct": s.correctAnswers,
    }).toList();

    // 📦 PAQUETE COMPLETO
    final fullBackup = {
      "version": 1,
      "questions": questionsData,
      "progress": progressData,
      "stats": statsData,
    };

    final jsonString = const JsonEncoder.withIndent('  ').convert(fullBackup);
    final dir = await getTemporaryDirectory();
    // Usamos la fecha en el nombre para saber de cuándo es
    final dateStr = DateTime.now().toString().split(' ')[0];
    final file = File("${dir.path}/QuizBackup_$dateStr.json");

    await file.writeAsString(jsonString);

    return file.path;
  }
}