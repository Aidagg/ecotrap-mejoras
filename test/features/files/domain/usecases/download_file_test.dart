import 'package:ecotrap/features/files/domain/repositories/files_repository.dart';
import 'package:ecotrap/features/files/domain/usecases/download_file.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'download_file_test.mocks.dart';

/// Generar mocks:
/// flutter pub run build_runner build --delete-conflicting-outputs
@GenerateMocks([FilesRepository])
void main() {
  late DownloadFile usecase;
  late MockFilesRepository mockRepository;

  setUp(() {
    mockRepository = MockFilesRepository();
    usecase = DownloadFile(mockRepository);
  });

  const tFileName = 'trampa_001.jpg';
  const tFilePath = '/storage/emulated/0/EcoTrap/trampa_001.jpg';

  group('DownloadFile', () {
    test('debe retornar la ruta local del archivo descargado', () async {
      // Arrange
      when(mockRepository.downloadFile(any, any))
          .thenAnswer((_) async => tFilePath);

      // Act
      final result = await usecase(tFileName, (_) {});

      // Assert
      expect(result, tFilePath);
      verify(mockRepository.downloadFile(tFileName, any));
      verifyNoMoreInteractions(mockRepository);
    });

    test('debe invocar el callback de progreso durante la descarga', () async {
      // Arrange
      final progressValues = <double>[];

      when(mockRepository.downloadFile(any, any))
          .thenAnswer((invocation) async {
        final onProgress =
            invocation.positionalArguments[1] as Function(double);
        onProgress(0.25);
        onProgress(0.75);
        onProgress(1.0);
        return tFilePath;
      });

      // Act
      await usecase(tFileName, progressValues.add);

      // Assert
      expect(progressValues, [0.25, 0.75, 1.0]);
    });

    test('debe propagar la excepción cuando la descarga falla', () async {
      // Arrange
      when(mockRepository.downloadFile(any, any))
          .thenThrow(Exception('Sin espacio en el dispositivo'));

      // Act & Assert
      expect(
        () => usecase(tFileName, (_) {}),
        throwsA(isA<Exception>()),
      );
    });
  });
}
