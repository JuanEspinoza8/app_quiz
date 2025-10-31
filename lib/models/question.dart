import 'package:hive/hive.dart';

part 'question.g.dart';

@HiveType(typeId: 0)
class Question extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String questionText;

  @HiveField(2)
  List<String> options;

  @HiveField(3)
  int correctAnswerIndex;

  @HiveField(4)
  String category;

  @HiveField(5)
  DateTime createdAt;

  Question({
    required this.id,
    required this.questionText,
    required this.options,
    required this.correctAnswerIndex,
    required this.category,
    required this.createdAt,
  });
}
