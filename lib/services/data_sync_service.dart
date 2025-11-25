import 'dart:convert';
import 'dart:io';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import '../models/question.dart';

class DataSyncService {
  static Future<String> exportQuestions() async {
    final box = Hive.box<Question>('questionsBox');
    final List<Map<String, dynamic>> data = [];

    for (var q in box.values) {
      data.add({
        "id": q.id,
        "text": q.questionText,
        "options": q.options,
        "correct": q.correctAnswerIndex,
        "category": q.category,
        "createdAt": q.createdAt.toIso8601String(),
        "imagePath": q.imagePath,
        // 👇 NUEVOS CAMPOS AGREGADOS
        "explanation": q.explanation,
        "errorCount": q.errorCount,
        "totalAttempts": q.totalAttempts,
      });
    }

    // Le damos formato bonito (indentado) para que sea legible si lo abres en PC
    final jsonString = const JsonEncoder.withIndent('  ').convert(data);

    final dir = await getTemporaryDirectory();
    final file = File("${dir.path}/preguntas_export.json");

    await file.writeAsString(jsonString);

    return file.path;
  }
}