import 'package:get/get.dart';
import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import '../../features/bill/payment_result_screen.dart';
import '../../features/bill/bill_screen.dart';
import '../../features/bill/bill_controller.dart';

class DeepLinkController extends GetxController {
  final _appLinks = AppLinks();

  @override
  void onInit() {
    super.onInit();
    initDeepLinks();
  }

  Future<void> initDeepLinks() async {
    try {
      final uri = await _appLinks.getInitialLink();
      if (uri != null) {
        handleDeepLink(uri);
      }
    } catch (e) {
      if (kDebugMode) {
        print('DeepLink Init Error: $e');
      }
    }

    _appLinks.uriLinkStream.listen(
      (uri) {
        handleDeepLink(uri);
      },
      onError: (err) {
        if (kDebugMode) {
          print('DeepLink Stream Error: $err');
        }
      },
    );
  }

  void handleDeepLink(Uri uri) {
    if (kDebugMode) {
      print('Received URI: $uri');
    }

    if (uri.scheme == 'thuongoc') {
      if (uri.host == 'payment_result' || uri.host == 'payment-result') {
        final params = uri.queryParameters;
        Get.to(() => PaymentResultScreen(params: params));
      } else if (uri.host == 'table_bill') {
        final tableId = uri.queryParameters['id'];
        if (tableId != null) {
          try {
            Get.delete<BillController>(force: true);
          } catch (e) {
            debugPrint('BillController not found: $e');
          }

          Get.to(() => const BillScreen(), arguments: tableId);
        }
      }
    }
  }
}
