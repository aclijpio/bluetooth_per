import 'package:equatable/equatable.dart';

class DeviceModel extends Equatable {
  final String name;
  final String macAddress;
  final bool isConnected;

  const DeviceModel({
    required this.name,
    required this.macAddress,
    this.isConnected = false,
  });

  DeviceModel copyWith({
    String? name,
    String? macAddress,
    bool? isConnected,
  }) {
    return DeviceModel(
      name: name ?? this.name,
      macAddress: macAddress ?? this.macAddress,
      isConnected: isConnected ?? this.isConnected,
    );
  }

  @override
  List<Object?> get props => [name, macAddress, isConnected];
}

class ArchiveModel extends Equatable {
  final String fileName;
  final int sizeBytes;
  final DateTime? lastModified;

  const ArchiveModel({
    required this.fileName,
    required this.sizeBytes,
    this.lastModified,
  });

  String get formattedSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024)
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  List<Object?> get props => [fileName, sizeBytes, lastModified];
}

class OperationModel extends Equatable {
  final int id;
  final String name;
  final bool isSelected;
  final bool canExport;
  final bool isExported;
  final DateTime timestamp;

  const OperationModel({
    required this.id,
    required this.name,
    this.isSelected = false,
    this.canExport = true,
    this.isExported = false,
    required this.timestamp,
  });

  OperationModel copyWith({
    int? id,
    String? name,
    bool? isSelected,
    bool? canExport,
    bool? isExported,
    DateTime? timestamp,
  }) {
    return OperationModel(
      id: id ?? this.id,
      name: name ?? this.name,
      isSelected: isSelected ?? this.isSelected,
      canExport: canExport ?? this.canExport,
      isExported: isExported ?? this.isExported,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  List<Object?> get props =>
      [id, name, isSelected, canExport, isExported, timestamp];
}
