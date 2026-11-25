import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_daily/logic/question_validator.dart';
import 'package:quiz_daily/models/question.dart';

Question multipleChoice({
  String text = '¿Capital de Francia?',
  String category = 'Geografía',
  List<String> options = const ['París', 'Roma', 'Madrid', 'Lisboa'],
  int correct = 0,
}) =>
    Question(
      id: 'mc',
      questionText: text,
      options: options,
      correctAnswerIndex: correct,
      category: category,
      createdAt: DateTime(2026),
    );

Question matching({
  String text = 'Uní cada número con su imagen',
  List<String> left = const ['1', '2', '3'],
  List<String> images = const ['uno.png', 'dos.png', 'tres.png'],
}) =>
    Question(
      id: 'm',
      type: QuestionType.matching,
      questionText: text,
      options: const [],
      correctAnswerIndex: 0,
      category: 'Números',
      createdAt: DateTime(2026),
      matchLeft: left,
      matchImages: images,
    );

void main() {
  group('comunes', () {
    test('una pregunta completa es válida', () {
      expect(validateQuestion(multipleChoice()), isNull);
      expect(validateQuestion(matching()), isNull);
    });

    test('pide enunciado y categoría (los espacios no cuentan)', () {
      expect(validateQuestion(multipleChoice(text: '   ')), 'Falta el enunciado.');
      expect(validateQuestion(multipleChoice(category: ' ')), 'Falta la categoría.');
    });

    test('rechaza un tipo desconocido', () {
      expect(validateQuestion(multipleChoice()..type = 'otro'), 'Tipo de pregunta desconocido.');
    });
  });

  group('opción múltiple', () {
    test('entre 2 y 6 opciones', () {
      expect(validateQuestion(multipleChoice(options: ['Sí'])), contains('entre 2 y 6'));
      expect(validateQuestion(multipleChoice(options: ['Sí', 'No'])), isNull);
      expect(validateQuestion(multipleChoice(options: List.generate(7, (i) => '$i'))), contains('entre 2 y 6'));
    });

    test('no acepta opciones vacías', () {
      expect(validateQuestion(multipleChoice(options: ['París', '  ', 'Madrid'])), contains('Completá todas las opciones'));
    });

    test('la correcta tiene que estar dentro de las opciones', () {
      expect(validateQuestion(multipleChoice(correct: 4)), 'Marcá cuál es la opción correcta.');
      expect(validateQuestion(multipleChoice(correct: -1)), 'Marcá cuál es la opción correcta.');
    });
  });

  group('relacionar', () {
    test('entre 2 y 6 parejas', () {
      expect(validateQuestion(matching(left: ['1'], images: ['a'])), contains('entre 2 y 6'));
      expect(
        validateQuestion(matching(
          left: List.generate(7, (i) => '$i'),
          images: List.generate(7, (i) => 'img$i'),
        )),
        contains('entre 2 y 6'),
      );
    });

    test('cada elemento tiene su imagen', () {
      expect(validateQuestion(matching(images: ['uno.png', 'dos.png'])), 'Cada elemento tiene que tener su imagen.');
      expect(validateQuestion(matching(images: ['uno.png', '', 'tres.png'])), 'Falta la imagen de la pareja 2.');
    });

    test('no acepta textos vacíos', () {
      expect(validateQuestion(matching(left: ['1', ' ', '3'])), 'Falta el texto de la pareja 2.');
    });

    test('no acepta elementos repetidos, aunque cambien las mayúsculas', () {
      expect(validateQuestion(matching(left: ['Perro', 'Gato', 'perro '])), contains('"perro"'));
    });

    test('no acepta la misma imagen en dos parejas', () {
      expect(validateQuestion(matching(images: ['uno.png', 'uno.png', 'tres.png'])), 'La misma imagen está en dos parejas.');
    });
  });
}
