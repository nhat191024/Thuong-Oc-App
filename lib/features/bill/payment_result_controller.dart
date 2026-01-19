import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/api/api_service.dart';
import 'bill_controller.dart';
import '../../core/services/printer_service.dart';
import '../../data/models/bill.dart';

class PaymentResultController extends GetxController {
  final ApiService _apiService = ApiService();
  final Map<String, String> params;

  PaymentResultController(this.params);

  final isUpdating = false.obs;

  @override
  void onInit() {
    super.onInit();
    _checkAndUpdateStatus();
  }

  Future<void> printBill() async {
    Bill? billToPrint;
    
    if (Get.isRegistered<BillController>()) {
      billToPrint = Get.find<BillController>().bill.value;
    }

    if (billToPrint == null) {
      String? tableId = params['table_id'] ?? params['tableId'];
      if (tableId != null) {
        Get.dialog(GetPlatform.isAndroid ? const Center(child: CircularProgressIndicator()) : const Center(child: CircularProgressIndicator.adaptive()), barrierDismissible: false);
        try {
          final response = await _apiService.dio.get('/tables/$tableId/bill');
          Get.back(); // Close loading
          final data = response.data;
          if (data['data'] != null) {
            billToPrint = Bill.fromJson(data['data']);
          }
        } catch (e) {
          Get.back(); // Close loading
          Get.snackbar('Lỗi', 'Không thể tải hóa đơn: $e');
        }
      }
    }

    if (billToPrint != null) {
      Get.find<PrinterService>().printBill(billToPrint);
    } else {
      Get.snackbar('Lỗi', 'Chưa có thông tin hóa đơn để in');
    }
  }

  Future<void> _checkAndUpdateStatus() async {
    final status = params['status'];
    final code = params['code'];
    final cancel = params['cancel'];

    bool isSuccess = false;
    if (status == 'PAID' || status == '00') {
      isSuccess = true;
    } else if (code == '00' && cancel != 'true') {
      isSuccess = true;
    }

    if (isSuccess) {
      String? tableId = params['table_id'] ?? params['tableId'];
      if (tableId == null && Get.isRegistered<BillController>()) {
        tableId = Get.find<BillController>().table.value?.id;
      }

      if (tableId != null) {
        await updateBillStatus(tableId);
      }
    }
  }

  Future<void> updateBillStatus(String tableId) async {
    isUpdating.value = true;
    try {
      await _apiService.dio.patch(
        '/tables/$tableId/bill/status',
        data: {'status': 'paid', 'payment_method': 'qr_code'},
      );

      // Refresh Bill info if controller exists
      if (Get.isRegistered<BillController>()) {
        Get.find<BillController>().fetchBill();
      }
    } catch (e) {
      print('Error updating bill status: $e');
    } finally {
      isUpdating.value = false;
    }
  }
}
