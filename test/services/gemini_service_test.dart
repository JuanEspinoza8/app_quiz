import 'dart:convert';

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:quiz_daily/services/gemini_service.dart';

Map<String, Object?> question({
  Object? text = '¿Cuál es el planeta más grande?',
  Object? options = const ['Júpiter', 'Saturno', 'Tierra', 'Marte'],
  Object? correct = 0,
  Object? explanation = 'Júpiter es el más grande del sistema solar.',
}) =>
    {
      'questionText': text,
      'options': options,
      'correctAnswerIndex': correct,
      'explanation': explanation,
    };

void main() {
  group('GeminiService.parseQuestions', () {
    test('convierte una respuesta válida y usa la categoría elegida', () {
      final json = jsonEncode([
        {...question(), 'category': 'Otra cosa'},
        question(text: '¿Qué planeta tiene anillos más visibles?', correct: 1),
      ]);

      final result = GeminiService.parseQuestions(json, category: 'Astronomía');

      expect(result, hasLength(2));
      expect(result.every((q) => q.category == 'Astronomía'), isTrue);
      expect(result[1].options[result[1].correctAnswerIndex], 'Saturno');
      expect(result.first.id, isNot(result.last.id));
    });

    test('tolera que la respuesta venga envuelta en un bloque ```json', () {
      final json = '```json\n${jsonEncode([question()])}\n```';

      expect(GeminiService.parseQuestions(json, category: 'X'), hasLength(1));
    });

    test('descarta preguntas sin 4 opciones o con índice fuera de rango', () {
      final json = jsonEncode([
        question(options: ['a', 'b', 'c']),
        question(options: ['a', 'b', 'c', 'd', 'e']),
        question(correct: 4),
        question(correct: -1),
        question(correct: '0'),
        question(text: '   '),
        question(options: ['a', '', 'c', 'd']),
        'no es un objeto',
        question(text: 'La única válida'),
      ]);

      final result = GeminiService.parseQuestions(json, category: 'X');

      expect(result.map((q) => q.questionText), ['La única válida']);
    });

    test('una explicación vacía se guarda como null', () {
      final result = GeminiService.parseQuestions(jsonEncode([question(explanation: '  ')]), category: 'X');

      expect(result.single.explanation, isNull);
    });

    test('lanza GeminiException si no hay ninguna pregunta válida', () {
      expect(
        () => GeminiService.parseQuestions(jsonEncode([question(correct: 9)]), category: 'X'),
        throwsA(isA<GeminiException>()),
      );
    });

    test('lanza GeminiException si la respuesta no es JSON o no es una lista', () {
      expect(() => GeminiService.parseQuestions('Claro, acá van tus preguntas', category: 'X'),
          throwsA(isA<GeminiException>()));
      expect(() => GeminiService.parseQuestions(jsonEncode(question()), category: 'X'),
          throwsA(isA<GeminiException>()));
    });
  });

  test('sin GEMINI_API_KEY, generateQuestions avisa que la IA no está disponible', () async {
    // Los tests corren sin --dart-define, así que la clave está vacía. El
    // mensaje lo ve quien usa la app: no menciona detalles técnicos.
    expect(GeminiService.isConfigured, isFalse);
    await expectLater(
      GeminiService.generateQuestions('texto', userCategory: 'X'),
      throwsA(isA<GeminiException>()
          .having((e) => e.message, 'message', contains('no está disponible'))
          .having((e) => e.message, 'message', isNot(contains('GEMINI_API_KEY')))),
    );
  });

  group('GeminiService.friendlyError', () {
    String messageFor(Object error) => GeminiService.friendlyError(error).message;

    test('traduce los errores de la API y de la conexión a mensajes en español', () {
      expect(messageFor(ServerException('This model is currently experiencing high demand.')), contains('saturado'));
      expect(messageFor(ServerException('Resource has been exhausted (e.g. check quota).')), contains('límite de uso'));
      expect(
        messageFor(ServerException('This model models/gemini-2.5-flash is no longer available to new users.')),
        contains('actualizar la app'),
      );
      expect(messageFor(InvalidApiKey('API key not valid.')), contains('clave'));
      expect(messageFor(const SocketException('Failed host lookup')), contains('conexión a internet'));
      expect(messageFor(Exception('algo raro')), 'No se pudieron generar las preguntas. Probá de nuevo más tarde.');
    });

    test('ningún mensaje deja pasar el texto técnico en inglés', () {
      expect(messageFor(ServerException('Internal error encountered.')), isNot(contains('Internal')));
    });
  });

  test('usa el alias del modelo Flash vigente', () {
    expect(GeminiService.modelName, 'gemini-flash-latest');
  });
}
