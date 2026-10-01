import 'package:equatable/equatable.dart';

abstract class FilesEvent extends Equatable {
  const FilesEvent();

  @override
  List<Object?> get props => [];
}

class LoadFiles extends FilesEvent {}

class DownloadFileEvent extends FilesEvent {
  final String fileName;

  const DownloadFileEvent(this.fileName);

  @override
  List<Object?> get props => [fileName];
}