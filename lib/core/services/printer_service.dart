import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:sunmi_flutter_plugin_printer/bean/printer.dart';
import 'package:sunmi_flutter_plugin_printer/listener/printer_listener.dart';
import 'package:sunmi_flutter_plugin_printer/printer_sdk.dart';
import 'package:sunmi_flutter_plugin_printer/style/base_style.dart';
import 'package:sunmi_flutter_plugin_printer/style/text_style.dart'
    as printer_style;
import 'package:sunmi_flutter_plugin_printer/enum/align.dart' as printer_align;
import '../../data/models/bill.dart';

class PrinterService extends GetxService {
  Printer? printer;

  printer_style.TextStyle _boldTextStyle({
    printer_align.Align? align,
    int? textSize,
  }) {
    final style = printer_style.TextStyle.getStyle().enableBold(true);
    if (align != null) {
      style.setAlign(align);
    }
    if (textSize != null) {
      style.setTextSize(textSize);
    }
    return style;
  }

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

  Future<void> printBill(Bill bill, {String? tableName}) async {
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
        _boldTextStyle(align: printer_align.Align.CENTER, textSize: 34),
      );
      lineApi.printText(
        'Hóa Đơn Thanh Toán',
        _boldTextStyle(align: printer_align.Align.CENTER, textSize: 28),
      );
      lineApi.printText(
        ' ',
        _boldTextStyle(textSize: 8),
      );

      // Info
      lineApi.printText(
        tableName != null && tableName.isNotEmpty
            ? 'Bàn: $tableName (${bill.tableNumber})'
            : 'Bàn: ${bill.tableNumber}',
        _boldTextStyle(textSize: 22),
      );
      lineApi.printText(
        'Giờ vào: ${bill.timeIn}',
        _boldTextStyle(textSize: 22),
      );
      lineApi.printText(
        'Mã HĐ: ${bill.id}',
        _boldTextStyle(textSize: 22),
      );
      if (bill.customer != null) {
        lineApi.printText(
          'Khách hàng: ${bill.customer!.name ?? '---'}',
          _boldTextStyle(textSize: 22),
        );
        if (bill.customer!.phone != null && bill.customer!.phone!.isNotEmpty) {
          lineApi.printText(
            'SĐT: ${bill.customer!.phone}',
            _boldTextStyle(textSize: 22),
          );
        }
      }
      lineApi.printText(' ', _boldTextStyle(textSize: 8));

      // Divider
      lineApi.printText(
        '--------------------------------',
        _boldTextStyle(align: printer_align.Align.CENTER, textSize: 22),
      );

      // Table header: Tên món | SL | Tiền (bỏ cột Note, dùng dòng phụ)
      lineApi.printTexts(['Tên món', 'SL', 'Tiền'], [6, 1, 2], [
        _boldTextStyle(align: printer_align.Align.LEFT, textSize: 24),
        _boldTextStyle(align: printer_align.Align.CENTER, textSize: 24),
        _boldTextStyle(align: printer_align.Align.RIGHT, textSize: 24),
      ]);

      // Items
      for (var item in bill.details) {
        // Dòng chính: tên món | số lượng | thành tiền
        lineApi.printTexts(
          [
            item.name,
            '${item.quantity}',
            NumberFormat('#,###').format(item.total),
          ],
          [6, 1, 2],
          [
            _boldTextStyle(align: printer_align.Align.LEFT, textSize: 24),
            _boldTextStyle(align: printer_align.Align.CENTER, textSize: 24),
            _boldTextStyle(align: printer_align.Align.RIGHT, textSize: 24),
          ],
        );
        // Dòng phụ: cách chế biến (nếu có)
        if (item.cookingMethod != null && item.cookingMethod!.isNotEmpty) {
          lineApi.printText(
            '  > ${item.cookingMethod}',
            _boldTextStyle(align: printer_align.Align.LEFT, textSize: 22),
          );
        }
        // Dòng phụ: ghi chú (nếu có)
        if (item.note != null && item.note!.isNotEmpty) {
          lineApi.printText(
            '  * ${item.note}',
            _boldTextStyle(align: printer_align.Align.LEFT, textSize: 22),
          );
        }
      }

      // Divider
      lineApi.printText(
        '--------------------------------',
        _boldTextStyle(align: printer_align.Align.CENTER, textSize: 22),
      );

      // Totals
      lineApi.printTexts(
        ['Tổng cộng:', (NumberFormat('#,###').format(bill.totalAmount))],
        [1, 1],
        [
          _boldTextStyle(align: printer_align.Align.LEFT, textSize: 24),
          _boldTextStyle(align: printer_align.Align.RIGHT, textSize: 24),
        ],
      );

      if (bill.discountAmount > 0) {
        lineApi.printTexts(
          [
            'Giảm giá:',
            '-${NumberFormat('#,###').format(bill.discountAmount)}',
          ],
          [1, 1],
          [
            _boldTextStyle(align: printer_align.Align.LEFT, textSize: 24),
            _boldTextStyle(align: printer_align.Align.RIGHT, textSize: 24),
          ],
        );
      }

      lineApi.printTexts(
        ['Thanh toán:', (NumberFormat('#,###').format(bill.finalAmount))],
        [1, 1],
        [
          _boldTextStyle(align: printer_align.Align.LEFT, textSize: 28),
          _boldTextStyle(align: printer_align.Align.RIGHT, textSize: 28),
        ],
      );

      lineApi.printText(' ', _boldTextStyle(textSize: 8));
      lineApi.printText(
        'Xin cảm ơn quý khách!',
        _boldTextStyle(align: printer_align.Align.CENTER, textSize: 22),
      );
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
