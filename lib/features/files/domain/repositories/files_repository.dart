import '../entities/file_entity.dart';

abstract class FilesRepository {
  Future<List<FileEntity>> getFiles();
  Future<String> downloadFile(String fileName, Function(double) onProgress);
}