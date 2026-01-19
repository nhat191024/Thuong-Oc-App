import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:forui/forui.dart';
import 'package:get/get.dart';
import '../../core/controllers/deep_link_controller.dart';

class PaymentWebViewScreen extends StatelessWidget {
  final String url;
  final String title;

  const PaymentWebViewScreen({super.key, required this.url, this.title = 'Thanh toán'});

  @override
  Widget build(BuildContext context) {
    return FScaffold(
      header: FHeader(
        title: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.of(context).pop(),
            ),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
      ),
      child: InAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(url)),
        initialSettings: InAppWebViewSettings(
          isInspectable: true,
          mediaPlaybackRequiresUserGesture: false,
          allowsInlineMediaPlayback: true,
          iframeAllow: "camera; microphone",
          iframeAllowFullscreen: true,
        ),
        shouldOverrideUrlLoading: (controller, navigationAction) async {
          final uri = navigationAction.request.url;
          if (uri != null && uri.scheme == 'thuongoc') {
            if (Get.isRegistered<DeepLinkController>()) {
              Get.find<DeepLinkController>().handleDeepLink(uri);
            } else {
              Get.put(DeepLinkController()).handleDeepLink(uri);
            }
            return NavigationActionPolicy.CANCEL;
          }
          return NavigationActionPolicy.ALLOW;
        },
      ),
    );
  }
}
