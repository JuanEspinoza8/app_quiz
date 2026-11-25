import 'dart:math';

/// Orden en que se muestran las imágenes: order[fila] = índice de la imagen
/// en Question.matchImages. Con 2 o más parejas nunca devuelve el orden
/// original, para que la respuesta no sean líneas rectas.
List<int> shuffledOrder(int n, Random random) {
  final order = List.generate(n, (i) => i);
  if (n < 2) return order;
  do {
    order.shuffle(random);
  } while (_isIdentity(order));
  return order;
}

bool _isIdentity(List<int> order) {
  for (var i = 0; i < order.length; i++) {
    if (order[i] != i) return false;
  }
  return true;
}

/// Las conexiones que va armando el usuario: elemento de la izquierda →
/// imagen. Los dos lados se identifican por su índice en la pregunta (no por
/// la posición en pantalla), así que la corrección no depende de la mezcla.
///
/// Reglas: cada elemento tiene a lo sumo una imagen y cada imagen recibe a lo
/// sumo una línea.
class MatchingAnswer {
  final int pairCount;
  final Map<int, int> _imageByLeft = {};

  MatchingAnswer(this.pairCount);

  Map<int, int> get connections => Map.unmodifiable(_imageByLeft);
  bool get isEmpty => _imageByLeft.isEmpty;
  bool get isComplete => _imageByLeft.length == pairCount;

  int? imageFor(int left) => _imageByLeft[left];

  int? leftFor(int image) {
    for (final entry in _imageByLeft.entries) {
      if (entry.value == image) return entry.key;
    }
    return null;
  }

  /// Une [left] con [image]. Si la imagen ya tenía otra línea, se la saca; si
  /// el elemento ya tenía otra imagen, se reemplaza.
  void connect(int left, int image) {
    _imageByLeft.removeWhere((l, img) => img == image && l != left);
    _imageByLeft[left] = image;
  }

  void disconnect(int left) => _imageByLeft.remove(left);

  void disconnectImage(int image) => _imageByLeft.removeWhere((_, img) => img == image);

  void clear() => _imageByLeft.clear();

  /// Para cada elemento, si quedó unido a su imagen (la del mismo índice).
  List<bool> grade() => [for (var i = 0; i < pairCount; i++) _imageByLeft[i] == i];

  bool get allCorrect => grade().every((correct) => correct);
}
