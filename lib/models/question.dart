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

  // Los campos agregados después de la primera versión llevan defaultValue
  // para que las preguntas guardadas antes se puedan seguir leyendo.
  @HiveField(7)
  String? explanation; // Explicación de la respuesta correcta

  @HiveField(8, defaultValue: 0)
  int errorCount;      // Peso para el repaso: +1 al errar, -1 al acertar

  @HiveField(9, defaultValue: 0)
  int totalAttempts;   // Veces totales que la respondió (para Estadísticas)

  @HiveField(10, defaultValue: 0)
  int correctCount;    // Veces que la acertó (para la precisión por materia)

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
    this.correctCount = 0,
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
    'correctCount': correctCount,
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
    correctCount: json['correctCount'] ?? 0,
  );
}