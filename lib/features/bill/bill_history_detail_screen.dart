import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:forui/forui.dart';
import 'package:intl/intl.dart';
import 'bill_history_detail_controller.dart';

class BillHistoryDetailScreen extends StatelessWidget {
  const BillHistoryDetailScreen({super.key});

  static String _formatDateTime(String? raw) {
    if (raw == null || raw.isEmpty) return '---';
    try {
      final dt = DateTime.parse(raw);
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return raw;
    }
  }

  static String _paymentMethodLabel(String? method) {
    switch (method) {
      case 'cash':
        return 'Tiền mặt';
      case 'qr_code':
        return 'QR Code';
      default:
        return method ?? '---';
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(BillHistoryDetailController());
    final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0);

    return FScaffold(
      header: FHeader(
        title: Row(
          children: [
            IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Get.back()),
            const SizedBox(width: 8),
            Obx(() {
              final bill = controller.bill.value;
              return Text(
                bill != null ? 'Hóa đơn #${bill.id}' : 'Chi tiết hóa đơn',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
              );
            }),
          ],
        ),
      ),
      child: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        final bill = controller.bill.value;
        if (bill == null) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Không tải được chi tiết hóa đơn'),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: controller.fetchDetail,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Thử lại'),
                ),
              ],
            ),
          );
        }

        final isPaid = bill.payStatus == 'paid';

        return Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: FCard(
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (controller.tableName != null &&
                              controller.tableName!.isNotEmpty)
                            Text(
                              controller.tableName!,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          Text(
                            '#${bill.tableNumber}',
                            style: const TextStyle(fontSize: 13, color: Colors.grey),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isPaid
                              ? Colors.green.withValues(alpha: 0.2)
                              : Colors.orange.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isPaid ? 'ĐÃ THANH TOÁN' : 'CHƯA THANH TOÁN',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isPaid ? Colors.green : Colors.orange,
                          ),
                        ),
                      ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Giờ vào: ${_formatDateTime(bill.timeIn)}'),
                      if (bill.timeOut != null)
                        Text('Giờ ra: ${_formatDateTime(bill.timeOut)}'),
                      if (bill.paymentMethod != null)
                        Text('Thanh toán: ${_paymentMethodLabel(bill.paymentMethod)}'),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ...bill.details.map(
                        (d) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      d.name,
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    if (d.cookingMethod != null)
                                      Text(
                                        '${d.cookingMethod}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.blueAccent,
                                        ),
                                      ),
                                    if (d.note != null)
                                      Text(
                                        'Ghi chú: ${d.note!}',
                                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                                      ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${d.quantity} x ${currencyFormat.format(d.price)}',
                                    style: const TextStyle(fontWeight: FontWeight.w500),
                                  ),
                                  Text(
                                    currencyFormat.format(d.total),
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Divider(),
                      _buildSummaryRow('Tạm tính', bill.totalAmount, currencyFormat),
                      if (bill.discountAmount > 0)
                        _buildSummaryRow(
                          'Giảm giá (${bill.discountPercent}%)',
                          -bill.discountAmount,
                          currencyFormat,
                          color: Colors.green,
                        ),
                      const SizedBox(height: 8),
                      _buildSummaryRow(
                        'Tổng cộng',
                        bill.finalAmount,
                        currencyFormat,
                        isBold: true,
                        fontSize: 18,
                      ),
                      if (bill.customer != null) ...[
                        const Divider(height: 24),
                        Row(
                          children: [
                            const Icon(Icons.person, size: 16, color: Colors.grey),
                            const SizedBox(width: 6),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Khách: ${bill.customer!.name ?? '---'}',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                if (bill.customer!.phone != null)
                                  Text(
                                    bill.customer!.phone!,
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ],
                      if (bill.voucherCode != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.local_offer, size: 16, color: Colors.grey),
                            const SizedBox(width: 6),
                            Text(
                              'Voucher: ${bill.voucherCode}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            // Print button
            Padding(
              padding: const EdgeInsets.all(16),
              child: Obx(() => FButton(
                    onPress: controller.isPrinting.value
                        ? null
                        : () => controller.printBill(),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (controller.isPrinting.value)
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        else
                          const Icon(Icons.print, size: 18),
                        const SizedBox(width: 8),
                        Text(controller.isPrinting.value ? 'Đang in...' : 'In lại đơn'),
                      ],
                    ),
                  )),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildSummaryRow(
    String label,
    int amount,
    NumberFormat formatter, {
    bool isBold = false,
    double fontSize = 14,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: fontSize,
              color: color,
            ),
          ),
          Text(
            formatter.format(amount),
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: fontSize,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
