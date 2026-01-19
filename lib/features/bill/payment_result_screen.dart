import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:forui/forui.dart';
import '../table/table_list_screen.dart';
import 'payment_result_controller.dart';

class PaymentResultScreen extends StatelessWidget {
  final Map<String, String> params;

  const PaymentResultScreen({super.key, required this.params});

  @override
  Widget build(BuildContext context) {
    Get.put(PaymentResultController(params));

    final orderCode = params['orderCode'] ?? params['id'] ?? 'Unknown';
    final status = params['status'];
    final code = params['code'];
    final cancel = params['cancel'];

    bool isSuccess = false;

    if (status == 'PAID' || status == '00') {
      isSuccess = true;
    } else if (code == '00' && cancel != 'true') {
      isSuccess = true;
    }

    return FScaffold(
      header: FHeader(title: const Text('Kết quả thanh toán')),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isSuccess ? Icons.check_circle : Icons.cancel,
                size: 80,
                color: isSuccess ? Colors.green : Colors.red,
              ),
              const SizedBox(height: 24),
              Text(
                isSuccess ? 'Thanh toán thành công!' : 'Thanh toán thất bại',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isSuccess ? Colors.green : Colors.red,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isSuccess
                    ? 'Đơn hàng #$orderCode đã được thanh toán.'
                    : 'Đơn hàng #$orderCode chưa được thanh toán.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, fontSize: 16),
              ),
              if (isSuccess) ...[
                const SizedBox(height: 24),
                FButton(
                  onPress: () => Get.find<PaymentResultController>().printBill(),
                  child: const Text('In hóa đơn'),
                ),
              ],
              const SizedBox(height: 48),
              FButton(
                onPress: () {
                  Get.offAll(() => const TableListScreen());
                },
                child: const Text('Về trang chủ'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
