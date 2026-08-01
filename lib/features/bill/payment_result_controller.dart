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
  Bill? _billToPrint;
  String? _tableId;

  @override
  void onInit() {
    super.onInit();
    _tableId = params['table_id'] ?? params['tableId'];
    if (Get.isRegistered<BillController>()) {
      final billController = Get.find<BillController>();
      // Keep the bill before marking it as paid. The subsequent refresh no
      // longer returns it from the current-bill endpoint.
      _billToPrint = billController.bill.value;
      _tableId ??= billController.table.value?.id;
    }
    _checkAndUpdateStatus();
  }

  Future<void> printBill() async {
    Bill? billToPrint = _billToPrint;

    if (billToPrint == null) {
      final tableId = _tableId;
      final billId = int.tryParse(params['orderCode'] ?? params['id'] ?? '');
      if (tableId != null && billId != null) {
        Get.dialog(
          const Center(child: CircularProgressIndicator.adaptive()),
          barrierDismissible: false,
        );
        try {
          final response = await _apiService.dio.get(
            '/tables/$tableId/bill-history/$billId',
          );
          final data = response.data;
          if (data['data'] != null) {
            billToPrint = Bill.fromJson(data['data']);
            _billToPrint = billToPrint;
          }
        } catch (e) {
          Get.snackbar('Lỗi', 'Không thể tải hóa đơn: $e');
        } finally {
          if (Get.isDialogOpen == true) Get.back();
        }
      }
    }

    if (billToPrint != null) {
      await Get.find<PrinterService>().printBill(billToPrint);
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
      if (_tableId != null) {
        await updateBillStatus(_tableId!);
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
