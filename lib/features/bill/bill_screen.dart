import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:forui/forui.dart';
import 'package:intl/intl.dart';
import 'bill_controller.dart';

class BillScreen extends StatelessWidget {
  const BillScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(BillController());
    final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0);

    return FScaffold(
      header: FHeader(
        title: Row(
          children: [
            IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Get.back()),
            const SizedBox(width: 8),
            const Text('Chi tiết hóa đơn'),
          ],
        ),
      ),
      child: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        if (controller.bill.value == null) {
          return const Center(child: Text('Không có hóa đơn hoạt động'));
        }

        final bill = controller.bill.value!;

        return Column(
          children: [
            // Bill Info
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: FCard(
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Bàn ${bill.tableNumber}'),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: bill.payStatus == 'paid'
                              ? Colors.green.withValues(alpha: 0.2)
                              : Colors.orange.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          bill.payStatus == 'paid' ? 'ĐÃ THANH TOÁN' : 'CHƯA THANH TOÁN',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: bill.payStatus == 'paid' ? Colors.green : Colors.orange,
                          ),
                        ),
                      ),
                    ],
                  ),
                  subtitle: Text('Giờ vào: ${bill.timeIn}'),
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
                      if (bill.customer != null || bill.voucherCode != null) ...[
                        const Divider(height: 24),
                        if (bill.customer != null)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
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
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 20),
                                onPressed: () => controller.removeCustomer(),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                        if (bill.customer != null && bill.voucherCode != null) const SizedBox(height: 8),
                        if (bill.voucherCode != null)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Voucher: ${bill.voucherCode}',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    '-${currencyFormat.format(bill.discountAmount)}',
                                    style: const TextStyle(fontSize: 12, color: Colors.green),
                                  ),
                                ],
                              ),
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 20),
                                onPressed: () => controller.removeVoucher(),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            // Actions
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: FButton(
                      onPress:
                          bill.customer != null
                              ? null
                              : () => _showAddCustomerDialog(context, controller),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.person_add, size: 14),
                          SizedBox(width: 8),
                          Text('Khách hàng'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FButton(
                      onPress:
                          bill.voucherCode != null
                              ? null
                              : () => _showAddVoucherDialog(context, controller),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.local_offer, size: 16),
                          SizedBox(width: 8),
                          Text('Voucher'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Payment Button
            Padding(
              padding: const EdgeInsets.all(16),
              child: FButton(
                onPress: () => _showPaymentSheet(context, controller),
                child: const Text('Thanh toán'),
              ),
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

  void _showAddCustomerDialog(BuildContext context, BillController controller) {
    final phoneCtrl = TextEditingController();
    final nameCtrl = TextEditingController();

    Get.defaultDialog(
      title: 'Thêm khách hàng',
      content: Column(
        children: [
          TextField(
            controller: phoneCtrl,
            decoration: const InputDecoration(labelText: 'Số điện thoại'),
          ),
          TextField(
            controller: nameCtrl,
            decoration: const InputDecoration(labelText: 'Tên (Không bắt buộc)'),
          ),
        ],
      ),
      textConfirm: 'Thêm',
      textCancel: 'Hủy',
      onConfirm: () {
        controller.addCustomer(phoneCtrl.text, nameCtrl.text);
        Get.back();
      },
    );
  }

  void _showAddVoucherDialog(BuildContext context, BillController controller) {
    final codeCtrl = TextEditingController();

    Get.defaultDialog(
      title: 'Áp dụng mã giảm giá',
      content: Column(
        children: [
          TextField(
            controller: codeCtrl,
            decoration: const InputDecoration(labelText: 'Mã giảm giá'),
          ),
        ],
      ),
      textConfirm: 'Áp dụng',
      textCancel: 'Hủy',
      onConfirm: () {
        controller.applyVoucher(codeCtrl.text);
        Get.back();
      },
    );
  }

  void _showPaymentSheet(BuildContext context, BillController controller) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Material(
        // Wrap in Material to support ListTile
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.money),
                title: const Text('Cash'),
                onTap: () => controller.payAndPrint(method: 'cash'),
              ),
              ListTile(
                leading: const Icon(Icons.qr_code),
                title: const Text('QR Code'),
                onTap: () => controller.payAndPrint(method: 'qr_code'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
