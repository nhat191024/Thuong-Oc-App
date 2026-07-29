import 'package:flutter/foundation.dart';
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
import '../../data/models/print_station.dart';

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
      debugPrint('Printer init error: $e');
    }
    return this;
  }

  void setPrinter(Printer p) {
    printer = p;
  }

  Future<void> printStationTest() async {
    final currentPrinter = printer;
    if (currentPrinter == null) {
      throw StateError('Không tìm thấy máy in tích hợp trên thiết bị');
    }

    final lineApi = currentPrinter.lineApi;
    lineApi.initLine(BaseStyle.getStyle());
    lineApi.printText(
      'THUONG OC',
      _boldTextStyle(align: printer_align.Align.CENTER, textSize: 30),
    );
    lineApi.printText(
      'PRINT TEST SUCCESS',
      _boldTextStyle(align: printer_align.Align.CENTER, textSize: 26),
    );
    lineApi.printText(
      DateTime.now().toIso8601String(),
      _boldTextStyle(align: printer_align.Align.CENTER, textSize: 20),
    );
    lineApi.printText(' ', _boldTextStyle(textSize: 18));
    lineApi.printText(' ', _boldTextStyle(textSize: 18));
    lineApi.autoOut();
  }

  Future<void> printStationJob(PrintJob job) async {
    final currentPrinter = printer;
    if (currentPrinter == null) {
      throw StateError('Không tìm thấy máy in tích hợp trên thiết bị');
    }

    final lineApi = currentPrinter.lineApi;
    lineApi.initLine(BaseStyle.getStyle());
    lineApi.printText(
      '--------------------------------',
      _boldTextStyle(align: printer_align.Align.CENTER, textSize: 22),
    );
    lineApi.printText(
      'Ban: ${_removeVietnameseDiacritics(job.tableNumber)}',
      _boldTextStyle(align: printer_align.Align.CENTER, textSize: 34),
    );
    lineApi.printText(
      '${_formatQuantity(job.quantity)} x '
      '${_removeVietnameseDiacritics(job.dishName)}',
      _boldTextStyle(align: printer_align.Align.CENTER, textSize: 34),
    );
    if (job.cookingMethod.isNotEmpty) {
      lineApi.printText(
        'Che bien: ${_removeVietnameseDiacritics(job.cookingMethod)}',
        _boldTextStyle(align: printer_align.Align.CENTER, textSize: 34),
      );
    }
    if (job.note.isNotEmpty) {
      lineApi.printText(
        'Ghi chu: ${_removeVietnameseDiacritics(job.note)}',
        _boldTextStyle(align: printer_align.Align.CENTER, textSize: 34),
      );
    }
    lineApi.printText(
      '--------------------------------',
      _boldTextStyle(align: printer_align.Align.CENTER, textSize: 22),
    );
    lineApi.printText(' ', _boldTextStyle(textSize: 18));
    lineApi.printText(' ', _boldTextStyle(textSize: 18));
    lineApi.autoOut();
  }

  String _formatQuantity(num value) {
    return value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toString();
  }

  String _removeVietnameseDiacritics(String value) {
    const characterGroups = <String, String>{
      'a': 'àáạảãâầấậẩẫăằắặẳẵ',
      'A': 'ÀÁẠẢÃÂẦẤẬẨẪĂẰẮẶẲẴ',
      'e': 'èéẹẻẽêềếệểễ',
      'E': 'ÈÉẸẺẼÊỀẾỆỂỄ',
      'i': 'ìíịỉĩ',
      'I': 'ÌÍỊỈĨ',
      'o': 'òóọỏõôồốộổỗơờớợởỡ',
      'O': 'ÒÓỌỎÕÔỒỐỘỔỖƠỜỚỢỞỠ',
      'u': 'ùúụủũưừứựửữ',
      'U': 'ÙÚỤỦŨƯỪỨỰỬỮ',
      'y': 'ỳýỵỷỹ',
      'Y': 'ỲÝỴỶỸ',
      'd': 'đ',
      'D': 'Đ',
    };

    var result = value;
    for (final entry in characterGroups.entries) {
      for (final character in entry.value.split('')) {
        result = result.replaceAll(character, entry.key);
      }
    }
    return result;
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
      lineApi.printText(' ', _boldTextStyle(textSize: 8));

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
      lineApi.printText('Mã HĐ: ${bill.id}', _boldTextStyle(textSize: 22));
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
      for (var i = 0; i < bill.details.length; i++) {
        final item = bill.details[i];
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
        if (i < bill.details.length - 1) {
          lineApi.printText(
            ' - - - - - - - - ',
            _boldTextStyle(align: printer_align.Align.CENTER, textSize: 16),
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
