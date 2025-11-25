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
      });
    }

    final jsonString = jsonEncode(data);

    final dir = await getTemporaryDirectory();
    final file = File("${dir.path}/preguntas_export.json");

    await file.writeAsString(jsonString);

    return file.path;
  }
}
