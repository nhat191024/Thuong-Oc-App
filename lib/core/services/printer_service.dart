import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:sunmi_flutter_plugin_printer/bean/printer.dart';
import 'package:sunmi_flutter_plugin_printer/listener/printer_listener.dart';
import 'package:sunmi_flutter_plugin_printer/printer_sdk.dart';
import 'package:sunmi_flutter_plugin_printer/style/base_style.dart';
import 'package:sunmi_flutter_plugin_printer/style/text_style.dart' as printer_style;
import 'package:sunmi_flutter_plugin_printer/enum/align.dart' as printer_align;
import '../../data/models/bill.dart';

class PrinterService extends GetxService {
  Printer? printer;

  Future<PrinterService> init() async {
    try {
      PrinterSdk.instance.getPrinter(PrinterServiceListener(this));
    } catch (e) {
      print('Printer init error: $e');
    }
    return this;
  }

  void setPrinter(Printer p) {
    printer = p;
  }

  Future<void> printBill(Bill bill) async {
    if (printer == null) {
      Get.snackbar('Lỗi', 'Không tìm thấy máy in');
      return;
    }

    try {
      final lineApi = printer!.lineApi;
      lineApi.initLine(BaseStyle.getStyle());

      // Header
      lineApi.printText(
        'Thương Ốc',
        printer_style.TextStyle.getStyle()
            .setAlign(printer_align.Align.CENTER)
            .setTextSize(30)
            .enableBold(true),
      );
      lineApi.printText(
        'Hóa Đơn Thanh Toán',
        printer_style.TextStyle.getStyle().setAlign(printer_align.Align.CENTER).setTextSize(24),
      );
      lineApi.autoOut();

      // Info
      lineApi.printText('Bàn: ${bill.tableNumber}', printer_style.TextStyle.getStyle());
      lineApi.printText('Giờ vào: ${bill.timeIn}', printer_style.TextStyle.getStyle());
      lineApi.printText('Mã HĐ: ${bill.id}', printer_style.TextStyle.getStyle());
      lineApi.autoOut();

      // Divider
      lineApi.printText(
        '--------------------------------',
        printer_style.TextStyle.getStyle().setAlign(printer_align.Align.CENTER),
      );

      // Items
      for (var item in bill.details) {
        lineApi.printText(item.name, printer_style.TextStyle.getStyle());
        lineApi
            .printTexts(['${item.quantity}', (NumberFormat('#,###').format(item.total))], [1, 1], [
              printer_style.TextStyle.getStyle().setAlign(printer_align.Align.LEFT),
              printer_style.TextStyle.getStyle().setAlign(printer_align.Align.RIGHT),
            ]);
      }

      // Divider
      lineApi.printText(
        '--------------------------------',
        printer_style.TextStyle.getStyle().setAlign(printer_align.Align.CENTER),
      );

      // Totals
      lineApi.printTexts(['Tổng cộng:', (NumberFormat('#,###').format(bill.totalAmount))], [1, 1], [
        printer_style.TextStyle.getStyle().setAlign(printer_align.Align.LEFT),
        printer_style.TextStyle.getStyle().setAlign(printer_align.Align.RIGHT),
      ]);

      if (bill.discountAmount > 0) {
        lineApi.printTexts(
          ['Giảm giá:', '-${NumberFormat('#,###').format(bill.discountAmount)}'],
          [1, 1],
          [
            printer_style.TextStyle.getStyle().setAlign(printer_align.Align.LEFT),
            printer_style.TextStyle.getStyle().setAlign(printer_align.Align.RIGHT),
          ],
        );
      }

      lineApi
          .printTexts(['Thanh toán:', (NumberFormat('#,###').format(bill.finalAmount))], [1, 1], [
            printer_style.TextStyle.getStyle()
                .setAlign(printer_align.Align.LEFT)
                .enableBold(true)
                .setTextSize(24),
            printer_style.TextStyle.getStyle()
                .setAlign(printer_align.Align.RIGHT)
                .enableBold(true)
                .setTextSize(24),
          ]);

      lineApi.autoOut();
      lineApi.printText(
        'Xin cảm ơn quý khách!',
        printer_style.TextStyle.getStyle().setAlign(printer_align.Align.CENTER),
      );
      lineApi.autoOut();
      lineApi.autoOut();
      lineApi.autoOut();
    } catch (e) {
      Get.snackbar('Lỗi', 'In thất bại: $e');
    }
  }
}

class PrinterServiceListener extends PrinterListener {
  final PrinterService service;
  PrinterServiceListener(this.service);

  @override
  void onDefPrinter(Printer var1) {
    service.setPrinter(var1);
  }
}
