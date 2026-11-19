import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import '../data/progress_repository.dart';
import '../data/question_repository.dart';
import 'image_store.dart';

/// Versión del formato de respaldo.
/// 1: un .json sin imágenes (versiones anteriores de la app).
/// 2: un .zip con backup.json y las imágenes en images/.
const kBackupVersion = 2;
const kBackupJsonName = 'backup.json';
const kBackupImagesDir = 'images/';

class DataSyncService {
  /// Crea el respaldo en la carpeta temporal y devuelve su ruta.
  static Future<String> exportFullBackup({
    required QuestionRepository questions,
    required ProgressRepository progress,
    required ImageStore images,
  }) async {
    final bytes = await buildBackupZip(questions: questions, progress: progress, images: images);
    final dir = await getTemporaryDirectory();
    // Usamos la fecha en el nombre para saber de cuándo es
    final dateStr = DateTime.now().toIso8601String().split('T')[0];
    final file = File('${dir.path}${Platform.pathSeparator}QuizBackup_$dateStr.zip');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  /// Arma el .zip: backup.json con preguntas, progreso y estadísticas, y las
  /// imágenes de las preguntas. Dentro del respaldo cada imagen se llama
  /// img_N.ext; al restaurar se guardan con nombres nuevos.
  static Future<Uint8List> buildBackupZip({
    required QuestionRepository questions,
    required ProgressRepository progress,
    required ImageStore images,
  }) async {
    final archive = Archive();
    final packed = <String, String?>{};
    var counter = 0;

    /// Agrega la imagen al zip una sola vez y devuelve su nombre ahí adentro,
    /// o null si el archivo no está en este teléfono.
    Future<String?> pack(String ref) async {
      if (packed.containsKey(ref)) return packed[ref];
      final bytes = await images.readBytes(ref);
      String? name;
      if (bytes != null) {
        name = 'img_${counter++}.${_extensionOf(ref)}';
        archive.addFile(ArchiveFile.bytes('$kBackupImagesDir$name', bytes));
      }
      return packed[ref] = name;
    }

    final questionsData = <Map<String, dynamic>>[];
    for (final q in questions.all) {
      final json = q.toJson();
      final imagePath = q.imagePath;
      json['imagePath'] = imagePath == null ? null : await pack(imagePath);
      json['matchImages'] = [for (final ref in q.matchImages) await pack(ref) ?? ''];
      questionsData.add(json);
    }

    final p = progress.progress;
    final data = {
      'version': kBackupVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'questions': questionsData,
      'progress': {
        'dailyGoal': p.dailyGoal,
        'streak': p.streak,
        'lastPlayed': p.lastPlayedDate.toIso8601String(),
        'notifHour': p.notificationHour,
        'notifMinute': p.notificationMinute,
        // answeredToday no se exporta: al restaurar otro día no tiene sentido
      },
      'stats': [
        for (final s in progress.dailyStats)
          {
            'date': s.date.toIso8601String(),
            'answered': s.questionsAnswered,
            'correct': s.correctAnswers,
          },
      ],
    };

    archive.addFile(ArchiveFile.string(kBackupJsonName, const JsonEncoder.withIndent('  ').convert(data)));
    return ZipEncoder().encodeBytes(archive);
  }

  static String _extensionOf(String ref) {
    final dot = ref.lastIndexOf('.');
    final slash = ref.lastIndexOf(RegExp(r'[/\\]'));
    if (dot <= slash) return 'jpg';
    final ext = ref.substring(dot + 1).toLowerCase();
    return RegExp(r'^[a-z0-9]{1,5}$').hasMatch(ext) ? ext : 'jpg';
  }
}
