import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
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
    );

    // Construimos la lista de "evitar"
    String avoidText = "";
    if (avoidQuestions != null && avoidQuestions.isNotEmpty) {
      avoidText = "NO generes preguntas similares a estas: ${avoidQuestions.join(', ')}";
    }

    // El prompt base
    final fullPrompt = '''
      Actúa como un profesor experto creando un examen.
      Genera 5 preguntas de opción múltiple NUEVAS basadas en el material proporcionado (Texto o Archivo adjunto)
      pero en ningun momento hacer mencion al mismo, ademas las opciones incorrectas no deben ser absurdas, deben parecer posibles pero ser erroneas.
      
      REGLAS OBLIGATORIAS:
      1. La categoría de TODAS debe ser: "$userCategory".
      2. $avoidText
      3. Preguntas DIRECTAS y AUTÓNOMAS.
      
      FORMATO SALIDA (JSON puro Array []):
      - "questionText": Enunciado.
      - "options": Array de 4 respuestas.
      - "correctAnswerIndex": 0-3.
      - "category": "$userCategory".
      - "explanation": Breve porqué.

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
      if (responseText == null) throw Exception("La IA no devolvió respuesta.");

      final cleanJson = responseText.replaceAll('```json', '').replaceAll('```', '').trim();
      final List<dynamic> jsonList = jsonDecode(cleanJson);
      final uuid = const Uuid();

      return jsonList.map((item) {
        return Question(
          id: uuid.v4(),
          questionText: item['questionText'],
          options: List<String>.from(item['options']),
          correctAnswerIndex: item['correctAnswerIndex'],
          category: item['category'] ?? userCategory,
          createdAt: DateTime.now(),
          explanation: item['explanation'],
          errorCount: 0,
          totalAttempts: 0,
        );
      }).toList();

    } catch (e) {
      print("Error generando preguntas: $e");
      rethrow;
    }
  }
}