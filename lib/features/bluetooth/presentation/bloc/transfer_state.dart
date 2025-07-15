import 'package:bluetooth_per/core/data/source/operation.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

import '../models/archive_entry.dart';
import '../models/device.dart';

abstract class TransferState extends Equatable {
  const TransferState();

  @override
  List<Object?> get props => [];
}

class InitialSearchState extends TransferState {
  const InitialSearchState();
}

class PendingArchivesState extends TransferState {
  final List<String> dbPaths;
  const PendingArchivesState(this.dbPaths);

  @override
  List<Object?> get props => [dbPaths];
}

class SearchingState extends TransferState {
  const SearchingState();
}

class SearchingStateWithDevices extends TransferState {
  final List<Device> devices;
  const SearchingStateWithDevices(this.devices);

  @override
  List<Object?> get props => [devices];
}

class DeviceListState extends TransferState {
  final List<Device> devices;
  const DeviceListState(this.devices);

  @override
  List<Object?> get props => [devices];
}

class ConnectedState extends TransferState {
  final Device connectedDevice;
  final List<ArchiveEntry> archives;
  const ConnectedState({required this.connectedDevice, required this.archives});

  @override
  List<Object?> get props => [connectedDevice, archives];
}

class DownloadingState extends TransferState {
  final Device connectedDevice;
  final ArchiveEntry entry;

  final double progress;

  final String speedLabel;

  final int? fileSize;

  final double? elapsedTime;

  const DownloadingState({
    required this.connectedDevice,
    required this.entry,
    required this.progress,
    required this.speedLabel,
    this.fileSize,
    this.elapsedTime,
  });

  @override
  List<Object?> get props =>
      [connectedDevice, entry, progress, speedLabel, fileSize, elapsedTime];
}

class TableViewState extends TransferState {
  final Device connectedDevice;
  final ArchiveEntry entry;
  final List<dynamic> rows;
  final List<Operation> operations;
  final bool isLoading;
  final bool disabled;
  const TableViewState({
    required this.connectedDevice,
    required this.entry,
    required this.rows,
    required this.operations,
    this.isLoading = false,
    this.disabled = false,
  });

  @override
  List<Object?> get props =>
      [connectedDevice, entry, rows, operations, isLoading, disabled];
}

class TableRowData extends Equatable {
  final DateTime date;
  final String wellId;
  const TableRowData({required this.date, required this.wellId});

  @override
  List<Object?> get props => [date, wellId];
}

class UploadingState extends TransferState {
  final Device connectedDevice;
  const UploadingState(this.connectedDevice);

  @override
  List<Object?> get props => [connectedDevice];
}

class RefreshingState extends TransferState {
  final Device connectedDevice;
  const RefreshingState(this.connectedDevice);

  @override
  List<Object?> get props => [connectedDevice];
}

class ExportingState extends TransferState {
  final double progress;
  final ArchiveEntry entry;
  final Device connectedDevice;
  final int? currentExportingOperationDt;
  const ExportingState(this.progress,
      {required this.entry,
      required this.connectedDevice,
      this.currentExportingOperationDt});

  @override
  List<Object?> get props =>
      [progress, entry, connectedDevice, currentExportingOperationDt];
}

class ExportSuccessState extends TransferState {
  const ExportSuccessState();
}


class NetErrorState extends TransferState {
  final String dbPath;
  const NetErrorState(this.dbPath);

  @override
  List<Object?> get props => [dbPath];
}

class BluetoothDisabledState extends TransferState {
  const BluetoothDisabledState();
}

class InfoMessageState extends TransferState {
  final Widget content;
  final VoidCallback onButtonPressed;
  final String buttonText;

  const InfoMessageState({
    required this.content,
    required this.onButtonPressed,
    this.buttonText = 'ОК',
  });

  @override
  List<Object?> get props => [content, onButtonPressed, buttonText];
}
