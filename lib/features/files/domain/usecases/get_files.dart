import '../entities/file_entity.dart';
import '../repositories/files_repository.dart';

class GetFiles {
  final FilesRepository repository;

  GetFiles(this.repository);

  Future<List<FileEntity>> call() async {
    return await repository.getFiles();
  }
}