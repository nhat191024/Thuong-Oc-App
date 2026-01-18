import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:forui/forui.dart';
import 'login_controller.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final LoginController controller = Get.put(LoginController());

    return FScaffold(
      header: FHeader(title: const Text('Đăng nhập')),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FTextField(
                control: .managed(controller: controller.usernameController),
                label: const Text('Tên đăng nhập'),
                hint: 'Nhập tên tài khoản',
              ),
              const SizedBox(height: 16),
              FTextField(
                control: .managed(controller: controller.passwordController),
                label: const Text('Mật khẩu'),
                obscureText: true,
                hint: 'Nhập mật khẩu',
              ),
              const SizedBox(height: 24),
              Obx(
                () => FButton(
                  onPress: controller.isLoading.value ? null : controller.login,
                  child: controller.isLoading.value
                      ? const Text('Đang đăng nhập...')
                      : const Text('Đăng nhập'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
