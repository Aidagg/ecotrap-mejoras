import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/usecases/download_file.dart';
import '../../domain/usecases/get_files.dart';
import 'files_event.dart';
import 'files_state.dart';

class FilesBloc extends Bloc<FilesEvent, FilesState> {
  final GetFiles getFiles;
  final DownloadFile downloadFile;

  FilesBloc({
    required this.getFiles,
    required this.downloadFile,
  }) : super(FilesInitial()) {
    on<LoadFiles>(_onLoadFiles);
    on<DownloadFileEvent>(_onDownloadFile);
  }

  Future<void> _onLoadFiles(
    LoadFiles event,
    Emitter<FilesState> emit,
  ) async {
    emit(FilesLoading());
    
    try {
      final files = await getFiles();
      emit(FilesLoaded(files));
    } catch (e) {
      emit(FilesError(e.toString()));
    }
  }

  Future<void> _onDownloadFile(
    DownloadFileEvent event,
    Emitter<FilesState> emit,
  ) async {
    try {
      final filePath = await downloadFile(
        event.fileName,
        (progress) {
          emit(FileDownloading(event.fileName, progress));
        },
      );
      emit(FileDownloaded(filePath));
    } catch (e) {
      emit(FileDownloadError(e.toString()));
    }
  }
}