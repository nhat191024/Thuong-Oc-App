import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:forui/forui.dart';
import 'features/splash/splash_screen.dart';
import 'core/controllers/deep_link_controller.dart';
import 'core/services/printer_service.dart';

void main() async {
  await GetStorage.init();
  await Get.putAsync(() => PrinterService().init());
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
