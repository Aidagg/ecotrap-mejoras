import 'package:ecotrap/features/files/domain/entities/file_entity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FileEntity.sizeFormatted', () {
    test('devuelve bytes cuando el tamaño es menor a 1024', () {
      final entity = FileEntity(name: 'foto.jpg', size: 500);
      expect(entity.sizeFormatted, '500 B');
    });

    test('devuelve KB cuando el tamaño está entre 1024 y 1 MB', () {
      final entity = FileEntity(name: 'foto.jpg', size: 2048);
      expect(entity.sizeFormatted, '2.0 KB');
    });

    test('devuelve MB cuando el tamaño supera 1 MB', () {
      final entity = FileEntity(name: 'foto.jpg', size: 1024 * 1024 * 3);
      expect(entity.sizeFormatted, '3.0 MB');
    });

    test('redondea correctamente a un decimal en KB', () {
      final entity = FileEntity(name: 'doc.json', size: 1536); // 1.5 KB
      expect(entity.sizeFormatted, '1.5 KB');
    });
  });

  group('FileEntity.extension', () {
    test('devuelve la extensión en mayúsculas', () {
      final entity = FileEntity(name: 'captura.JPG', size: 100);
      expect(entity.extension, 'JPG');
    });

    test('devuelve la última extensión si hay varios puntos', () {
      final entity = FileEntity(name: 'archivo.backup.json', size: 100);
      expect(entity.extension, 'json'.toUpperCase());
    });

    test('devuelve DESCONOCIDO si no hay extensión', () {
      final entity = FileEntity(name: 'sinextension', size: 100);
      expect(entity.extension, 'DESCONOCIDO');
    });
  });

  group('FileEntity.isImage', () {
    for (final ext in ['jpg', 'jpeg', 'png', 'gif', 'webp']) {
      test('reconoce $ext como imagen', () {
        final entity = FileEntity(name: 'foto.$ext', size: 100);
        expect(entity.isImage, isTrue);
      });
    }

    test('no reconoce json como imagen', () {
      final entity = FileEntity(name: 'datos.json', size: 100);
      expect(entity.isImage, isFalse);
    });

    test('no reconoce txt como imagen', () {
      final entity = FileEntity(name: 'notas.txt', size: 100);
      expect(entity.isImage, isFalse);
    });
  });

  group('FileEntity.isJson', () {
    test('reconoce .json como JSON', () {
      final entity = FileEntity(name: 'datos.json', size: 100);
      expect(entity.isJson, isTrue);
    });

    test('no reconoce .jpg como JSON', () {
      final entity = FileEntity(name: 'foto.jpg', size: 100);
      expect(entity.isJson, isFalse);
    });

    test('no reconoce archivos sin extensión como JSON', () {
      final entity = FileEntity(name: 'sinextension', size: 100);
      expect(entity.isJson, isFalse);
    });
  });
}
