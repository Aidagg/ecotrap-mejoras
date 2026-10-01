import 'package:bloc_test/bloc_test.dart';
import 'package:ecotrap/features/files/domain/entities/file_entity.dart';
import 'package:ecotrap/features/files/domain/usecases/download_file.dart';
import 'package:ecotrap/features/files/domain/usecases/get_files.dart';
import 'package:ecotrap/features/files/presentation/bloc/files_bloc.dart';
import 'package:ecotrap/features/files/presentation/bloc/files_event.dart';
import 'package:ecotrap/features/files/presentation/bloc/files_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'files_bloc_test.mocks.dart';

/// Generar mocks:
/// flutter pub run build_runner build --delete-conflicting-outputs
@GenerateMocks([GetFiles, DownloadFile])
void main() {
  late FilesBloc bloc;
  late MockGetFiles mockGetFiles;
  late MockDownloadFile mockDownloadFile;

  setUp(() {
    mockGetFiles = MockGetFiles();
    mockDownloadFile = MockDownloadFile();
    bloc = FilesBloc(
      getFiles: mockGetFiles,
      downloadFile: mockDownloadFile,
    );
  });

  tearDown(() {
    bloc.close();
  });

  final tFiles = [
    FileEntity(name: 'trampa_001.jpg', size: 204800),
    FileEntity(name: 'ciclo_2024.json', size: 1024),
  ];

  group('LoadFiles', () {
    blocTest<FilesBloc, FilesState>(
      'emite [FilesLoading, FilesLoaded] cuando la carga es exitosa',
      build: () {
        when(mockGetFiles()).thenAnswer((_) async => tFiles);
        return bloc;
      },
      act: (bloc) => bloc.add(LoadFiles()),
      expect: () => [
        FilesLoading(),
        FilesLoaded(tFiles),
      ],
      verify: (_) {
        verify(mockGetFiles());
      },
    );

    blocTest<FilesBloc, FilesState>(
      'emite [FilesLoading, FilesLoaded] con lista vacía cuando no hay archivos',
      build: () {
        when(mockGetFiles()).thenAnswer((_) async => []);
        return bloc;
      },
      act: (bloc) => bloc.add(LoadFiles()),
      expect: () => [
        FilesLoading(),
        FilesLoaded(const []),
      ],
    );

    blocTest<FilesBloc, FilesState>(
      'emite [FilesLoading, FilesError] cuando la carga falla',
      build: () {
        when(mockGetFiles())
            .thenThrow(Exception('Error de conexión al dispositivo IoT'));
        return bloc;
      },
      act: (bloc) => bloc.add(LoadFiles()),
      expect: () => [
        FilesLoading(),
        isA<FilesError>(),
      ],
    );
  });

  group('DownloadFileEvent', () {
    const tFileName = 'trampa_001.jpg';
    const tFilePath = '/storage/emulated/0/EcoTrap/trampa_001.jpg';

    blocTest<FilesBloc, FilesState>(
      'emite [FileDownloading, FileDownloaded] cuando la descarga es exitosa',
      build: () {
        when(mockDownloadFile(any, any)).thenAnswer((invocation) async {
          final onProgress =
              invocation.positionalArguments[1] as Function(double);
          onProgress(0.5);
          onProgress(1.0);
          return tFilePath;
        });
        return bloc;
      },
      act: (bloc) => bloc.add(const DownloadFileEvent(tFileName)),
      expect: () => [
        const FileDownloading(tFileName, 0.5),
        const FileDownloading(tFileName, 1.0),
        const FileDownloaded(tFilePath),
      ],
      verify: (_) {
        verify(mockDownloadFile(tFileName, any));
      },
    );

    blocTest<FilesBloc, FilesState>(
      'emite [FileDownloadError] cuando la descarga falla',
      build: () {
        when(mockDownloadFile(any, any))
            .thenThrow(Exception('Sin espacio en el dispositivo'));
        return bloc;
      },
      act: (bloc) => bloc.add(const DownloadFileEvent(tFileName)),
      expect: () => [
        isA<FileDownloadError>(),
      ],
    );
  });
}
