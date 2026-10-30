import 'dart:io';

import 'package:hive/hive.dart';
import 'package:quiz_daily/models/daily_stats.dart';
import 'package:quiz_daily/models/question.dart';
import 'package:quiz_daily/models/user_progress.dart';
import 'package:quiz_daily/services/storage_service.dart';

/// Inicializa Hive en una carpeta temporal y abre las cajas de la app vacías.
Future<Directory> setUpTestHive() async {
  final dir = await Directory.systemTemp.createTemp('quiz_daily_test_');
  Hive.init(dir.path);
  if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(QuestionAdapter());
  if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(UserProgressAdapter());
  if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(DailyStatsAdapter());

  await Hive.openBox<Question>(HiveBoxes.questions);
  await Hive.openBox<UserProgress>(HiveBoxes.progress);
  await Hive.openBox<DailyStats>(HiveBoxes.stats);
  return dir;
}

/// Cierra y borra las cajas y la carpeta temporal.
Future<void> tearDownTestHive(Directory dir) async {
  await Hive.deleteFromDisk();
  if (await dir.exists()) await dir.delete(recursive: true);
}
