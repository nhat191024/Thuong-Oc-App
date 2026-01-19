import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import '../../core/api/api_service.dart';
import '../auth/login_screen.dart';
import '../branch/branch_list_screen.dart';

class SplashController extends GetxController {
  final ApiService _apiService = ApiService();
  final GetStorage _storage = GetStorage();

  @override
  void onInit() {
    super.onInit();
    _checkToken();
  }

  Future<void> _checkToken() async {
    await Future.delayed(const Duration(milliseconds: 500));

    final token = _storage.read('access_token');

    if (token == null) {
      Get.offAll(() => const LoginScreen());
      return;
    }

    try {
      await _apiService.dio.get('/check-token');
      Get.offAll(() => const BranchListScreen());
    } catch (e) {
      await _storage.remove('access_token');
      await _storage.remove('user');
      Get.offAll(() => const LoginScreen());
    }
  }
}
