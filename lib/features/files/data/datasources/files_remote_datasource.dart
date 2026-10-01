import '../../../../core/network/api_service.dart';
import '../models/file_model.dart';

abstract class FilesRemoteDataSource {
  Future<List<FileModel>> getFiles();
  Future<String> downloadFile(String fileName, Function(double) onProgress);
}

class FilesRemoteDataSourceImpl implements FilesRemoteDataSource {
  final ApiService apiService;

  FilesRemoteDataSourceImpl(this.apiService);

  @override
  Future<List<FileModel>> getFiles() async {
    final response = await apiService.getFiles();
    
    if (response.success && response.data != null) {
      return response.data!.map((file) => FileModel(
        name: file.name,
        size: file.size,
      )).toList();
    } else {
      throw Exception(response.errorMessage ?? 'Error obteniendo archivos');
    }
  }

  @override
  Future<String> downloadFile(String fileName, Function(double) onProgress) async {
    final response = await apiService.downloadFile(
      fileName: fileName,
      onProgress: onProgress,
    );
    
    if (response.success && response.data != null) {
      return response.data!;
    } else {
      throw Exception(response.errorMessage ?? 'Error descargando archivo');
    }
  }
}