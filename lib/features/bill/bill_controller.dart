import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import '../../core/api/api_service.dart';
import '../../core/services/printer_service.dart';
import '../../data/models/table.dart';
import '../../data/models/bill.dart';
import 'payment_webview_screen.dart';
import '../table/table_list_screen.dart';
import '../auth/login_screen.dart';

class BillController extends GetxController {
  final ApiService _apiService = ApiService();
  final GetStorage _storage = GetStorage();

  final table = Rxn<TableModel>();
  final bill = Rxn<Bill>();
  final isLoading = false.obs;
  final isDeleting = false.obs;
  Timer? _billPollingTimer;
  bool _isFetchingBill = false;

  // Tab: 0 = Hiện tại, 1 = Lịch sử
  final selectedTab = 0.obs;

  // Bill history
  final historyItems = <BillHistoryItem>[].obs;
  final isHistoryLoading = false.obs;
  final isLoadingMore = false.obs;
  final _historyPage = 1.obs;
  final hasMoreHistory = true.obs;

  final ScrollController historyScrollController = ScrollController();

  @override
  void onClose() {
    _billPollingTimer?.cancel();
    historyScrollController.dispose();
    super.onClose();
  }

  @override
  void onInit() {
    super.onInit();
    if (Get.arguments is TableModel) {
      table.value = Get.arguments as TableModel;
      fetchBill();
      _startBillPolling();
    } else if (Get.arguments is String) {
      table.value = TableModel(
        id: Get.arguments as String,
        name: 'Bàn ${Get.arguments}',
        tableNumber: '...',
        isActive: '1',
      );
      fetchBill();
      _startBillPolling();
    }

    historyScrollController.addListener(() {
      if (historyScrollController.position.pixels >=
              historyScrollController.position.maxScrollExtent - 200 &&
          !isLoadingMore.value &&
          hasMoreHistory.value) {
        _loadMoreHistory();
      }
    });
  }

