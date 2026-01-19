import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:dio/dio.dart';
import '../../core/api/api_service.dart';
import '../../data/models/table.dart';
import '../../data/models/bill.dart';
import 'payment_webview_screen.dart';

class BillController extends GetxController {
  final ApiService _apiService = ApiService();

  final table = Rxn<TableModel>();
  final bill = Rxn<Bill>();
  final isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    if (Get.arguments is TableModel) {
      table.value = Get.arguments as TableModel;
      fetchBill();
    } else if (Get.arguments is String) {
      table.value = TableModel(id: Get.arguments as String, tableNumber: '...', isActive: '1');
      fetchBill();
    }
  }

  Future<void> fetchBill() async {
    if (table.value == null) return;
    isLoading.value = true;
    try {
      final response = await _apiService.dio.get('/tables/${table.value!.id}/bill');
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
      isLoading.value = false;
    }
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

      if (method == 'qr_code' && data['data'] != null && data['data']['checkoutUrl'] != null) {
        final qrUrl = data['data']['checkoutUrl'];
        Get.to(() => PaymentWebViewScreen(url: qrUrl, title: 'Cổng thanh toán'));
      } else {
        Get.snackbar('Thành công', 'Thanh toán đã được khởi tạo/hoàn tất');
      }

      fetchBill();
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
      Get.snackbar('Lỗi', 'Khách hàng không tồn tại trong hệ thống vui lòng kèm tên');
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
      await _apiService.dio.post('/tables/${table.value!.id}/bill/discount', data: {'code': code});
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
}
