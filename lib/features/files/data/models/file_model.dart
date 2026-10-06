import '../../domain/entities/file_entity.dart';

class FileModel extends FileEntity {
  FileModel({
    required super.name,
    required super.size,
  });

  factory FileModel.fromJson(Map<String, dynamic> json) {
    return FileModel(
      name: json['name'] as String,
      size: json['size'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'size': size,
    };
  }
}