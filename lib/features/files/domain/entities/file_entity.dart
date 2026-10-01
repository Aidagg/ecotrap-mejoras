class FileEntity {
  final String name;
  final int size;

  FileEntity({
    required this.name,
    required this.size,
  });

  String get sizeFormatted {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String get extension {
    final parts = name.split('.');
    return parts.length > 1 ? parts.last.toUpperCase() : 'DESCONOCIDO';
  }

  bool get isImage {
    final ext = extension.toLowerCase();
    return ['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext);
  }

  bool get isJson => extension.toLowerCase() == 'json';
}