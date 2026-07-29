import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:pusher_client_socket/pusher_client_socket.dart';

import '../../core/api/api_service.dart';
import '../../data/models/print_station.dart';

class PrintStationController extends GetxController {
  static const _pusherKey =
      'UEhHTTBSbzB3VGZvNHJkd2tlRkRRb2Jib3RYTkhzTDdQNTlmdFYxRzRnU2swcXhhY3p1QU1MRXV2SUZWa3V6Zw==';
  static const _pusherHost = 'soketi-realtime.taiyo.fun';

  final ApiService _apiService = ApiService();
  final GetStorage _storage = GetStorage();

  final printers = <PrintStationPrinter>[].obs;
  final jobs = <PrintJob>[].obs;
  final selectedPrinterId = RxnInt();
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
  String _selectionBranchId = 'default';
  final Set<String> _knownRequestIds = {};

  @override
  void onInit() {
    super.onInit();
    loadStation();
  }

  Future<void> loadStation() async {
    isLoading.value = true;
    errorMessage.value = null;
    connectionStatus.value = 'Đang kết nối';
    _disconnect();

    try {
      final branchId = _storage.read('selected_branch');
      final response = await _apiService.dio.get(
        '/print-station/printers',
        queryParameters: {if (branchId != null) 'branch_id': branchId},
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
      if (meta.pusherChannel.isEmpty) {
        throw const FormatException(
          'API không trả về pusher_channel của trạm in',
        );
      }
      _connect(meta);
    } catch (error) {
      debugPrint('Print station load error: $error');
      errorMessage.value = 'Không thể tải thông tin trạm in: $error';
      connectionStatus.value = 'Mất kết nối';
    } finally {
      isLoading.value = false;
    }
  }

  PrintStationPrinter? get selectedPrinter {
    final printerId = selectedPrinterId.value;
    if (printerId == null) return null;

    for (final printer in printers) {
      if (printer.id == printerId) return printer;
    }
    return null;
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
        ' | address=${connection.host}:${connection.port}',
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

      await _sendToNetworkPrinter(printer, utf8.encode(testContent));

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
          await _sendToNetworkPrinter(printer, _buildJobReceipt(job));
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
    if (printers.isEmpty) {
      selectedPrinterId.value = null;
      return;
    }

    final branchId = apiBranchId > 0
        ? apiBranchId.toString()
        : (_storage.read('selected_branch')?.toString() ?? 'default');
    _selectionBranchId = branchId;
    final storedValue = _storage.read(_printerStorageKey(branchId));
    final storedId = int.tryParse(storedValue?.toString() ?? '');
    final isStoredPrinterAvailable = printers.any(
      (printer) => printer.id == storedId,
    );
    final currentId = selectedPrinterId.value;
    final isCurrentPrinterAvailable = printers.any(
      (printer) => printer.id == currentId,
    );

    final printerId = isStoredPrinterAvailable
        ? storedId!
        : isCurrentPrinterAvailable
        ? currentId!
        : printers.first.id;
    selectedPrinterId.value = printerId;
    _storage.write(_printerStorageKey(branchId), printerId);
  }

  String _printerStorageKey(Object branchId) {
    return 'print_station_selected_printer_$branchId';
  }

  void _connect(PrintStationMeta meta) {
    final token = _storage.read<String>('access_token');
    final authEndpoint = Uri.parse(
      ApiService.baseUrl,
    ).resolve(meta.authEndpoint).toString();

    final client = PusherClient(
      options: PusherOptions(
        key: _pusherKey,
        cluster: 'mt1',
        host: _pusherHost,
        wssPort: 443,
        encrypted: true,
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

    client.onConnecting((_) => connectionStatus.value = 'Đang kết nối');
    client.onConnectionEstablished((_) {
      debugPrint(
        '[PrintStation][WebSocket] Kết nối thành công'
        ' | socket_id=${client.socketId}'
        ' | host=$_pusherHost:443',
      );
      connectionStatus.value = 'Đang đăng ký nhận đơn';
    });
    client.onConnectionError((error) {
      debugPrint('Print station connection error: $error');
      connectionStatus.value = 'Lỗi kết nối';
    });
    client.onDisconnected((_) {
      if (!isClosed) connectionStatus.value = 'Mất kết nối';
    });

    final channel = client.private(meta.pusherChannel);
    channel.onSubscriptionSuccess((_) {
      debugPrint(
        '[PrintStation][WebSocket] Đăng ký channel thành công'
        ' | channel=${meta.pusherChannel}'
        ' | event=${meta.event}',
      );
      connectionStatus.value = 'Đang nhận đơn';
      errorMessage.value = null;
    });
    channel.bind('pusher:error', (error) {
      debugPrint('Print station subscription error: $error');
      connectionStatus.value = 'Lỗi đăng ký kênh';
      errorMessage.value = error.toString();
    });
    channel.bind(meta.event, _handlePrintJob);

    _client = client;
    _channel = channel;
    client.connect();
  }

  void _handlePrintJob(dynamic payload) {
    debugPrint('[PrintStation][WebSocket] Nhận yêu cầu in: $payload');
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
    try {
      _channel?.unsubscribe();
    } catch (_) {
      // The socket may already be closed.
    }
    try {
      _client?.disconnect();
    } catch (_) {
      // The socket may not have finished connecting.
    }
    _channel = null;
    _client = null;
  }

  @override
  void onClose() {
    _disconnect();
    super.onClose();
  }
}
