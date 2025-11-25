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

  @HiveField(6)
  String? imagePath;

  // 👇 NUEVOS CAMPOS PARA FASE 2.0
  @HiveField(7)
  String? explanation; // Explicación de la respuesta correcta

  @HiveField(8)
  int errorCount;      // Veces que se equivocó (para Repaso Inteligente)

  @HiveField(9)
  int totalAttempts;   // Veces totales que la respondió (para Estadísticas)

  Question({
    required this.id,
    required this.questionText,
    required this.options,
    required this.correctAnswerIndex,
    required this.category,
    required this.createdAt,
    this.imagePath,
    this.explanation,
    this.errorCount = 0,
    this.totalAttempts = 0,
  });

  // Para JSON (Exportar)
  Map<String, dynamic> toJson() => {
    'id': id,
    'questionText': questionText,
    'options': options,
    'correctAnswerIndex': correctAnswerIndex,
    'category': category,
    'createdAt': createdAt.toIso8601String(),
    'imagePath': imagePath,
    'explanation': explanation,
    'errorCount': errorCount,
    'totalAttempts': totalAttempts,
  };

  // Para JSON (Importar)
  factory Question.fromJson(Map<String, dynamic> json) => Question(
    id: json['id'] as String,
    questionText: json['questionText'] as String,
    options: (json['options'] as List).map((e) => e.toString()).toList(),
    correctAnswerIndex: json['correctAnswerIndex'] as int,
    category: json['category'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    imagePath: json['imagePath'] as String?,
    explanation: json['explanation'] as String?,
    errorCount: json['errorCount'] ?? 0,
    totalAttempts: json['totalAttempts'] ?? 0,
  );
}