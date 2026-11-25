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
      String.fromEnvironment('ANDROID_PACKAGE', defaultValue: 'io.github.juanespinoza8.quizdaily');
  static const String _androidCertSha1 = String.fromEnvironment('ANDROID_CERT_SHA1');

  static bool get isConfigured => _apiKey.isNotEmpty;

  /// Alias que siempre apunta al modelo Flash vigente. Un nombre fijo
  /// (gemini-2.5-flash) dejó de estar disponible para claves nuevas y la app
  /// instalada no se puede actualizar sola: con el alias sigue funcionando.
  static const modelName = 'gemini-flash-latest';

  /// Se usa si [modelName] está saturado o ya no existe. Es más liviano y
  /// suele responder cuando Flash devuelve "high demand" (503).
  static const fallbackModelName = 'gemini-flash-lite-latest';

  /// Si con este error conviene probar el modelo siguiente: saturación o
  /// modelo retirado. Con una clave inválida o sin conexión no tiene sentido.
  static bool shouldTryNextModel(Object error) {
    if (error is GeminiException || error is InvalidApiKey || error is UnsupportedUserLocation) return false;
    if (error is SocketException || error is http.ClientException) return false;
    final detail = (error is GenerativeAIException ? error.message : '$error').toLowerCase();
    return detail.contains('demand') ||
        detail.contains('overloaded') ||
        detail.contains('unavailable') ||
        detail.contains('no longer available') ||
        detail.contains('not found');
  }

  /// Llama a [attempt] con cada modelo, en orden, hasta que uno responda. Si
  /// el error no justifica probar otro (ver [shouldTryNextModel]), lo deja
  /// pasar enseguida; si fallan todos, lanza el último error.
  static Future<T> tryModels<T>(List<String> models, Future<T> Function(String model) attempt) async {
    Object? lastError;
    for (final model in models) {
      try {
        return await attempt(model);
      } catch (e) {
        if (!shouldTryNextModel(e)) rethrow;
        debugPrint('El modelo $model no respondió ($e); se prueba el siguiente.');
        lastError = e;
      }
    }
    throw lastError ?? StateError('No hay modelos para probar.');
  }

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

    // Lo ve quien usa la app: sin detalles técnicos. Cómo compilar con la
    // clave (GEMINI_API_KEY en env.json) está en el README.
    if (!isConfigured) {
      throw const GeminiException('La generación con IA no está disponible en esta versión de la app.');
    }

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
      final responseText = await tryModels([modelName, fallbackModelName], (name) async {
        final model = GenerativeModel(
          model: name,
          apiKey: _apiKey,
          httpClient: _buildHttpClient(),
          // Pedimos JSON con un esquema fijo en lugar de limpiar texto libre.
          generationConfig: GenerationConfig(
            responseMimeType: 'application/json',
            responseSchema: _responseSchema,
          ),
        );
        final response = await model.generateContent([Content.multi(parts)]);
        return response.text;
      });
      if (responseText == null || responseText.trim().isEmpty) {
        throw const GeminiException('La IA no devolvió respuesta. Probá de nuevo.');
      }
      return parseQuestions(responseText, category: userCategory);
    } on GeminiException {
      rethrow;
    } catch (e) {
      // El detalle técnico (en inglés) queda en el log; al usuario le llega
      // un mensaje en español.
      debugPrint('Error generando preguntas: $e');
      throw friendlyError(e);
    }
  }

  /// Traduce un error de la conexión o de la API a un mensaje para el usuario.
  static GeminiException friendlyError(Object error) {
    if (error is SocketException || error is http.ClientException) {
      return const GeminiException('No hay conexión a internet. Revisá la conexión y probá de nuevo.');
    }
    if (error is InvalidApiKey) {
      return const GeminiException('La clave de la IA no es válida. Avisale a quien te pasó la app.');
    }
    if (error is UnsupportedUserLocation) {
      return const GeminiException('La generación con IA no está disponible en tu región.');
    }
    final detail = (error is GenerativeAIException ? error.message : '$error').toLowerCase();
    if (detail.contains('demand') || detail.contains('overloaded') || detail.contains('unavailable')) {
      return const GeminiException('El servicio de IA está saturado en este momento. Probá de nuevo en unos minutos.');
    }
    if (detail.contains('quota') || detail.contains('resource_exhausted') || detail.contains('rate limit')) {
      return const GeminiException('Se alcanzó el límite de uso de la IA. Probá de nuevo más tarde.');
    }
    if (detail.contains('no longer available') || detail.contains('not found')) {
      return const GeminiException('El modelo de IA ya no está disponible. Hace falta actualizar la app.');
    }
    return const GeminiException('No se pudieron generar las preguntas. Probá de nuevo más tarde.');
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