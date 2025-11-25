import 'dart:convert';
import 'dart:io';
import 'package:hive/hive.dart';
import '../models/question.dart';

class ImportService {
  static Future<int> importQuestions(File file) async {
    final box = Hive.box<Question>('questionsBox');

    final content = await file.readAsString();
    final List<dynamic> jsonList = jsonDecode(content);

    int imported = 0;

    for (var item in jsonList) {
      // Evitar preguntas duplicadas por ID
      final exists = box.values.any((q) => q.id == item['id']);
      if (exists) continue;

      final q = Question(
        id: item['id'],
        questionText: item['text'],
        options: List<String>.from(item['options']),
        correctAnswerIndex: item['correct'],
        category: item['category'],
        createdAt: DateTime.parse(item['createdAt']),
        imagePath: item['imagePath'],
        // 👇 LEEMOS LOS NUEVOS CAMPOS (con seguridad para archivos viejos)
        explanation: item['explanation'],
        errorCount: item['errorCount'] ?? 0,
        totalAttempts: item['totalAttempts'] ?? 0,
      );

      await box.add(q);
      imported++;
    }

    return imported;
  }
}