import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:async';
import '../../../../core/data/main_data.dart';
import 'device_flow_state.dart';
import '../models/device.dart';
import '../models/archive_entry.dart';
import 'package:bluetooth_per/features/bluetooth/domain/repositories/bluetooth_repository.dart';
import 'package:bluetooth_per/features/bluetooth/domain/entities/bluetooth_device.dart';
import 'package:bluetooth_per/core/utils/archive_sync_manager.dart';
import 'package:bluetooth_per/core/utils/export_status_manager.dart'
   ;
import 'package:bluetooth_per/core/data/source/operation.dart';

class DeviceFlowCubit extends Cubit<DeviceFlowState> {
  final BluetoothRepository _repository;
  final MainData _mainData;
  final List<Device> _lastFoundDevices = [];
  bool _searching = false;

  DeviceFlowCubit(this._repository, this._mainData)
      : super(const InitialSearchState()) {
    _loadPending();
  }

  Future<void> _loadPending() async {
    final pending = await ArchiveSyncManager.getPending();
    if (pending.isNotEmpty) {
      emit(PendingArchivesState(pending));
    } else {
      emit(const InitialSearchState());
    }
  }

  // Генерация случайного номера телефона для связи
  String _generateRandomPhoneNumber() {
    final random = Random();
    final phoneNumbers = [
      '+7 (123) 456-78-90',
      '+7 (987) 654-32-10',
      '+7 (555) 123-45-67',
      '+7 (999) 888-77-66',
      '+7 (777) 222-33-44',
    ];
    return phoneNumbers[random.nextInt(phoneNumbers.length)];
  }

