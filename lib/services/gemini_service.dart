import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;
import '../models/question.dart';
import 'package:uuid/uuid.dart';

/// Error con un mensaje listo para mostrar al usuario.
class GeminiException implements Exception {
  final String message;
  const GeminiException(this.message);

  @override
  String toString() => message;
}

/// Agrega los headers que Google Cloud usa para validar una API key
/// restringida a una app Android. El SDK de Dart no los manda por su cuenta.
class _AndroidAppHeadersClient extends http.BaseClient {
  final String packageName;
  final String certSha1;
  final http.Client _inner = http.Client();

  _AndroidAppHeadersClient(this.packageName, this.certSha1);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['X-Android-Package'] = packageName;
    request.headers['X-Android-Cert'] = certSha1;
    return _inner.send(request);
  }

  @override
  void close() => _inner.close();
}

class GeminiService {
  /// Se inyecta al compilar: `flutter run --dart-define-from-file=env.json`.
  static const String _apiKey = String.fromEnvironment('GEMINI_API_KEY');

  /// Opcionales: solo hacen falta si la clave está restringida a la app Android.
  static const String _androidPackage =
      String.fromEnvironment('ANDROID_PACKAGE', defaultValue: 'com.example.quiz_daily');
  static const String _androidCertSha1 = String.fromEnvironment('ANDROID_CERT_SHA1');

  static bool get isConfigured => _apiKey.isNotEmpty;

  static http.Client? _buildHttpClient() {
    if (_androidCertSha1.isEmpty || !Platform.isAndroid) return null;
    // Google espera la huella en hexadecimal, sin los ':'.
    final cert = _androidCertSha1.replaceAll(':', '').toUpperCase();
    return _AndroidAppHeadersClient(_androidPackage, cert);
  }

  static Future<List<Question>> generateQuestions(
      String promptText, {
        required String userCategory,
        List<String>? avoidQuestions,
        Uint8List? fileBytes,
        String? mimeType,
      }) async {

    if (!isConfigured) {
      throw const GeminiException(
        'Falta GEMINI_API_KEY. Ejecutá la app con '
        '--dart-define-from-file=env.json (ver README).',
      );
    }

    final model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: _apiKey,
      httpClient: _buildHttpClient(),
      // Pedimos JSON con un esquema fijo en lugar de limpiar texto libre.
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
        responseSchema: _responseSchema,
      ),
    );

    final avoidRule = (avoidQuestions != null && avoidQuestions.isNotEmpty)
        ? '- NO generes preguntas similares a estas: ${avoidQuestions.join(', ')}'
        : '';

    final fullPrompt = '''
      Actúa como un profesor experto creando un examen.
      Genera 5 preguntas de opción múltiple NUEVAS basadas en el material proporcionado (texto o archivo adjunto),
      sin mencionar el material. Las opciones incorrectas no deben ser absurdas: tienen que parecer posibles pero ser erróneas.

      REGLAS OBLIGATORIAS:
      - Preguntas DIRECTAS y AUTÓNOMAS.
      - Cada pregunta tiene exactamente 4 opciones y "correctAnswerIndex" es el índice (0 a 3) de la correcta.
      - "explanation" explica brevemente por qué es la correcta.
      $avoidRule

      CONTEXTO ADICIONAL DEL USUARIO:
      "$promptText"
    ''';

    // Preparamos el contenido para enviar (Texto + Archivo si existe)
    final List<Part> parts = [TextPart(fullPrompt)];

    if (fileBytes != null && mimeType != null) {
      parts.add(DataPart(mimeType, fileBytes));
    }

    try {
      final response = await model.generateContent([Content.multi(parts)]);
      final responseText = response.text;
      if (responseText == null || responseText.trim().isEmpty) {
        throw const GeminiException('La IA no devolvió respuesta. Probá de nuevo.');
      }
      return parseQuestions(responseText, category: userCategory);
    } catch (e) {
      debugPrint('Error generando preguntas: $e');
      rethrow;
    }
  }

  static final _responseSchema = Schema.array(
    items: Schema.object(
      properties: {
        'questionText': Schema.string(description: 'Enunciado de la pregunta'),
        'options': Schema.array(items: Schema.string(), description: 'Exactamente 4 opciones'),
        'correctAnswerIndex': Schema.integer(description: 'Índice de la opción correcta, de 0 a 3'),
        'explanation': Schema.string(description: 'Por qué esa opción es la correcta'),
      },
      requiredProperties: ['questionText', 'options', 'correctAnswerIndex', 'explanation'],
    ),
  );

  /// Convierte la respuesta JSON de Gemini en preguntas de la [category]
  /// elegida. Descarta las que no tengan enunciado, exactamente 4 opciones y
  /// un índice correcto dentro de rango; si no queda ninguna, lanza
  /// [GeminiException].
  static List<Question> parseQuestions(String responseText, {required String category}) {
    final clean = responseText.replaceAll('```json', '').replaceAll('```', '').trim();

    final Object? decoded;
    try {
      decoded = jsonDecode(clean);
    } on FormatException {
      throw const GeminiException('La IA devolvió una respuesta que no es JSON válido. Probá de nuevo.');
    }
    if (decoded is! List) {
      throw const GeminiException('La IA devolvió un formato inesperado. Probá de nuevo.');
    }

    const uuid = Uuid();
    final questions = <Question>[];
    for (final item in decoded) {
      final question = _questionFromJson(item, category, uuid);
      if (question != null) questions.add(question);
    }

    if (questions.isEmpty) {
      throw const GeminiException('La IA no devolvió preguntas válidas. Probá de nuevo.');
    }
    return questions;
  }

  static Question? _questionFromJson(Object? item, String category, Uuid uuid) {
    if (item is! Map) return null;

    final text = item['questionText'];
    final options = item['options'];
    final correct = item['correctAnswerIndex'];
    final explanation = item['explanation'];

    if (text is! String || text.trim().isEmpty) return null;
    if (options is! List || options.length != 4) return null;
    if (options.any((o) => o is! String || o.trim().isEmpty)) return null;
    if (correct is! int || correct < 0 || correct >= options.length) return null;

    return Question(
      id: uuid.v4(),
      questionText: text.trim(),
      options: options.map((o) => (o as String).trim()).toList(),
      correctAnswerIndex: correct,
      category: category,
      createdAt: DateTime.now(),
      explanation: (explanation is String && explanation.trim().isNotEmpty) ? explanation.trim() : null,
    );
  }
}