import 'package:equatable/equatable.dart';
import '../../domain/entities/file_entity.dart';

abstract class FilesState extends Equatable {
  const FilesState();

  @override
  List<Object?> get props => [];
}

class FilesInitial extends FilesState {}

class FilesLoading extends FilesState {}

class FilesLoaded extends FilesState {
  final List<FileEntity> files;

  const FilesLoaded(this.files);

  @override
  List<Object?> get props => [files];
}

class FilesError extends FilesState {
  final String message;

  const FilesError(this.message);

  @override
  List<Object?> get props => [message];
}

class FileDownloading extends FilesState {
  final String fileName;
  final double progress;

  const FileDownloading(this.fileName, this.progress);

  @override
  List<Object?> get props => [fileName, progress];
}

class FileDownloaded extends FilesState {
  final String filePath;

  const FileDownloaded(this.filePath);

  @override
  List<Object?> get props => [filePath];
}

class FileDownloadError extends FilesState {
  final String message;

  const FileDownloadError(this.message);

  @override
  List<Object?> get props => [message];
}