  // Создание виджета ошибки ТМС сервера
  Widget _createTmsErrorWidget() {
    final phoneNumber = _generateRandomPhoneNumber();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.wifi_off,
          size: 64,
          color: Colors.orange,
        ),
        const SizedBox(height: 16),
        const Text(
          'Нет ответа от ТМС',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF222222),
          ),
        ),
        const SizedBox(height: 16),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            'Возможно сервер не был запущен на устройстве ТМС, либо нет подключения к серверу.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF5F5F5F),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Контактный телефон:',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          phoneNumber,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: Color(0xFF0B78CC),
          ),
        ),
      ],
    );
  }

  // Helper: convert bytes/sec to human-readable label.
  String _formatSpeed(double bytesPerSec) {
    if (bytesPerSec < 1024) {
      return '${bytesPerSec.toStringAsFixed(0)} B/s';
    }
    final kB = bytesPerSec / 1024;
    if (kB < 1024) return '${kB.toStringAsFixed(1)} KB/s';
    final mB = kB / 1024;
    return '${mB.toStringAsFixed(1)} MB/s';
  }

  BluetoothDeviceEntity _toEntity(Device d) =>
      BluetoothDeviceEntity(address: d.macAddress, name: d.name);

  Device _toUi(BluetoothDeviceEntity e) =>
      Device(name: e.name ?? '', macAddress: e.address);

  // Start scanning for Bluetooth devices using the repository.
  Future<void> startScanning() async {
    _searching = true;
    emit(const SearchingState());

    _lastFoundDevices.clear();
    final result = await _repository.scanForDevices(
      onDeviceFound: (entity) {
        if (!_searching) return;
        final device = _toUi(entity);
        if (!_lastFoundDevices.any((d) => d.macAddress == device.macAddress)) {
          _lastFoundDevices.add(device);
          emit(SearchingStateWithDevices(List<Device>.from(_lastFoundDevices)));
        }
      },
    );

    result.fold(
      (failure) {
        if (!_searching) return;
        _searching = false;
        emit(const InitialSearchState());
      },
      (entities) {
        if (!_searching) return;
        final devices = entities.map(_toUi).toList();
        _lastFoundDevices.clear();
        _lastFoundDevices.addAll(devices);
        _searching = false;
        if (devices.isEmpty) {
          emit(const InitialSearchState());
        } else {
          emit(DeviceListState(devices));
        }
      },
    );
  }

  Future<void> connectToDevice(Device device) async {
    _searching = false;
    _repository.cancelScan();
    print(
        '[DeviceFlowCubit] connectToDevice: ${device.name} (${device.macAddress})');
    emit(UploadingState(device));

    try {
      final connectRes = await _repository
          .connectToDevice(_toEntity(device))
          .timeout(const Duration(seconds: 20));

      bool connected = false;
      connectRes.fold(
        (failure) {
          emit(ExceptionState(
            infoWidget: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.bluetooth_disabled,
                  size: 64,
                  color: Colors.red,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Ошибка подключения',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF222222),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    'Не удалось подключиться к устройству ${device.name}.\n Убедитесь, что устройство ТМС включено и находится в зоне действия.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Color(0xFF5F5F5F),
                    ),
                  ),
                ),
              ],
            ),
            onOkPressed: () {
              emit(DeviceListState(_lastFoundDevices));
            },
          ));
        },
        (_) {
          print('[DeviceFlowCubit] connectToDevice: success');
          connected = true;
        },
      );

      if (!connected) return;

      // Timeout на обновление архива (60 секунд)
      await for (final status in _repository.requestArchiveUpdate()) {
        if (status == 'ARCHIVE_UPDATING') {
          emit(RefreshingState(device));
        } else if (status == 'ARCHIVE_READY') {
          break;
        }
      }

      final listRes =
          await _repository.getReadyArchive().timeout(const Duration(seconds: 15));

      listRes.fold(
        (failure) {
          emit(ExceptionState(
            infoWidget: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.folder_off,
                  size: 64,
                  color: Colors.orange,
                ),
                SizedBox(height: 16),
                Text(
                  'Ошибка получения списка файлов',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF222222),
                  ),
                ),
                SizedBox(height: 16),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    'Не удалось получить список архивов с устройства. Попробуйте подключиться снова.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Color(0xFF5F5F5F),
                    ),
                  ),
                ),
              ],
            ),
            onOkPressed: () {
              emit(DeviceListState(_lastFoundDevices));
            },
          ));
        },
        (fileNames) {
          final archives = fileNames
              .map((f) => ArchiveEntry(fileName: f, sizeBytes: 0))
              .toList();
          print(
              '[DeviceFlowCubit] connectToDevice: got ${archives.length} archives');
          emit(ConnectedState(connectedDevice: device, archives: archives));
        },
      );
    } catch (e) {
      print('[DeviceFlowCubit] connectToDevice: timeout or error=$e');
      final isTimeout = e.toString().contains('TimeoutException');
      emit(ExceptionState(
        infoWidget: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isTimeout ? Icons.timer_off : Icons.error_outline,
              size: 64,
              color: Colors.orange,
            ),
            const SizedBox(height: 16),
            Text(
              isTimeout ? 'Время ожидания истекло' : 'Ошибка подключения',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF222222),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                isTimeout
                    ? 'Превышено время ожидания ответа от устройства. Попробуйте подключиться снова.'
                    : 'Произошла ошибка при подключении к устройству. Попробуйте снова.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  color: Color(0xFF5F5F5F),
                ),
              ),
            ),
          ],
        ),
        onOkPressed: () {
          emit(DeviceListState(_lastFoundDevices));
        },
      ));
    }
  }

  // Download selected archive using repository and update UI with progress.
  Future<void> downloadArchive(ArchiveEntry entry) async {
    print('[DeviceFlowCubit] downloadArchive: ${entry.fileName}');
    if (state is! ConnectedState) {
      print(
          '[DeviceFlowCubit] downloadArchive: not in ConnectedState, current=$state');
      return;
    }

    final connectedDevice = (state as ConnectedState).connectedDevice;

    final startTime = DateTime.now();
    int? totalFileSize;

    emit(DownloadingState(
      connectedDevice: connectedDevice,
      entry: entry,
      progress: 0,
      speedLabel: '0 B/s',
      fileSize: null,
      elapsedTime: null,
    ));

    final downloadRes = await _repository.downloadFile(
      entry.fileName,
      _toEntity(connectedDevice),
      onProgress: (progress, totalBytes) {
        final elapsed =
            DateTime.now().difference(startTime).inMilliseconds / 1000.0;
        final received = (totalBytes ?? 0) * progress;
        final speed = elapsed > 0 ? received / elapsed : 0.0;
        final speedLabel = _formatSpeed(speed);
        if (totalBytes != null) totalFileSize = totalBytes;
        emit(DownloadingState(
          connectedDevice: connectedDevice,
          entry: entry,
          progress: progress,
          speedLabel: speedLabel,
          fileSize: totalFileSize,
          elapsedTime: elapsed,
        ));
      },
      onComplete: (filePath) async {
        print(
            '[DeviceFlowCubit] downloadArchive: onComplete filePath=$filePath');
        await _handleDownloadedDb(filePath, entry, connectedDevice);
      },
    );

    downloadRes.fold(
      (failure) {
        print('[DeviceFlowCubit] downloadArchive: failure=$failure');
        emit(ExceptionState(
          infoWidget: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_download,
                size: 64,
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              const Text(
                'Ошибка загрузки',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF222222),
                ),
              ),
              const SizedBox(height: 16),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  'Не удалось загрузить архив с устройства. Проверьте соединение и попробуйте снова.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF5F5F5F),
                  ),
                ),
              ),
            ],
          ),
          onOkPressed: () {
            emit(DeviceListState(_lastFoundDevices));
          },
        ));
      },
      (_) {},
    );
  }

  // Process downloaded SQLite database and show table.
  Future<void> _handleDownloadedDb(
      String filePath, ArchiveEntry entry, Device connectedDevice) async {
    print('[DeviceFlowCubit] _handleDownloadedDb: filePath=$filePath');
    _mainData.dbPath = filePath;
    _mainData.resetOperationData();

    // Сразу показываем таблицу с isLoading=true
    emit(TableViewState(
      connectedDevice: connectedDevice,
      entry: entry,
      rows: const [],
      operations: _mainData.operations.toList(),
      isLoading: true,
    ));

    final localStatus = await _mainData.awaitOperations();
    print(
        '[DeviceFlowCubit] _handleDownloadedDb: awaitOperations status = $localStatus');

    if (localStatus == OperStatus.dbError) {
      emit(ExceptionState(
        infoWidget: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            const Text(
              'Ошибка базы данных',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF222222),
              ),
            ),
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Файл не является базой данных или повреждён.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF5F5F5F),
                ),
              ),
            ),
          ],
        ),
        onOkPressed: () {
          reset();
        },
      ));
      return;
    }
    if (localStatus == OperStatus.filePathError) {
      emit(ExceptionState(
        infoWidget: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.folder_off,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            const Text(
              'Ошибка файла',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF222222),
              ),
            ),
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Не выбран файл базы данных.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF5F5F5F),
                ),
              ),
            ),
          ],
        ),
        onOkPressed: () {
          reset();
        },
      ));
      return;
    }
    if (localStatus != OperStatus.ok) {
      emit(ExceptionState(
        infoWidget: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.warning_amber,
              size: 64,
              color: Colors.orange,
            ),
            const SizedBox(height: 16),
            const Text(
              'Неизвестная ошибка',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF222222),
              ),
            ),
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Неизвестная ошибка при открытии базы данных.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF5F5F5F),
                ),
              ),
            ),
          ],
        ),
        onOkPressed: () {
          reset();
        },
      ));
      return;
    }

    for (final op in _mainData.operations) {
      await _mainData.awaitOperationPoints(op);
    }

    final netStatus = await _mainData.awaitOperationsCanSendStatus();

    final filteredOps = _mainData.operations
        .where((op) => op.canSend == true || op.exported == true)
        .toList();
    final rows = filteredOps.map((op) {
      final dt = DateTime.fromMillisecondsSinceEpoch(op.dt * 1000);
      final wellId = op.hole;
      return TableRowData(date: dt, wellId: wellId);
    }).toList();

    print(
        '[DeviceFlowCubit] _handleDownloadedDb: emitting TableViewState with \x1b[32m${rows.length}\x1b[0m rows');
    emit(TableViewState(
      connectedDevice: connectedDevice,
      entry: entry,
      rows: rows,
      operations: filteredOps,
      isLoading: false,
    ));

    // Обновляем таблицу после синхронизации с сервером
    notifyTableChanged();

    if (netStatus != OperStatus.ok) {
      // Нет сети – помечаем архив как «ожидающий» и показываем ошибку
      print(
          '[DeviceFlowCubit] _handleDownloadedDb: netStatus not ok, marking as pending');
      await ArchiveSyncManager.addPending(filePath);

      emit(ExceptionState(
        infoWidget: _createTmsErrorWidget(),
        onOkPressed: () {
          emit(DeviceListState(_lastFoundDevices));
        },
      ));
    }
  }

  // Reset to initial.
  void reset() {
    _searching = false;
    print('[DeviceFlowCubit] reset called');
    _loadPending();
  }

  /// Загружает локальный архив без подключения к устройству.
  Future<void> loadLocalArchive(String dbPath) async {
    _mainData.dbPath = dbPath;
    _mainData.resetOperationData();

    // Сразу показываем таблицу с isLoading=true
    emit(TableViewState(
      connectedDevice: Device(name: 'Local', macAddress: ''),
      entry: ArchiveEntry(fileName: dbPath, sizeBytes: 0),
      rows: const [],
      operations: _mainData.operations.toList(),
      isLoading: true,
    ));

    final status = await _mainData.awaitOperations();

    if (status == OperStatus.dbError) {
      emit(ExceptionState(
        infoWidget: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            const Text(
              'Ошибка базы данных',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF222222),
              ),
            ),
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Файл не является базой данных или повреждён.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF5F5F5F),
                ),
              ),
            ),
          ],
        ),
        onOkPressed: () {
          reset();
        },
      ));
      return;
    }
    if (status == OperStatus.filePathError) {
      emit(ExceptionState(
        infoWidget: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.folder_off,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            const Text(
              'Ошибка файла',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF222222),
              ),
            ),
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Не выбран файл базы данных.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF5F5F5F),
                ),
              ),
            ),
          ],
        ),
        onOkPressed: () {
          reset();
        },
      ));
      return;
    }
    if (status != OperStatus.ok) {
      emit(ExceptionState(
        infoWidget: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.warning_amber,
              size: 64,
              color: Colors.orange,
            ),
            const SizedBox(height: 16),
            const Text(
              'Неизвестная ошибка',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF222222),
              ),
            ),
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Неизвестная ошибка при открытии базы данных.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF5F5F5F),
                ),
              ),
            ),
          ],
        ),
        onOkPressed: () {
          reset();
        },
      ));
      return;
    }

    for (final op in _mainData.operations) {
      await _mainData.awaitOperationPoints(op);
    }

    final netStatus = await _mainData.awaitOperationsCanSendStatus();

    final filteredOps = _mainData.operations
        .where((op) => op.canSend == true || op.exported == true)
        .toList();
    final rows = filteredOps.map((op) {
      final dt = DateTime.fromMillisecondsSinceEpoch(op.dt * 1000);
      return TableRowData(date: dt, wellId: op.hole);
    }).toList();

    emit(TableViewState(
      connectedDevice: Device(name: 'Local', macAddress: ''),
      entry: ArchiveEntry(fileName: dbPath, sizeBytes: 0),
      rows: rows,
      operations: filteredOps,
      isLoading: false,
    ));

    // Обновляем таблицу после синхронизации с сервером
    notifyTableChanged();

    if (netStatus != OperStatus.ok) {
      emit(ExceptionState(
        infoWidget: _createTmsErrorWidget(),
        onOkPressed: () async {
          // Возвращаемся к таблице и пробуем снова
          await loadLocalArchive(dbPath);
        },
      ));
    }
  }

  /// Экспорт отмеченных операций на сервер соStatus
  Future<void> exportSelected(
      {void Function(double progress)? onProgress,
      void Function()? onFinish}) async {
    if (state is! TableViewState) {
      print('[exportSelected] Not in TableViewState, current: $state');
      return;
    }

    final prevState = state as TableViewState;
    final connectedDevice = prevState.connectedDevice;
    final entry = prevState.entry;
    final rows = prevState.rows;

    final selected =
        _mainData.operations.where((op) => op.selected && op.canSend).toList();

/*     for (final op in selected) {
      await _mainData.awaitOperationPoints(op);
    } */

    if (selected.isEmpty) {
      emit(TableViewState(
        connectedDevice: connectedDevice,
        entry: entry,
        rows: rows,
        operations: _mainData.operations.toList(),
        isLoading: false,
      ));
      return;
    }

    int done = 0;
    bool hasSuccess = false;
    print('[exportSelected] Start export loop');

    final archiveFileName = _mainData.dbPath.split('/').last;
    final exportedOps = <int>[];

    // --- Новый прогресс по точкам операций ---
    final totalPoints =
        selected.fold<int>(0, (sum, op) => sum + op.points.length);
    int exportedPoints = 0;
    print('[exportSelected] totalPoints = '
        '\x1b[32m$totalPoints\u001b[0m');

    emit(ExportingState(0, entry: entry, connectedDevice: connectedDevice));

    List<Operation> currentOps = _mainData.operations
        .map((op) => Operation(
              dt: op.dt,
              dtStop: op.dtStop,
              maxP: op.maxP,
              idOrg: op.idOrg,
              workType: op.workType,
              ngdu: op.ngdu,
              field: op.field,
              section: op.section,
              bush: op.bush,
              hole: op.hole,
              brigade: op.brigade,
              lat: op.lat,
              lon: op.lon,
              equipment: op.equipment,
              pCnt: op.pCnt,
              points: op.points,
            )
              ..selected = op.selected
              ..canSend = op.canSend
              ..checkError = false)
        .toList();

    for (int i = 0; i < selected.length; i++) {
      final op = selected[i];
      final code = await _mainData.awaitSendingOperation(op);
      final idx = currentOps.indexWhere((o) => o.dt == op.dt);
      if (idx != -1) {
        if (code == 200) {
          hasSuccess = true;
          done++;
          currentOps[idx] = Operation(
            dt: op.dt,
            dtStop: op.dtStop,
            maxP: op.maxP,
            idOrg: op.idOrg,
            workType: op.workType,
            ngdu: op.ngdu,
            field: op.field,
            section: op.section,
            bush: op.bush,
            hole: op.hole,
            brigade: op.brigade,
            lat: op.lat,
            lon: op.lon,
            equipment: op.equipment,
            pCnt: op.pCnt,
            points: op.points,
          )
            ..selected = false
            ..canSend = false
            ..checkError = false
            ..exported = true
            ..unavailable = false
            ..errorCode = 0;
          exportedOps.add(op.dt);
          await ExportStatusManager.addExportedOp(archiveFileName, op.dt);
        } else {
          currentOps[idx] = Operation(
            dt: op.dt,
            dtStop: op.dtStop,
            maxP: op.maxP,
            idOrg: op.idOrg,
            workType: op.workType,
            ngdu: op.ngdu,
            field: op.field,
            section: op.section,
            bush: op.bush,
            hole: op.hole,
            brigade: op.brigade,
            lat: op.lat,
            lon: op.lon,
            equipment: op.equipment,
            pCnt: op.pCnt,
            points: op.points,
          )
            ..selected = op.selected
            ..canSend = op.canSend
            ..checkError = true
            ..exported = false
            ..unavailable = false
            ..errorCode = code;
        }
      }
      exportedPoints += op.points.length;
      final prog = totalPoints == 0 ? 1.0 : exportedPoints / totalPoints;
      emit(ExportingState(
        prog,
        entry: entry,
        connectedDevice: connectedDevice,
      ));
      if (onProgress != null) onProgress(prog);
      // Обновляем таблицу после каждой операции, но блокируем UI
      emit(TableViewState(
        connectedDevice: connectedDevice,
        entry: entry,
        rows: rows,
        operations: currentOps,
        isLoading: false,
        disabled: true,
      ));
    }
    // После завершения экспорта — разблокируем UI
    emit(TableViewState(
      connectedDevice: connectedDevice,
      entry: entry,
      rows: rows,
      operations: currentOps,
      isLoading: false,
      disabled: false,
    ));
    onProgress!(0);
    // После экспорта обновляем основной список операций
    _mainData.operations
      ..clear()
      ..addAll(currentOps);

    final allOpDts = currentOps.map((op) => op.dt).toList();
    final allExported = currentOps.every((op) => !op.canSend);
    if (allExported) {
      await ArchiveSyncManager.markExported(_mainData.dbPath);
      await ExportStatusManager.setArchiveStatus(
          archiveFileName, 'exported', allOpDts);
    } else {
      await ExportStatusManager.setArchiveStatus(
          archiveFileName, 'partial', allOpDts);
    }

    // Сбросить прогресс
    emit(TableViewState(
      connectedDevice: connectedDevice,
      entry: entry,
      rows: rows,
      operations: currentOps,
      isLoading: false,
    ));
    // Обновляем таблицу после экспорта
    notifyTableChanged();

    if (onFinish != null) onFinish();
  }

  void notifyTableChanged() {
    if (state is TableViewState) {
      final s = state as TableViewState;
      final filteredOps = _mainData.operations
          .where((op) => op.canSend == true || op.exported == true)
          .toList();
      final rows = filteredOps.map((op) {
        final dt = DateTime.fromMillisecondsSinceEpoch(op.dt * 1000);
        return TableRowData(date: dt, wellId: op.hole);
      }).toList();
      emit(TableViewState(
        connectedDevice: s.connectedDevice,
        entry: s.entry,
        rows: rows,
        operations: filteredOps,
        isLoading: false,
      ));
    }
  }

  void updateOperations(List<Operation> ops) {
    _mainData.operations
      ..clear()
      ..addAll(ops);
    if (state is TableViewState) {
      final s = state as TableViewState;
      final filteredOps =
          ops.where((op) => op.canSend == true || op.exported == true).toList();
      final rows = filteredOps.map((op) {
        final dt = DateTime.fromMillisecondsSinceEpoch(op.dt * 1000);
        return TableRowData(date: dt, wellId: op.hole);
      }).toList();
      emit(TableViewState(
        connectedDevice: s.connectedDevice,
        entry: s.entry,
        rows: rows,
        operations: filteredOps,
        isLoading: false,
      ));
    }
  }

  void stopScanning() {
    _searching = false;
    _repository.cancelScan();
    emit(DeviceListState(List<Device>.from(_lastFoundDevices)));
  }

  // Удаляет архив из списка ожидающих экспорта
  Future<void> deletePendingArchive(String path) async {
    print('[DeviceFlowCubit] deletePendingArchive: $path');
    await ArchiveSyncManager.deletePending(path);
    // Перезагружаем список ожидающих архивов
    await _loadPending();
  }
}
