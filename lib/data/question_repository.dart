import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../models/question.dart';

/// Acceso a las preguntas guardadas. Las pantallas lo usan a través de
/// Provider y se redibujan cuando la caja cambia, venga de donde venga el
/// cambio (pantalla, importación de un respaldo, etc.).
class QuestionRepository extends ChangeNotifier {
  final Box<Question> _box;
  late final StreamSubscription<BoxEvent> _subscription;

  QuestionRepository(this._box) {
    _subscription = _box.watch().listen((_) => notifyListeners());
  }

  List<Question> get all => _box.values.toList();
  bool get isEmpty => _box.isEmpty;
  int get count => _box.length;

  /// Materias sin repetir, en el orden en que se cargaron.
  List<String> get categories => {for (final q in _box.values) q.category}.toList();

  bool containsId(String id) => _box.values.any((q) => q.id == id);

  Future<void> add(Question question) => _box.add(question);

  Future<void> addAll(Iterable<Question> questions) => _box.addAll(questions);

  /// Guarda [edited] en el lugar de [original], conservando el orden.
  Future<void> update(Question original, Question edited) {
    if (original.isInBox) return _box.put(original.key, edited);
    return _box.add(edited);
  }

  /// Borra la pregunta y devuelve la clave que tenía, para poder deshacer
  /// el borrado con [restore].
  Future<dynamic> delete(Question question) async {
    final key = question.key;
    await question.delete();
    return key;
  }

  /// Vuelve a guardar una pregunta borrada en su posición original.
  Future<void> restore(dynamic key, Question question) => _box.put(key, question);

  /// Registra una respuesta: suma el intento, el acierto y ajusta el peso del
  /// repaso inteligente (+1 al errar, -1 al acertar, nunca menos de 0).
  Future<void> recordAnswer(Question question, {required bool correct}) {
    question.totalAttempts++;
    if (correct) {
      question.correctCount++;
      if (question.errorCount > 0) question.errorCount--;
    } else {
      question.errorCount++;
    }
    return question.save();
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
