import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Dónde viven las imágenes de las preguntas. Las preguntas guardan solo una
/// referencia (el nombre del archivo) y las pantallas le piden la imagen a
/// este servicio.
abstract class ImageStore {
  /// Copia la imagen de [sourcePath] y devuelve la referencia para guardar.
  Future<String> saveFromPath(String sourcePath);

  /// Guarda [bytes] como una imagen nueva y devuelve su referencia.
  Future<String> saveBytes(Uint8List bytes, {String extension = 'jpg'});

  /// Los bytes de la imagen, o null si no está en este dispositivo.
  Future<Uint8List?> readBytes(String ref);

  /// Si la imagen está en este dispositivo.
  bool exists(String ref);

  /// La imagen lista para mostrar, o null si no está. Con [cacheWidth] se
  /// decodifica achicada, para no tener fotos de 12 MP en memoria.
  ImageProvider? providerFor(String ref, {int? cacheWidth});

  /// Borra las imágenes guardadas que no estén en [usedRefs] y devuelve
  /// cuántas borró.
  Future<int> deleteUnreferenced(Set<String> usedRefs);
}

/// Guarda las imágenes en la carpeta de documentos de la app, que a
/// diferencia de la caché no la vacía el sistema.
class FileImageStore implements ImageStore {
  final Directory directory;
  static const _uuid = Uuid();

  FileImageStore(this.directory);

  static Future<FileImageStore> open() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}${Platform.pathSeparator}question_images');
    await dir.create(recursive: true);
    return FileImageStore(dir);
  }

  /// Las referencias son nombres de archivo dentro de [directory]. Las
  /// preguntas viejas guardaban la ruta absoluta: esas se usan tal cual.
  File fileFor(String ref) {
    final file = File(ref);
    if (file.isAbsolute) return file;
    return File('${directory.path}${Platform.pathSeparator}$ref');
  }

  @override
  Future<String> saveFromPath(String sourcePath) async {
    final name = '${_uuid.v4()}.${_extensionOf(sourcePath)}';
    await directory.create(recursive: true);
    await File(sourcePath).copy(fileFor(name).path);
    return name;
  }

  @override
  Future<String> saveBytes(Uint8List bytes, {String extension = 'jpg'}) async {
    final name = '${_uuid.v4()}.${_cleanExtension(extension)}';
    await directory.create(recursive: true);
    await fileFor(name).writeAsBytes(bytes, flush: true);
    return name;
  }

  @override
  Future<Uint8List?> readBytes(String ref) async {
    final file = fileFor(ref);
    if (!await file.exists()) return null;
    return file.readAsBytes();
  }

  @override
  bool exists(String ref) => fileFor(ref).existsSync();

  @override
  ImageProvider? providerFor(String ref, {int? cacheWidth}) {
    final file = fileFor(ref);
    if (!file.existsSync()) return null;
    return ResizeImage.resizeIfNeeded(cacheWidth, null, FileImage(file));
  }

  @override
  Future<int> deleteUnreferenced(Set<String> usedRefs) async {
    if (!await directory.exists()) return 0;
    var deleted = 0;
    await for (final entity in directory.list()) {
      if (entity is! File) continue;
      final name = entity.uri.pathSegments.last;
      if (usedRefs.contains(name) || usedRefs.contains(entity.path)) continue;
      try {
        await entity.delete();
        deleted++;
      } on FileSystemException {
        // Si un archivo no se puede borrar ahora, se intenta en el próximo inicio.
      }
    }
    return deleted;
  }

  static String _extensionOf(String path) {
    final dot = path.lastIndexOf('.');
    final slash = path.lastIndexOf(RegExp(r'[/\\]'));
    if (dot <= slash) return 'jpg';
    return _cleanExtension(path.substring(dot + 1));
  }

  static String _cleanExtension(String extension) {
    final ext = extension.toLowerCase();
    return RegExp(r'^[a-z0-9]{1,5}$').hasMatch(ext) ? ext : 'jpg';
  }
}
