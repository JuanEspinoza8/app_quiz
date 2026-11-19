import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_daily/services/image_store.dart';

void main() {
  late Directory tmp;
  late FileImageStore store;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('quiz_images_test_');
    store = FileImageStore(Directory('${tmp.path}/question_images'));
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  Future<File> sourceFile(String name, List<int> bytes) async {
    final file = File('${tmp.path}/$name');
    await file.writeAsBytes(bytes);
    return file;
  }

  test('saveFromPath copia la imagen con un nombre nuevo y conserva la extensión', () async {
    final source = await sourceFile('foto.PNG', [1, 2, 3]);

    final ref = await store.saveFromPath(source.path);

    expect(ref, endsWith('.png'));
    expect(ref, isNot(contains('/')));
    expect(store.exists(ref), isTrue);
    expect(await store.readBytes(ref), [1, 2, 3]);
    // La copia no depende del original (que en Android está en la caché).
    await source.delete();
    expect(store.exists(ref), isTrue);
  });

  test('sin extensión reconocible usa jpg', () async {
    final source = await sourceFile('sin_extension', [9]);
    expect(await store.saveFromPath(source.path), endsWith('.jpg'));
    expect(await store.saveBytes(Uint8List.fromList([1]), extension: '../x'), endsWith('.jpg'));
  });

  test('saveBytes guarda y readBytes devuelve null si no existe', () async {
    final ref = await store.saveBytes(Uint8List.fromList([4, 5]), extension: 'png');

    expect(await store.readBytes(ref), [4, 5]);
    expect(await store.readBytes('no_existe.png'), isNull);
    expect(store.exists('no_existe.png'), isFalse);
  });

  test('las rutas absolutas de las preguntas viejas se usan tal cual', () async {
    final legacy = await sourceFile('vieja.jpg', [7]);

    expect(store.exists(legacy.path), isTrue);
    expect(await store.readBytes(legacy.path), [7]);
    expect(store.providerFor(legacy.path), isNotNull);
  });

  test('providerFor devuelve null si falta el archivo y achica con cacheWidth', () async {
    final ref = await store.saveBytes(Uint8List.fromList([1]), extension: 'png');

    expect(store.providerFor('no_existe.png'), isNull);
    expect(store.providerFor(ref), isA<FileImage>());
    expect(store.providerFor(ref, cacheWidth: 200), isA<ResizeImage>());
  });

  test('deleteUnreferenced borra solo las imágenes que no se usan', () async {
    final used = await store.saveBytes(Uint8List.fromList([1]));
    final unused = await store.saveBytes(Uint8List.fromList([2]));
    final legacy = await sourceFile('vieja.jpg', [3]);

    final deleted = await store.deleteUnreferenced({used, legacy.path});

    expect(deleted, 1);
    expect(store.exists(used), isTrue);
    expect(store.exists(unused), isFalse);
    // Lo que está fuera de la carpeta de la app nunca se toca.
    expect(await legacy.exists(), isTrue);
  });

  test('deleteUnreferenced no falla si la carpeta todavía no existe', () async {
    expect(await store.deleteUnreferenced({}), 0);
  });
}
