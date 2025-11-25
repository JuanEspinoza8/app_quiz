import 'dart:convert';
import 'dart:typed_data';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/question.dart';
import 'package:uuid/uuid.dart';

class GeminiService {
  static const String _apiKey = 'AIzaSyCfKhmdoSfOOADvGX23Q7u92GjndJlLSVQ'; // 👈 Tu API Key

  static Future<List<Question>> generateQuestions(
      String promptText, {
        required String userCategory,
        List<String>? avoidQuestions,
        Uint8List? fileBytes, // 👈 Nuevo: Archivo en bytes
        String? mimeType,     // 👈 Nuevo: Tipo de archivo (pdf, png, etc)
      }) async {

    if (_apiKey.startsWith('TU_API') || _apiKey.isEmpty) {
      throw Exception('⚠️ Error: Falta la API Key en gemini_service.dart');
    }

    final model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: _apiKey,
    );

    // Construimos la lista de "evitar"
    String avoidText = "";
    if (avoidQuestions != null && avoidQuestions.isNotEmpty) {
      avoidText = "NO generes preguntas similares a estas: ${avoidQuestions.join(', ')}";
    }

    // El prompt base
    final fullPrompt = '''
      Actúa como un profesor experto creando un examen.
      Genera 5 preguntas de opción múltiple NUEVAS basadas en el material proporcionado (Texto o Archivo adjunto).
      
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