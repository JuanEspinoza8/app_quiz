import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import '../data/progress_repository.dart';
import '../data/question_repository.dart';
import '../logic/question_validator.dart';
import '../models/daily_stats.dart';
import '../models/question.dart';
import 'data_sync_service.dart';
import 'image_store.dart';

/// Qué se restaura de un respaldo.
enum ImportMode {
  /// Solo se agregan las preguntas nuevas.
  questionsOnly,

  /// También se reemplazan meta, racha, recordatorio y estadísticas.
  all,
}

/// El archivo no se pudo leer como respaldo. No se escribió nada.
class BackupFormatException implements Exception {
  final String message;
  const BackupFormatException(this.message);

  @override
  String toString() => message;
}

class ImportResult {
  final int added;
  final int duplicates;
  final int invalid;
  final bool progressRestored;

  const ImportResult({
    required this.added,
    required this.duplicates,
    required this.invalid,
    required this.progressRestored,
  });

  String get message {
    var text = added == 1 ? 'Se agregó 1 pregunta' : 'Se agregaron $added preguntas';
    final details = [
      if (duplicates > 0) '$duplicates ya ${duplicates == 1 ? 'estaba' : 'estaban'}',
      if (invalid > 0) '$invalid no ${invalid == 1 ? 'válida' : 'válidas'}',
    ];
    if (details.isNotEmpty) text += ' (${details.join(', ')})';
    if (progressRestored) text += ' y se restauró tu progreso 📈';
    return text;
  }
}

class ImportService {
  /// Restaura un respaldo: el .zip actual o el .json de versiones anteriores.
  ///
  /// Primero lee y valida todo; recién después escribe. Si el archivo no se
  /// puede leer, lanza [BackupFormatException] sin haber tocado nada. Las
  /// preguntas que ya existen (mismo id) o que no se pueden jugar se saltean
  /// y se cuentan en el resultado.
  static Future<ImportResult> importBackup(
    File file, {
    required QuestionRepository questions,
    required ProgressRepository progress,
    required ImageStore images,
    ImportMode mode = ImportMode.all,
  }) async {
    final content = _readContent(await file.readAsBytes());

    final Object? data = content.json;
    List<dynamic> items;
    Map<dynamic, dynamic>? progressMap;
    List<dynamic>? statsList;
    if (data is List) {
      // Formato más viejo: solo una lista de preguntas.
      items = data;
    } else if (data is Map) {
      items = data['questions'] is List ? data['questions'] as List : const [];
      progressMap = data['progress'] is Map ? data['progress'] as Map : null;
      statsList = data['stats'] is List ? data['stats'] as List : null;
    } else {
      throw const BackupFormatException('El archivo no es un respaldo de Quiz Daily.');
    }

    // Una imagen se puede usar si viene en el zip o, en un .json viejo, si el
    // archivo existe en este teléfono (en otro teléfono la ruta no sirve).
    bool imageAvailable(String ref) =>
        content.isZip ? content.images.containsKey(ref) : images.exists(ref);

    // 1. Leer y validar las preguntas, sin escribir nada.
    var duplicates = 0;
    var invalid = 0;
    final seenIds = <String>{};
    final accepted = <Question>[];
    for (final item in items) {
      var q = _parseQuestion(item);
      if (q == null) {
        invalid++;
        continue;
      }
      if (questions.containsId(q.id) || !seenIds.add(q.id)) {
        duplicates++;
        continue;
      }

      final imagePath = q.imagePath;
      if (imagePath != null && !imageAvailable(imagePath)) {
        // La pregunta se puede jugar igual, sin la imagen.
        q = q.copyWith(imagePath: () => null);
      }
      if (q.matchImages.any((ref) => !imageAvailable(ref))) {
        invalid++; // Sin sus imágenes, una pregunta de relacionar no se puede jugar.
        continue;
      }
      q = q.copyWith(category: questions.canonicalCategory(q.category));
      if (validateQuestion(q) != null) {
        invalid++;
        continue;
      }
      accepted.add(q);
    }

    // 2. Guardar las imágenes del zip con nombres nuevos.
    final toAdd = <Question>[];
    if (content.isZip) {
      final saved = <String, String>{};
      Future<String> store(String name) async =>
          saved[name] ??= await images.saveBytes(content.images[name]!, extension: _extensionOf(name));
      for (final q in accepted) {
        final imagePath = q.imagePath;
        final newImagePath = imagePath == null ? null : await store(imagePath);
        final newMatchImages = [for (final ref in q.matchImages) await store(ref)];
        toAdd.add(q.copyWith(imagePath: () => newImagePath, matchImages: newMatchImages));
      }
    } else {
      toAdd.addAll(accepted);
    }

    // 3. Guardar preguntas, progreso y estadísticas.
    await questions.addAll(toAdd);

    var progressRestored = false;
    if (mode == ImportMode.all) {
      if (progressMap != null) {
        await progress.restoreFromBackup(
          dailyGoal: _asInt(progressMap['dailyGoal']),
          streak: _asInt(progressMap['streak']),
          notificationHour: _asInt(progressMap['notifHour']),
          notificationMinute: _asInt(progressMap['notifMinute']),
          lastPlayed: _asDate(progressMap['lastPlayed']),
        );
        progressRestored = true;
      }
      if (statsList != null) {
        // Reemplazan a las actuales para no duplicar días en los gráficos.
        await progress.replaceDailyStats(_parseStats(statsList));
        progressRestored = true;
      }
    }

    return ImportResult(
      added: toAdd.length,
      duplicates: duplicates,
      invalid: invalid,
      progressRestored: progressRestored,
    );
  }

