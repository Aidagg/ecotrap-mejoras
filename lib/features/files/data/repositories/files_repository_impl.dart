import '../../domain/entities/file_entity.dart';
import '../../domain/repositories/files_repository.dart';
import '../datasources/files_remote_datasource.dart';

class FilesRepositoryImpl implements FilesRepository {
  final FilesRemoteDataSource remoteDataSource;

  FilesRepositoryImpl(this.remoteDataSource);

  @override
  Future<List<FileEntity>> getFiles() async {
    return await remoteDataSource.getFiles();
  }

  @override
  Future<String> downloadFile(String fileName, Function(double) onProgress) async {
    return await remoteDataSource.downloadFile(fileName, onProgress);
  }
}