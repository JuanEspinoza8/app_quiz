import 'package:hive/hive.dart';

part 'user_progress.g.dart';

@HiveType(typeId: 1)
class UserProgress extends HiveObject {
  @HiveField(0)
  int dailyGoal;

  @HiveField(1)
  int answeredToday;

  @HiveField(2)
  int streak;

  @HiveField(3)
  DateTime lastPlayedDate;

  @HiveField(4)
  String? targetCategory;

  @HiveField(5)
  DateTime? targetDate;

  // 👇 ESTOS SON LOS CAMPOS QUE FALTABAN
  @HiveField(6, defaultValue: 18)
  int notificationHour;

  @HiveField(7, defaultValue: 0)
  int notificationMinute;

  UserProgress({
    required this.dailyGoal,
    required this.answeredToday,
    required this.streak,
    required this.lastPlayedDate,
    this.targetCategory,
    this.targetDate,
    this.notificationHour = 18, // Valor por defecto (6 PM)
    this.notificationMinute = 0,
  });
}
