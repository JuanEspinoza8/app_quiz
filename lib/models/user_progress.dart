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

  @HiveField(6, defaultValue: 18)
  int notificationHour;

  @HiveField(7, defaultValue: 0)
  int notificationMinute;

  @HiveField(8, defaultValue: false)
  bool isDarkMode;

  @HiveField(9, defaultValue: '')
  String userName; // Nombre del usuario

  @HiveField(10, defaultValue: [])
  List<String> hiddenCategories; // Categorías desactivadas

  /// Último día en que se cumplió la meta. La racha sigue mientras sea hoy o ayer.
  @HiveField(11)
  DateTime? lastGoalMetDate;

  /// La racha más larga alcanzada (los logros no se pierden si se corta).
  @HiveField(12, defaultValue: 0)
  int bestStreak;

  UserProgress({
    required this.dailyGoal,
    required this.answeredToday,
    required this.streak,
    required this.lastPlayedDate,
    this.targetCategory,
    this.targetDate,
    this.notificationHour = 18,
    this.notificationMinute = 0,
    this.isDarkMode = false,
    this.userName = '',
    this.hiddenCategories = const [],
    this.lastGoalMetDate,
    this.bestStreak = 0,
  });
}