  void _startBillPolling() {
    _billPollingTimer?.cancel();
    _billPollingTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      fetchBill(showLoading: false);
    });
  }

  void onTabChanged(int index) {
    selectedTab.value = index;
    if (index == 1 && historyItems.isEmpty && !isHistoryLoading.value) {
      fetchBillHistory();
    }
  }

  Future<void> fetchBillHistory() async {
    if (table.value == null) return;
    isHistoryLoading.value = true;
    _historyPage.value = 1;
    hasMoreHistory.value = true;
    historyItems.clear();
    try {
      final response = await _apiService.dio.get(
        '/tables/${table.value!.id}/bill-history',
        queryParameters: {'page': 1},
      );
      final data = response.data;
      final List items = data['data'] ?? [];
      historyItems.assignAll(items.map((e) => BillHistoryItem.fromJson(e)).toList());
      final meta = data['meta'] ?? data['pagination'];
      final lastPage = meta?['last_page'] ?? 1;
      if (_historyPage.value >= lastPage) hasMoreHistory.value = false;
    } on DioException catch (_) {
      Get.snackbar('Lỗi', 'Không tải được lịch sử hóa đơn');
    } finally {
      isHistoryLoading.value = false;
    }
  }

  Future<void> _loadMoreHistory() async {
    if (table.value == null || !hasMoreHistory.value || isLoadingMore.value) return;
    isLoadingMore.value = true;
    _historyPage.value++;
    try {
      final response = await _apiService.dio.get(
        '/tables/${table.value!.id}/bill-history',
        queryParameters: {'page': _historyPage.value},
      );
      final data = response.data;
      final List items = data['data'] ?? [];
      historyItems.addAll(items.map((e) => BillHistoryItem.fromJson(e)).toList());
      final meta = data['meta'] ?? data['pagination'];
      final lastPage = meta?['last_page'] ?? 1;
      if (_historyPage.value >= lastPage) hasMoreHistory.value = false;
    } on DioException catch (_) {
      _historyPage.value--;
      Get.snackbar('Lỗi', 'Không tải được thêm lịch sử');
    } finally {
      isLoadingMore.value = false;
    }
  }

  Future<void> fetchBill({bool showLoading = true}) async {
    if (table.value == null || _isFetchingBill) return;
    _isFetchingBill = true;
    if (showLoading) isLoading.value = true;
    try {
      final response = await _apiService.dio.get(
        '/tables/${table.value!.id}/bill',
      );
      final data = response.data;
      if (data['data'] != null) {
        bill.value = Bill.fromJson(data['data']);
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        bill.value = null;
      } else {
        Get.snackbar('Lỗi', 'Không tải được hóa đơn');
      }
    } finally {
      _isFetchingBill = false;
      if (showLoading) isLoading.value = false;
    }
  }

  Future<void> _printCurrentBill() async {
    if (bill.value == null) {
      Get.snackbar('Lỗi', 'Không tìm thấy hóa đơn để in');
      return;
    }

    await Get.find<PrinterService>().printBill(
      bill.value!,
      tableName: table.value?.name,
    );
  }

  Future<void> payAndPrint({required String method}) async {
    if (table.value == null) return;
    try {
      final response = await _apiService.dio.post(
        '/tables/${table.value!.id}/bill/pay',
        data: {'payment_method': method, 'table_id': table.value!.id},
      );

      Get.back();

      final data = response.data;

      if (method == 'qr_code' &&
          data['data'] != null &&
          data['data']['checkoutUrl'] != null) {
        final qrUrl = data['data']['checkoutUrl'];
        Get.to(
          () => PaymentWebViewScreen(url: qrUrl, title: 'Cổng thanh toán'),
        );
      } else {
        await _printCurrentBill();
        Get.dialog(
          AlertDialog(
            title: const Text('Thanh toán thành công'),
            content: const Text(
              'Nếu máy in gặp vấn đề, bạn có thể in lại hóa đơn trước khi quay về danh sách bàn.',
            ),
            actions: [
              TextButton(
                onPressed: _printCurrentBill,
                child: const Text('In lại'),
              ),
              TextButton(
                onPressed: () => Get.offAll(() => const TableListScreen()),
                child: const Text('Về danh sách bàn'),
              ),
            ],
          ),
          barrierDismissible: false,
        );
      }
    } catch (e) {
      Get.snackbar('Lỗi', 'Thanh toán thất bại');
    }
  }

  Future<void> addCustomer(String phone, String name) async {
    if (table.value == null) return;
    try {
      await _apiService.dio.post(
        '/tables/${table.value!.id}/bill/customer',
        data: {'phone': phone, 'name': name},
      );
      Get.snackbar('Thành công', 'Đã thêm khách hàng');
      fetchBill();
    } catch (e) {
      debugPrint(e.toString());
      Get.snackbar(
        'Lỗi',
        'Khách hàng không tồn tại trong hệ thống vui lòng kèm tên',
      );
    }
  }

  Future<void> removeCustomer() async {
    if (table.value == null) return;
    try {
      await _apiService.dio.delete('/tables/${table.value!.id}/bill/customer');
      Get.snackbar('Thành công', 'Đã xóa khách hàng');
      fetchBill();
    } catch (e) {
      Get.snackbar('Lỗi', 'Xóa khách hàng thất bại');
    }
  }

  Future<void> applyVoucher(String code) async {
    if (table.value == null) return;
    try {
      await _apiService.dio.post(
        '/tables/${table.value!.id}/bill/discount',
        data: {'code': code},
      );
      Get.snackbar('Thành công', 'Áp dụng mã giảm giá thành công');
      fetchBill();
    } catch (e) {
      if (e is DioException && e.response?.data is Map) {
        Get.snackbar('Lỗi', e.response?.data['message'] ?? 'Áp dụng thất bại');
      } else {
        Get.snackbar('Lỗi', 'Áp dụng thất bại');
      }
    }
  }

  Future<void> removeVoucher() async {
    if (table.value == null) return;
    try {
      await _apiService.dio.delete('/tables/${table.value!.id}/bill/discount');
      Get.snackbar('Thành công', 'Đã xóa mã giảm giá');
      fetchBill();
    } catch (e) {
      debugPrint(e.toString());
      Get.snackbar('Lỗi', 'Xóa mã giảm giá thất bại: $e');
    }
  }

  Future<void> deleteUnpaidBill() async {
    final currentTable = table.value;
    if (currentTable == null || isDeleting.value) return;

    isDeleting.value = true;
    _billPollingTimer?.cancel();
    try {
      await _apiService.dio.delete('/tables/${currentTable.id}/bill');
      bill.value = null;
      Get.back(result: true);
      Get.snackbar('Thành công', 'Đã xóa đơn và đưa bàn về trạng thái trống.');
    } on DioException catch (error) {
      final statusCode = error.response?.statusCode;
      final responseData = error.response?.data;
      final message = responseData is Map
          ? responseData['message']?.toString()
          : null;

      if (statusCode == 401) {
        await _storage.remove('access_token');
        Get.offAll(() => const LoginScreen());
        Get.snackbar('Phiên đăng nhập hết hạn', 'Vui lòng đăng nhập lại.');
        return;
      }

      if (statusCode == 404) {
        Get.snackbar(
          'Đơn không còn tồn tại',
          message ?? 'Không tìm thấy đơn chưa thanh toán.',
        );
        await fetchBill(showLoading: false);
        _startBillPolling();
        return;
      }

      Get.snackbar('Lỗi', message ?? 'Không thể xóa đơn. Vui lòng thử lại.');
      _startBillPolling();
    } finally {
      isDeleting.value = false;
    }
  }
}
