import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import '../models/daily_stats.dart';
import '../models/question.dart';
import '../models/user_progress.dart';

/// Nombres de las cajas de Hive.
abstract final class HiveBoxes {
  static const questions = 'questionsBox';
  static const progress = 'progressBox';
  static const stats = 'statsBox';
}

class StorageService {
  /// Abre las cajas de Hive. Si alguna falla no se borra nada: se devuelve
  /// el error de cada caja para que el usuario decida qué hacer.
  static Future<Map<String, Object>> openBoxes() async {
    final failures = <String, Object>{};

    Future<void> tryOpen(String name, Future<void> Function() open) async {
      try {
        await open();
      } catch (e) {
        debugPrint('No se pudo abrir la caja $name: $e');
        failures[name] = e;
      }
    }

    await tryOpen(HiveBoxes.questions, () => Hive.openBox<Question>(HiveBoxes.questions));
    await tryOpen(HiveBoxes.progress, () => Hive.openBox<UserProgress>(HiveBoxes.progress));
    await tryOpen(HiveBoxes.stats, () => Hive.openBox<DailyStats>(HiveBoxes.stats));
    return failures;
  }

  /// Copia los archivos de las cajas indicadas a una carpeta de respaldo y
  /// recién después las borra. Devuelve la ruta del respaldo.
  static Future<String> backupAndDelete(Iterable<String> boxNames) async {
    final docs = await getApplicationDocumentsDirectory();
    final stamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final backupDir = await Directory('${docs.path}/hive_backup_$stamp').create(recursive: true);

    for (final name in boxNames) {
      // Hive guarda cada caja como <nombre en minúsculas>.hive en la carpeta
      // de documentos (la que usa Hive.initFlutter).
      final fileName = '${name.toLowerCase()}.hive';
      final file = File('${docs.path}/$fileName');
      if (await file.exists()) {
        await file.copy('${backupDir.path}/$fileName');
      }
      await Hive.deleteBoxFromDisk(name);
    }
    return backupDir.path;
  }
}
