import '../models/question.dart';

/// Límites de una pregunta. Más de 6 parejas no entran bien en un celular.
const kMinOptions = 2;
const kMaxOptions = 6;
const kMinPairs = 2;
const kMaxPairs = 6;

/// Revisa que la pregunta se pueda jugar. Devuelve el primer problema, listo
/// para mostrarle al usuario, o null si está todo bien. La usan el editor,
/// la importación de respaldos y el generador con IA.
String? validateQuestion(Question q) {
  if (q.questionText.trim().isEmpty) return 'Falta el enunciado.';
  if (q.category.trim().isEmpty) return 'Falta la categoría.';

  return switch (q.type) {
    QuestionType.multipleChoice => _validateMultipleChoice(q),
    QuestionType.matching => _validateMatching(q),
    _ => 'Tipo de pregunta desconocido.',
  };
}

String? _validateMultipleChoice(Question q) {
  if (q.options.length < kMinOptions || q.options.length > kMaxOptions) {
    return 'Tiene que haber entre $kMinOptions y $kMaxOptions opciones.';
  }
  if (q.options.any((o) => o.trim().isEmpty)) {
    return 'Completá todas las opciones (o quitá las que sobran).';
  }
  if (q.correctAnswerIndex < 0 || q.correctAnswerIndex >= q.options.length) {
    return 'Marcá cuál es la opción correcta.';
  }
  return null;
}

String? _validateMatching(Question q) {
  final pairs = q.matchLeft.length;
  if (pairs != q.matchImages.length) {
    return 'Cada elemento tiene que tener su imagen.';
  }
  if (pairs < kMinPairs || pairs > kMaxPairs) {
    return 'Tiene que haber entre $kMinPairs y $kMaxPairs parejas.';
  }
  for (var i = 0; i < pairs; i++) {
    if (q.matchLeft[i].trim().isEmpty) return 'Falta el texto de la pareja ${i + 1}.';
    if (q.matchImages[i].trim().isEmpty) return 'Falta la imagen de la pareja ${i + 1}.';
  }

  final seenLeft = <String>{};
  for (final left in q.matchLeft) {
    if (!seenLeft.add(left.trim().toLowerCase())) {
      return 'Hay dos elementos iguales a la izquierda: "${left.trim()}".';
    }
  }
  if (q.matchImages.toSet().length != pairs) {
    return 'La misma imagen está en dos parejas.';
  }
  return null;
}
