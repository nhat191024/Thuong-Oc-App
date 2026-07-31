import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:pusher_client_socket/pusher_client_socket.dart';

import '../../core/api/api_service.dart';
import '../../core/config/app_config.dart';
import '../../core/services/printer_service.dart';
import '../../data/models/print_station.dart';

class PrintStationController extends GetxController {
  static const localPrinterId = -1;

  final ApiService _apiService = ApiService();
  final GetStorage _storage = GetStorage();
  final PrinterService _printerService = Get.find<PrinterService>();

  final printers = <PrintStationPrinter>[].obs;
  final jobs = <PrintJob>[].obs;
  final selectedPrinterId = RxnInt(localPrinterId);
  final isTestingPrinter = false.obs;
  final isProcessingQueue = false.obs;
  final isQueuePaused = false.obs;
  final currentPrintingJobKey = RxnString();
  final failedJobKeys = <String>{}.obs;
  final isLoading = true.obs;
  final connectionStatus = 'Đang kết nối'.obs;
  final errorMessage = RxnString();

  PusherClient? _client;
  PrivateChannel? _channel;
  bool _isLoadingStation = false;
  String _selectionBranchId = 'default';
  String? _lastDebugAuthSocketId;
  final Set<String> _knownRequestIds = {};

  static const PrintStationPrinter localPrinter = PrintStationPrinter(
    id: localPrinterId,
    name: 'Máy in của thiết bị này',
    connection: PrinterConnection(
      type: 'local',
      host: '',
      port: 0,
      timeoutSeconds: 3,
    ),
  );

  @override
  void onInit() {
    super.onInit();
    loadStation();
  }

  Future<void> loadStation() async {
    if (_isLoadingStation) {
      debugPrint('[PrintStation] Bỏ qua loadStation vì đang tải');
      return;
    }
    _isLoadingStation = true;
    isLoading.value = true;
    errorMessage.value = null;
    connectionStatus.value = 'Đang kết nối';
    _disconnect();

    try {
      final branchId = _storage.read('selected_branch');
      if (branchId == null || branchId.toString().isEmpty) {
        throw const FormatException('Chưa chọn cơ sở để tải máy in');
      }
      final encodedBranchId = Uri.encodeComponent(branchId.toString());
      final response = await _apiService.dio.get(
        '/print-station/printers/$encodedBranchId',
      );
      final body = Map<String, dynamic>.from(response.data as Map);
      final printerData = body['data'] as List? ?? const [];
      final metaData = Map<String, dynamic>.from(
        body['meta'] as Map? ?? const {},
      );

      printers.assignAll(
        printerData.map(
          (item) => PrintStationPrinter.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        ),
      );

      final meta = PrintStationMeta.fromJson(metaData);
      _restorePrinterSelection(meta.branchId);
      _connect(meta);
    } catch (error) {
      debugPrint('Print station load error: $error');
      errorMessage.value = 'Không thể tải thông tin trạm in: $error';
      connectionStatus.value = 'Mất kết nối';
    } finally {
      isLoading.value = false;
      _isLoadingStation = false;
    }
  }

  PrintStationPrinter? get selectedPrinter {
    final printerId = selectedPrinterId.value;
    if (printerId == null) return null;

    for (final printer in availablePrinters) {
      if (printer.id == printerId) return printer;
    }
    return null;
  }

  List<PrintStationPrinter> get availablePrinters {
    return [localPrinter, ...printers];
  }

  Future<void> selectPrinter(PrintStationPrinter printer) async {
    selectedPrinterId.value = printer.id;
    await _storage.write(_printerStorageKey(_selectionBranchId), printer.id);
    retryPrintQueue();
  }

