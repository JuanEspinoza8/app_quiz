import 'package:hive/hive.dart';

part 'user_progress.g.dart';

@HiveType(typeId: 1)
class UserProgress extends HiveObject {
  @HiveField(0)
  int dailyGoal; // meta diaria de preguntas

  @HiveField(1)
  int answeredToday; // cuántas respondió hoy

  @HiveField(2)
  int streak; // días consecutivos con meta cumplida

  @HiveField(3)
  DateTime lastPlayedDate; // última fecha en que jugó

  // 👇 NUEVOS CAMPOS
  @HiveField(4)
  String? targetCategory; // Categoría que quiere estudiar

  @HiveField(5)
  DateTime? targetDate;   // Fecha límite (parcial)

  UserProgress({
    required this.dailyGoal,
    required this.answeredToday,
    required this.streak,
    required this.lastPlayedDate,
    this.targetCategory,
    this.targetDate,
  });
}