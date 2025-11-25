import 'package:hive/hive.dart';

part 'daily_stats.g.dart';

@HiveType(typeId: 2) // Usamos ID 2 porque el 0 es Question y el 1 es UserProgress
class DailyStats extends HiveObject {
  @HiveField(0)
  DateTime date; // El día (sin hora, solo fecha)

  @HiveField(1)
  int questionsAnswered; // Total respondidas ese día

  @HiveField(2)
  int correctAnswers; // Total acertadas ese día

  DailyStats({
    required this.date,
    required this.questionsAnswered,
    required this.correctAnswers,
  });
}