  Future<void> testSelectedPrinter() async {
    if (isProcessingQueue.value) {
      Get.snackbar('Máy in đang bận', 'Vui lòng chờ hàng đợi hiện tại in xong');
      return;
    }

    final printer = selectedPrinter;
    if (printer == null) {
      Get.snackbar('Chưa chọn máy in', 'Vui lòng chọn máy in cần test');
      return;
    }

    isTestingPrinter.value = true;
    try {
      final connection = printer.connection;
      debugPrint(
        '[PrintStation][TestPrint] Đang kết nối'
        ' | printer_id=${printer.id}'
        ' | type=${connection.type}'
        '${connection.type == 'network' ? ' | address=${connection.host}:${connection.port}' : ''}',
      );

      final testContent = [
        'THUONG OC',
        'PRINT TEST SUCCESS',
        '-------------------------------',
        'Printer: ${_removeVietnameseDiacritics(printer.name)}',
        'Address: ${connection.host}:${connection.port}',
        'Time: ${DateTime.now().toIso8601String()}',
        '-------------------------------',
        '',
        '',
        '',
      ].join('\n');

      if (printer.id == localPrinterId) {
        await _printerService.printStationTest();
      } else {
        await _sendToNetworkPrinter(printer, utf8.encode(testContent));
      }

      debugPrint(
        '[PrintStation][TestPrint] In thử thành công'
        ' | printer_id=${printer.id}',
      );
      Get.snackbar('Thành công', 'Đã gửi lệnh in thử đến ${printer.name}');
    } catch (error) {
      debugPrint(
        '[PrintStation][TestPrint] In thử thất bại'
        ' | printer_id=${printer.id}'
        ' | error=$error',
      );
      Get.snackbar('In thử thất bại', error.toString());
    } finally {
      isTestingPrinter.value = false;
      unawaited(_processPrintQueue());
    }
  }

  void retryPrintQueue() {
    isQueuePaused.value = false;
    failedJobKeys.clear();
    unawaited(_processPrintQueue());
  }

  bool isJobPrinting(PrintJob job) {
    return currentPrintingJobKey.value == _jobKey(job);
  }

  bool didJobFail(PrintJob job) {
    return failedJobKeys.contains(_jobKey(job));
  }

  Future<void> _processPrintQueue() async {
    if (isProcessingQueue.value ||
        isTestingPrinter.value ||
        isQueuePaused.value ||
        jobs.isEmpty) {
      return;
    }

    isProcessingQueue.value = true;
    try {
      while (jobs.isNotEmpty && !isQueuePaused.value) {
        final job = jobs.first;
        final jobKey = _jobKey(job);
        final printer = selectedPrinter;
        currentPrintingJobKey.value = jobKey;

        if (printer == null) {
          isQueuePaused.value = true;
          failedJobKeys.add(jobKey);
          debugPrint(
            '[PrintStation][Queue] Tạm dừng vì chưa chọn máy in'
            ' | request_id=${job.requestId}',
          );
          break;
        }

        try {
          debugPrint(
            '[PrintStation][Queue] Bắt đầu in'
            ' | request_id=${job.requestId}'
            ' | printer_id=${printer.id}'
            ' | remaining=${jobs.length}',
          );
          if (printer.id == localPrinterId) {
            await _printerService.printStationJob(job);
          } else {
            await _sendToNetworkPrinter(printer, _buildJobReceipt(job));
          }
          jobs.remove(job);
          failedJobKeys.remove(jobKey);
          debugPrint(
            '[PrintStation][Queue] In thành công'
            ' | request_id=${job.requestId}'
            ' | remaining=${jobs.length}',
          );
        } catch (error) {
          isQueuePaused.value = true;
          failedJobKeys.add(jobKey);
          debugPrint(
            '[PrintStation][Queue] In thất bại, đã dừng hàng đợi'
            ' | request_id=${job.requestId}'
            ' | error=$error',
          );
          Get.snackbar('Không thể in đơn', 'Hàng đợi đã tạm dừng: $error');
        } finally {
          currentPrintingJobKey.value = null;
        }
      }
    } finally {
      isProcessingQueue.value = false;
    }
  }

