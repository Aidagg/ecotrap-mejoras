import 'package:ecotrap/features/files/domain/entities/file_entity.dart';
import 'package:ecotrap/features/files/domain/repositories/files_repository.dart';
import 'package:ecotrap/features/files/domain/usecases/get_files.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'get_files_test.mocks.dart';

/// Generar mocks:
/// flutter pub run build_runner build --delete-conflicting-outputs
@GenerateMocks([FilesRepository])
void main() {
  late GetFiles usecase;
  late MockFilesRepository mockRepository;

  setUp(() {
    mockRepository = MockFilesRepository();
    usecase = GetFiles(mockRepository);
  });

  final tFiles = [
    FileEntity(name: 'trampa_001.jpg', size: 204800),
    FileEntity(name: 'ciclo_2024.json', size: 1024),
  ];

  group('GetFiles', () {
    test('debe retornar la lista de archivos del repositorio', () async {
      // Arrange
      when(mockRepository.getFiles()).thenAnswer((_) async => tFiles);

      // Act
      final result = await usecase();

      // Assert
      expect(result, tFiles);
      verify(mockRepository.getFiles());
      verifyNoMoreInteractions(mockRepository);
    });

    test('debe retornar lista vacía cuando el dispositivo no tiene archivos',
        () async {
      // Arrange
      when(mockRepository.getFiles()).thenAnswer((_) async => []);

      // Act
      final result = await usecase();

      // Assert
      expect(result, isEmpty);
      verify(mockRepository.getFiles());
    });

    test('debe propagar la excepción cuando el repositorio falla', () async {
      // Arrange
      when(mockRepository.getFiles())
          .thenThrow(Exception('Error de conexión al dispositivo IoT'));

      // Act & Assert
      expect(() => usecase(), throwsA(isA<Exception>()));
      verify(mockRepository.getFiles());
    });
  });
}
