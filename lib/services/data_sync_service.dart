import 'dart:convert';
import 'dart:io';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import '../models/question.dart';
import '../models/user_progress.dart';
import '../models/daily_stats.dart';

class DataSyncService {
  static Future<String> exportFullBackup() async {
    final qBox = Hive.box<Question>('questionsBox');
    final pBox = Hive.box<UserProgress>('progressBox');
    final sBox = Hive.box<DailyStats>('statsBox');

    // 1. Exportar Preguntas
    final questionsData = qBox.values.map((q) => {
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
    }).toList();

    // 2. Exportar Progreso Usuario
    final p = pBox.getAt(0)!;
    final progressData = {
      "dailyGoal": p.dailyGoal,
      "streak": p.streak,
      "lastPlayed": p.lastPlayedDate.toIso8601String(),
      "notifHour": p.notificationHour,
      "notifMinute": p.notificationMinute,
      // No exportamos answeredToday para que no se tranque si restauras otro día
    };

    // 3. Exportar Estadísticas Diarias
    final statsData = sBox.values.map((s) => {
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