  List<int> _buildJobReceipt(PrintJob job) {
    final bytes = BytesBuilder();

    // Header divider only.
    bytes.add(const [0x1B, 0x61, 0x01]);
    bytes.add(utf8.encode('--------------------------------\n'));

    // Use 3x and wrap text before the printer can split a word by itself.
    bytes.add(const [0x1D, 0x21, 0x22]);
    bytes.add(
      utf8.encode(
        '${_wrapReceiptText('Ban: ${_removeVietnameseDiacritics(job.tableNumber)}')}\n',
      ),
    );
    bytes.add(const [0x1B, 0x45, 0x01]);
    bytes.add(
      utf8.encode(
        '${_wrapReceiptText('${_formatQuantity(job.quantity)} x '
        '${_removeVietnameseDiacritics(job.dishName)}')}\n',
      ),
    );
    bytes.add(const [0x1B, 0x45, 0x00]);
    if (job.cookingMethod.isNotEmpty) {
      bytes.add(
        utf8.encode(
          '${_wrapReceiptText('Che bien: ${_removeVietnameseDiacritics(job.cookingMethod)}')}\n',
        ),
      );
    }
    if (job.note.isNotEmpty) {
      bytes.add(const [0x1B, 0x45, 0x01]);
      bytes.add(
        utf8.encode(
          '${_wrapReceiptText('Ghi chu: ${_removeVietnameseDiacritics(job.note)}')}\n',
        ),
      );
      bytes.add(const [0x1B, 0x45, 0x00]);
    }

    // Restore normal size for the divider, then feed paper before cutting.
    bytes.add(const [0x1D, 0x21, 0x00]);
    bytes.add(utf8.encode('--------------------------------\n'));
    bytes.add(const [0x1B, 0x64, 0x03]);
    return bytes.takeBytes();
  }

  Future<void> _sendToNetworkPrinter(
    PrintStationPrinter printer,
    List<int> content,
  ) async {
    final connection = printer.connection;
    if (connection.type.toLowerCase() != 'network') {
      throw UnsupportedError('Chỉ hỗ trợ máy in kết nối network');
    }
    if (connection.host.isEmpty || connection.port <= 0) {
      throw const FormatException('Địa chỉ IP hoặc port máy in không hợp lệ');
    }

    final timeout = Duration(seconds: connection.timeoutSeconds);
    Socket? socket;
    try {
      socket = await Socket.connect(
        connection.host,
        connection.port,
        timeout: timeout,
      );
      socket.add(const [0x1B, 0x40]);
      socket.add(content);
      socket.add(const [0x1D, 0x56, 0x00]);
      await socket.flush().timeout(timeout);
      await socket.close().timeout(timeout);
      socket = null;
    } finally {
      socket?.destroy();
    }
  }

  String _formatQuantity(num value) {
    return value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toString();
  }

  String _removeVietnameseDiacritics(String value) {
    const characterGroups = <String, String>{
      'a': 'àáạảãâầấậẩẫăằắặẳẵ',
      'A': 'ÀÁẠẢÃÂẦẤẬẨẪĂẰẮẶẲẴ',
      'e': 'èéẹẻẽêềếệểễ',
      'E': 'ÈÉẸẺẼÊỀẾỆỂỄ',
      'i': 'ìíịỉĩ',
      'I': 'ÌÍỊỈĨ',
      'o': 'òóọỏõôồốộổỗơờớợởỡ',
      'O': 'ÒÓỌỎÕÔỒỐỘỔỖƠỜỚỢỞỠ',
      'u': 'ùúụủũưừứựửữ',
      'U': 'ÙÚỤỦŨƯỪỨỰỬỮ',
      'y': 'ỳýỵỷỹ',
      'Y': 'ỲÝỴỶỸ',
      'd': 'đ',
      'D': 'Đ',
    };

    var result = value;
    for (final entry in characterGroups.entries) {
      for (final character in entry.value.split('')) {
        result = result.replaceAll(character, entry.key);
      }
    }
    return result;
  }

  String _wrapReceiptText(String value, {int maxCharacters = 10}) {
    final words = value.trim().split(RegExp(r'\s+'));
    final lines = <String>[];
    var currentLine = '';

    for (final word in words) {
      final candidate = currentLine.isEmpty ? word : '$currentLine $word';
      if (candidate.length <= maxCharacters) {
        currentLine = candidate;
        continue;
      }

      if (currentLine.isNotEmpty) {
        lines.add(currentLine);
        currentLine = '';
      }
      if (word.length <= maxCharacters) {
        currentLine = word;
        continue;
      }

      for (var start = 0; start < word.length; start += maxCharacters) {
        final end = (start + maxCharacters).clamp(0, word.length);
        final part = word.substring(start, end);
        if (end == word.length) {
          currentLine = part;
        } else {
          lines.add(part);
        }
      }
    }

    if (currentLine.isNotEmpty) {
      lines.add(currentLine);
    }
    return lines.join('\n');
  }

  String _jobKey(PrintJob job) {
    return job.requestId.isNotEmpty
        ? job.requestId
        : job.receivedAt.microsecondsSinceEpoch.toString();
  }

  void _restorePrinterSelection(int apiBranchId) {
    final branchId = apiBranchId > 0
        ? apiBranchId.toString()
        : (_storage.read('selected_branch')?.toString() ?? 'default');
    _selectionBranchId = branchId;
    final storedValue = _storage.read(_printerStorageKey(branchId));
    final storedId = int.tryParse(storedValue?.toString() ?? '');
    final isStoredPrinterAvailable = availablePrinters.any(
      (printer) => printer.id == storedId,
    );
    final currentId = selectedPrinterId.value;
    final isCurrentPrinterAvailable = availablePrinters.any(
      (printer) => printer.id == currentId,
    );

    final printerId = isStoredPrinterAvailable
        ? storedId!
        : isCurrentPrinterAvailable
        ? currentId!
        : printers.isNotEmpty
        ? printers.first.id
        : localPrinterId;
    selectedPrinterId.value = printerId;
    _storage.write(_printerStorageKey(branchId), printerId);
  }

  String _printerStorageKey(Object branchId) {
    return 'print_station_selected_printer_$branchId';
  }

  void _connect(PrintStationMeta meta) {
    AppConfig.validatePusher();
    final token = _storage.read<String>('access_token');
    final authEndpoint = Uri.parse(
      ApiService.baseUrl,
    ).resolve(meta.authEndpoint).toString();
    final privateChannel = _resolvePrivateChannel(meta);

    if (kDebugMode) {
      debugPrint(
        '[PrintStation][WebSocket][AUTH] Chuẩn bị xác thực private channel',
      );
      debugPrint(
        '[PrintStation][WebSocket][AUTH] Channel: private-$privateChannel',
      );
      debugPrint('[PrintStation][WebSocket][AUTH] Endpoint: $authEndpoint');
      debugPrint(
        '[PrintStation][WebSocket][AUTH] Bearer token: '
        '${token != null && token.isNotEmpty ? 'Có' : 'Không có'}',
      );
    }

    final client = PusherClient(
      options: PusherOptions(
        key: AppConfig.pusherAppKey,
        cluster: AppConfig.pusherCluster,
        host: AppConfig.pusherHost,
        wssPort: AppConfig.pusherWssPort,
        encrypted: true,
        activityTimeout: 30000,
        pongTimeout: 10000,
        autoConnect: false,
        authOptions: PusherAuthOptions(
          authEndpoint,
          headers: () async => {
            'Accept': 'application/json',
            if (token != null && token.isNotEmpty)
              'Authorization': 'Bearer $token',
          },
        ),
      ),
    );

    client.onConnecting((_) {
      if (!_isActiveClient(client)) return;
      connectionStatus.value = 'Đang kết nối';
    });
    client.onConnectionStateChange((state) {
      if (!_isActiveClient(client) || !kDebugMode) return;
      debugPrint(
        '[PrintStation][WebSocket][STATE] '
        '${state.runtimeType} | value=$state',
      );
    });
    client.onReconnecting((_) {
      if (!_isActiveClient(client)) return;
      debugPrint('[PrintStation][WebSocket] Đang tự kết nối lại');
      connectionStatus.value = 'Đang kết nối lại';
    });
    client.onReconnected((_) {
      if (!_isActiveClient(client)) return;
      debugPrint('[PrintStation][WebSocket] Transport đã kết nối lại');
      connectionStatus.value = 'Đang đăng ký lại kênh';
    });
    client.onConnectionEstablished((_) {
      if (!_isActiveClient(client)) return;
      debugPrint(
        '[PrintStation][WebSocket] Kết nối thành công'
        ' | socket_id=${client.socketId}'
        ' | host=${AppConfig.pusherHost}:${AppConfig.pusherWssPort}',
      );
      connectionStatus.value = 'Đang đăng ký nhận đơn';
      unawaited(
        _debugProbeChannelAuth(
          client: client,
          authEndpoint: authEndpoint,
          privateChannel: privateChannel,
        ),
      );
    });
    client.onConnectionError((error) {
      if (!_isActiveClient(client)) return;
      debugPrint('Print station connection error: $error');
      connectionStatus.value = 'Lỗi kết nối';
    });
    client.onError((error) {
      if (!_isActiveClient(client)) return;
      debugPrint(
        '[PrintStation][WebSocket][PUSHER_ERROR] '
        'type=${error.runtimeType} | error=$error',
      );
    });
    client.onDisconnected((data) {
      if (!_isActiveClient(client)) return;
      debugPrint(
        '[PrintStation][WebSocket][DISCONNECTED] '
        'type=${data.runtimeType} | data=$data',
      );
      connectionStatus.value = 'Mất kết nối';
    });

    final channel = client.private(privateChannel);
    channel.onSubscriptionSuccess((_) {
      if (!_isActiveClient(client)) return;
      debugPrint(
        '[PrintStation][WebSocket] Đăng ký channel thành công'
        ' | channel=${channel.name}'
        ' | event=${meta.event}',
      );
      connectionStatus.value = 'Đang nhận đơn';
      errorMessage.value = null;
    });
    channel.bind('pusher:error', (error) {
      if (!_isActiveClient(client)) return;
      debugPrint('Print station subscription error: $error');
      connectionStatus.value = 'Lỗi đăng ký kênh';
      errorMessage.value = error.toString();
    });
    channel.bind(meta.event, (payload) {
      if (kDebugMode) {
        debugPrint('==================================================');
        debugPrint('[PrintStation][WebSocket][DEBUG] Có đơn mới được gửi đến');
        debugPrint('[PrintStation][WebSocket][DEBUG] Channel: ${channel.name}');
        debugPrint('[PrintStation][WebSocket][DEBUG] Event: ${meta.event}');
        debugPrint('[PrintStation][WebSocket][DEBUG] Payload: $payload');
        debugPrint('==================================================');
      }
      _handlePrintJob(payload);
    });

    _client = client;
    _channel = channel;
    client.connect();
  }

  Future<void> _debugProbeChannelAuth({
    required PusherClient client,
    required String authEndpoint,
    required String privateChannel,
  }) async {
    if (!kDebugMode || !_isActiveClient(client)) return;

    final socketId = client.socketId;
    if (socketId == null || socketId.isEmpty) {
      debugPrint(
        '[PrintStation][WebSocket][AUTH_PROBE] Bỏ qua: chưa có socket_id',
      );
      return;
    }
    if (_lastDebugAuthSocketId == socketId) return;
    _lastDebugAuthSocketId = socketId;

    final channelName = 'private-$privateChannel';
    final stopwatch = Stopwatch()..start();
    debugPrint(
      '[PrintStation][WebSocket][AUTH_PROBE] POST $authEndpoint'
      ' | socket_id=$socketId | channel_name=$channelName',
    );

    try {
      final response = await _apiService.dio.post<dynamic>(
        authEndpoint,
        data: {'socket_id': socketId, 'channel_name': channelName},
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          validateStatus: (_) => true,
        ),
      );
      stopwatch.stop();
      debugPrint(
        '[PrintStation][WebSocket][AUTH_PROBE] Response'
        ' | status=${response.statusCode}'
        ' | elapsed_ms=${stopwatch.elapsedMilliseconds}'
        ' | data=${_sanitizeAuthResponse(response.data)}',
      );
    } on DioException catch (error) {
      stopwatch.stop();
      debugPrint(
        '[PrintStation][WebSocket][AUTH_PROBE] DioException'
        ' | type=${error.type}'
        ' | status=${error.response?.statusCode}'
        ' | elapsed_ms=${stopwatch.elapsedMilliseconds}'
        ' | message=${error.message}'
        ' | data=${_sanitizeAuthResponse(error.response?.data)}',
      );
    } catch (error, stackTrace) {
      stopwatch.stop();
      debugPrint(
        '[PrintStation][WebSocket][AUTH_PROBE] Exception'
        ' | elapsed_ms=${stopwatch.elapsedMilliseconds}'
        ' | error=$error',
      );
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  dynamic _sanitizeAuthResponse(dynamic data) {
    if (data is Map) {
      final sanitized = Map<String, dynamic>.from(data);
      if (sanitized.containsKey('auth')) sanitized['auth'] = '***';
      if (sanitized.containsKey('shared_secret')) {
        sanitized['shared_secret'] = '***';
      }
      return sanitized;
    }
    if (data is String) {
      try {
        return _sanitizeAuthResponse(jsonDecode(data));
      } catch (_) {
        return data.length > 500 ? '${data.substring(0, 500)}…' : data;
      }
    }
    return data;
  }

  String _resolvePrivateChannel(PrintStationMeta meta) {
    if (meta.pusherChannel.isNotEmpty) {
      return meta.pusherChannel.replaceFirst(RegExp(r'^private-'), '');
    }
    if (meta.channel.isNotEmpty) {
      return meta.channel.replaceFirst(RegExp(r'^private-'), '');
    }

    final storedBranchId = int.tryParse(
      _storage.read('selected_branch')?.toString() ?? '',
    );
    final branchId = meta.branchId > 0 ? meta.branchId : storedBranchId;
    if (branchId == null || branchId <= 0) {
      throw const FormatException(
        'Không xác định được branch_id để đăng ký private channel',
      );
    }
    return 'print-stations.$branchId';
  }

  void _handlePrintJob(dynamic payload) {
    try {
      dynamic decoded = payload;
      if (decoded is String) {
        decoded = jsonDecode(decoded);
      }
      if (decoded is! Map) {
        throw const FormatException('Payload không phải JSON object');
      }

      final data = Map<String, dynamic>.from(decoded);
      final rawJob = data['job'] ?? data;
      if (rawJob is! Map) {
        throw const FormatException('Payload không có dữ liệu job');
      }

      final job = PrintJob.fromJson(Map<String, dynamic>.from(rawJob));
      debugPrint(
        '[PrintStation][Job] Đã parse yêu cầu in'
        ' | request_id=${job.requestId}'
        ' | table=${job.tableNumber}'
        ' | dish=${job.dishName}'
        ' | quantity=${job.quantity}',
      );
      if (job.requestId.isNotEmpty &&
          _knownRequestIds.contains(job.requestId)) {
        debugPrint(
          '[PrintStation][Job] Bỏ qua yêu cầu trùng'
          ' | request_id=${job.requestId}',
        );
        return;
      }
      if (job.requestId.isNotEmpty) {
        _knownRequestIds.add(job.requestId);
        if (_knownRequestIds.length > 500) {
          _knownRequestIds.remove(_knownRequestIds.first);
        }
      }
      jobs.add(job);
      debugPrint(
        '[PrintStation][Queue] Đã thêm vào hàng đợi'
        ' | request_id=${job.requestId}'
        ' | queue_size=${jobs.length}',
      );
      unawaited(_processPrintQueue());
    } catch (error) {
      debugPrint('Invalid print job payload: $error');
      Get.snackbar('Lỗi', 'Không thể đọc yêu cầu in mới');
    }
  }

  void _disconnect() {
    final channel = _channel;
    final client = _client;
    _channel = null;
    _client = null;
    try {
      channel?.unsubscribe();
    } catch (_) {
      // The socket may already be closed.
    }
    try {
      client?.disconnect();
    } catch (_) {
      // The socket may not have finished connecting.
    }
  }

  bool _isActiveClient(PusherClient client) {
    return !isClosed && identical(_client, client);
  }

  @override
  void onClose() {
    _disconnect();
    super.onClose();
  }
}
