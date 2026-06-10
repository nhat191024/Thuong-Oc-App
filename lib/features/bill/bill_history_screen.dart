import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../data/models/bill.dart';
import 'bill_controller.dart';
import 'bill_history_detail_screen.dart';

class BillHistoryScreen extends StatelessWidget {
  const BillHistoryScreen({super.key});

  static String _formatDateTime(String? raw) {
    if (raw == null || raw.isEmpty) return '---';
    try {
      final dt = DateTime.parse(raw);
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return raw;
    }
  }

  static String _paymentMethodLabel(String method) {
    switch (method) {
      case 'cash':
        return 'Tiền mặt';
      case 'qr_code':
        return 'QR Code';
      default:
        return method;
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<BillController>();
    final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0);

    return Obx(() {
      if (controller.isHistoryLoading.value) {
        return const Center(child: CircularProgressIndicator());
      }

      if (controller.historyItems.isEmpty) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.history, size: 48, color: Colors.grey),
              const SizedBox(height: 8),
              const Text('Không có lịch sử hóa đơn', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: () => controller.fetchBillHistory(),
                icon: const Icon(Icons.refresh),
                label: const Text('Thử lại'),
              ),
            ],
          ),
        );
      }

      return ListView.builder(
        controller: controller.historyScrollController,
        padding: const EdgeInsets.all(12),
        itemCount: controller.historyItems.length + (controller.hasMoreHistory.value ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == controller.historyItems.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final item = controller.historyItems[index];
          return _buildHistoryCard(item, currencyFormat);
        },
      );
    });
  }

  Widget _buildHistoryCard(BillHistoryItem item, NumberFormat currencyFormat) {
    final isPaid = item.payStatus == 'paid';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Get.to(
          () => const BillHistoryDetailScreen(),
          arguments: {
            'tableId': Get.find<BillController>().table.value?.id,
            'billId': item.id,
            'tableName': Get.find<BillController>().table.value?.name,
          },
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Hóa đơn #${item.id}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isPaid
                          ? Colors.green.withValues(alpha: 0.15)
                          : Colors.orange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isPaid ? 'Đã thanh toán' : 'Chưa thanh toán',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isPaid ? Colors.green : Colors.orange,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.login, size: 16, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text(
                    'Vào: ${_formatDateTime(item.timeIn)}',
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.logout, size: 16, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text(
                    'Ra: ${_formatDateTime(item.timeOut)}',
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.payment, size: 16, color: Colors.grey),
                      const SizedBox(width: 6),
                      Text(
                        _paymentMethodLabel(item.paymentMethod),
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                  Text(
                    currencyFormat.format(item.finalTotal),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
