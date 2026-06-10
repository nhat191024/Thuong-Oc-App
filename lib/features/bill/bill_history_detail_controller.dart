import 'package:get/get.dart';
import 'package:dio/dio.dart';
import '../../core/api/api_service.dart';
import '../../core/services/printer_service.dart';
import '../../data/models/bill.dart';
import '../../data/models/table.dart';

class BillHistoryDetailController extends GetxController {
  final ApiService _apiService = ApiService();

  final bill = Rxn<Bill>();
  final isLoading = false.obs;
  final isPrinting = false.obs;

  late final String tableId;
  late final int billId;
  String? tableName;

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments as Map<String, dynamic>;
    tableId = args['tableId'].toString();
    billId = args['billId'] as int;
    tableName = args['tableName'] as String?;
    fetchDetail();
  }

  Future<void> fetchDetail() async {
    isLoading.value = true;
    try {
      final response = await _apiService.dio.get(
        '/tables/$tableId/bill-history/$billId',
      );
      final data = response.data;
      if (data['data'] != null) {
        bill.value = Bill.fromJson(data['data']);
      }
    } on DioException catch (_) {
      Get.snackbar('Lỗi', 'Không tải được chi tiết hóa đơn');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> printBill() async {
    if (bill.value == null) return;
    isPrinting.value = true;
    try {
      await Get.find<PrinterService>().printBill(
        bill.value!,
        tableName: tableName,
      );
    } catch (e) {
      Get.snackbar('Lỗi', 'In đơn thất bại');
    } finally {
      isPrinting.value = false;
    }
  }
}
