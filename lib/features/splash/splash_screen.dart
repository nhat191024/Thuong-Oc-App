import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:forui/forui.dart';
import 'splash_controller.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Get.put(SplashController());

    return const FScaffold(child: Center(child: CircularProgressIndicator()));
  }
}