  static _BackupContent _readContent(Uint8List bytes) {
    // Un zip empieza con "PK\x03\x04".
    final isZip = bytes.length >= 4 && bytes[0] == 0x50 && bytes[1] == 0x4B && bytes[2] == 0x03 && bytes[3] == 0x04;
    try {
      if (!isZip) return _BackupContent(_decodeJson(bytes), const {}, isZip: false);

      final archive = ZipDecoder().decodeBytes(bytes);
      final jsonFile = archive.findFile(kBackupJsonName);
      if (jsonFile == null) {
        throw const BackupFormatException('El .zip no es un respaldo de Quiz Daily (falta $kBackupJsonName).');
      }
      final images = <String, Uint8List>{
        for (final f in archive.files)
          if (f.isFile && f.name.startsWith(kBackupImagesDir) && f.name.length > kBackupImagesDir.length)
            f.name.substring(kBackupImagesDir.length): f.content,
      };
      return _BackupContent(_decodeJson(jsonFile.content), images, isZip: true);
    } on BackupFormatException {
      rethrow;
    } catch (e) {
      throw BackupFormatException('No se pudo leer el archivo: no es un respaldo válido ($e).');
    }
  }

  static Object? _decodeJson(List<int> bytes) {
    var text = utf8.decode(bytes);
    if (text.startsWith('﻿')) text = text.substring(1); // BOM
    return jsonDecode(text);
  }

  /// Convierte un ítem del respaldo en una pregunta, o null si le falta algo
  /// obligatorio. Limpia lo que dejaba la versión anterior: espacios y
  /// opciones vacías (el editor viejo guardaba siempre 4).
  static Question? _parseQuestion(Object? item) {
    if (item is! Map) return null;
    final Question q;
    try {
      q = Question.fromJson(Map<String, dynamic>.from(item));
    } catch (_) {
      return null;
    }

    var result = q.copyWith(
      questionText: q.questionText.trim(),
      category: q.category.trim(),
      matchLeft: [for (final left in q.matchLeft) left.trim()],
    );
    if (q.type == QuestionType.multipleChoice) {
      final options = <String>[];
      var correct = -1; // si la correcta estaba vacía, la validación la rechaza
      for (var i = 0; i < q.options.length; i++) {
        final option = q.options[i].trim();
        if (option.isEmpty) continue;
        if (i == q.correctAnswerIndex) correct = options.length;
        options.add(option);
      }
      result = result.copyWith(options: options, correctAnswerIndex: correct);
    }
    return result;
  }

  static List<DailyStats> _parseStats(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map && _asDate(item['date']) != null && _asInt(item['answered']) != null)
          DailyStats(
            date: _asDate(item['date'])!,
            questionsAnswered: _asInt(item['answered'])!,
            correctAnswers: _asInt(item['correct']) ?? 0,
          ),
    ];
  }

  static int? _asInt(Object? value) => value is int ? value : null;

  static DateTime? _asDate(Object? value) => value is String ? DateTime.tryParse(value) : null;

  static String _extensionOf(String name) {
    final dot = name.lastIndexOf('.');
    return dot < 0 ? 'jpg' : name.substring(dot + 1);
  }
}

class _BackupContent {
  final Object? json;
  final Map<String, Uint8List> images;
  final bool isZip;
  const _BackupContent(this.json, this.images, {required this.isZip});
}
