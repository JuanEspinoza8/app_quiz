import 'package:hive/hive.dart';

part 'question.g.dart';

/// Tipos de pregunta. Se guardan como texto para que agregar uno nuevo no
/// cambie el significado de los que ya están guardados.
abstract final class QuestionType {
  /// Enunciado con opciones y una sola correcta.
  static const multipleChoice = 'multiple_choice';

  /// Elementos a la izquierda que se unen con imágenes a la derecha.
  static const matching = 'matching';
}

@HiveType(typeId: 0)
class Question extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String questionText;

  /// Opciones de una pregunta de opción múltiple. Vacía en las de relacionar.
  @HiveField(2)
  List<String> options;

  @HiveField(3)
  int correctAnswerIndex;

  @HiveField(4)
  String category;

  @HiveField(5)
  DateTime createdAt;

  /// Imagen opcional del enunciado: el nombre que devuelve ImageStore (o una
  /// ruta absoluta en las preguntas guardadas antes de que existiera).
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

  /// Uno de los valores de [QuestionType].
  @HiveField(11, defaultValue: QuestionType.multipleChoice)
  String type;

  /// Relacionar: los elementos de la izquierda (números, palabras, conceptos).
  @HiveField(12, defaultValue: [])
  List<String> matchLeft;

  /// Relacionar: la imagen que corresponde a cada elemento de [matchLeft].
  /// La pareja correcta es la del mismo índice; el orden mezclado existe solo
  /// en pantalla, así que mezclar nunca cambia las correspondencias.
  @HiveField(13, defaultValue: [])
  List<String> matchImages;

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
    this.type = QuestionType.multipleChoice,
    this.matchLeft = const [],
    this.matchImages = const [],
  });

  bool get isMatching => type == QuestionType.matching;

  /// Todas las imágenes que usa la pregunta.
  List<String> get imageRefs => [
        if (imagePath != null) imagePath!,
        ...matchImages,
      ];

  /// Copia con algunos campos cambiados. [imagePath] y [explanation] se pasan
  /// como funciones para poder ponerlos en null.
  Question copyWith({
    String? id,
    String? questionText,
    List<String>? options,
    int? correctAnswerIndex,
    String? category,
    DateTime? createdAt,
    String? Function()? imagePath,
    String? Function()? explanation,
    int? errorCount,
    int? totalAttempts,
    int? correctCount,
    String? type,
    List<String>? matchLeft,
    List<String>? matchImages,
  }) =>
      Question(
        id: id ?? this.id,
        questionText: questionText ?? this.questionText,
        options: options ?? this.options,
        correctAnswerIndex: correctAnswerIndex ?? this.correctAnswerIndex,
        category: category ?? this.category,
        createdAt: createdAt ?? this.createdAt,
        imagePath: imagePath != null ? imagePath() : this.imagePath,
        explanation: explanation != null ? explanation() : this.explanation,
        errorCount: errorCount ?? this.errorCount,
        totalAttempts: totalAttempts ?? this.totalAttempts,
        correctCount: correctCount ?? this.correctCount,
        type: type ?? this.type,
        matchLeft: matchLeft ?? this.matchLeft,
        matchImages: matchImages ?? this.matchImages,
      );

  /// Formato del respaldo (versión 2).
  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'questionText': questionText,
    'options': options,
    'correctAnswerIndex': correctAnswerIndex,
    'matchLeft': matchLeft,
    'matchImages': matchImages,
    'category': category,
    'createdAt': createdAt.toIso8601String(),
    'imagePath': imagePath,
    'explanation': explanation,
    'errorCount': errorCount,
    'totalAttempts': totalAttempts,
    'correctCount': correctCount,
  };

  /// Lee una pregunta de un respaldo. Acepta también las claves del respaldo
  /// de la versión 1 ("text" y "correct"). Lanza un error si falta un dato
  /// obligatorio o tiene otro tipo; quien importa decide qué hacer con eso.
  factory Question.fromJson(Map<String, dynamic> json) => Question(
    id: json['id'] as String,
    questionText: (json['questionText'] ?? json['text']) as String,
    options: [for (final o in (json['options'] as List? ?? const [])) o.toString()],
    correctAnswerIndex: (json['correctAnswerIndex'] ?? json['correct'] ?? 0) as int,
    category: json['category'] as String,
    createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    imagePath: json['imagePath'] as String?,
    explanation: json['explanation'] as String?,
    errorCount: json['errorCount'] as int? ?? 0,
    totalAttempts: json['totalAttempts'] as int? ?? 0,
    correctCount: json['correctCount'] as int? ?? 0,
    type: json['type'] as String? ?? QuestionType.multipleChoice,
    matchLeft: [for (final l in (json['matchLeft'] as List? ?? const [])) l.toString()],
    matchImages: [for (final i in (json['matchImages'] as List? ?? const [])) i.toString()],
  );
}
