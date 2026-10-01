import '../repositories/files_repository.dart';

class DownloadFile {
  final FilesRepository repository;

  DownloadFile(this.repository);

  Future<String> call(String fileName, Function(double) onProgress) async {
    return await repository.downloadFile(fileName, onProgress);
  }
}