import 'package:get/get.dart';
import '../../core/api/api_service.dart';
import 'bill_controller.dart';

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
