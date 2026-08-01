import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:forui/forui.dart';
import 'features/splash/splash_screen.dart';
import 'core/controllers/deep_link_controller.dart';
import 'core/api/api_service.dart';
import 'core/services/printer_service.dart';
import 'features/auth/login_controller.dart';
import 'features/auth/login_screen.dart';

void main() async {
  await GetStorage.init();
  await Get.putAsync(() => PrinterService().init());
  ApiService.onUnauthorized = () async {
    if (Get.isRegistered<LoginController>()) {
      Get.delete<LoginController>(force: true);
    }
    Get.offAll(() => const LoginScreen());
    Get.snackbar(
      'Phiên đăng nhập hết hạn',
      'Vui lòng đăng nhập lại.',
      snackPosition: SnackPosition.BOTTOM,
    );
  };
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    Get.put(DeepLinkController());

    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Thuong Oc',
      builder: (context, child) {
        return FTheme(data: FThemes.rose.light, child: child!);
      },
      home: const SplashScreen(),
    );
  }
}
