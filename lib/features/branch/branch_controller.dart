import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:dio/dio.dart';
import '../../core/api/api_service.dart';
import '../../data/models/branch.dart';
import '../table/table_list_screen.dart';

class BranchController extends GetxController {
  final ApiService _apiService = ApiService();
  final GetStorage _storage = GetStorage();

  final branches = <Branch>[].obs;
  final isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    fetchBranches();
  }

  Future<void> fetchBranches() async {
    isLoading.value = true;
    try {
      final response = await _apiService.dio.get('/branches');
      final data = response.data;
      if (data['data'] != null) {
        branches.value = (data['data'] as List).map((e) => Branch.fromJson(e)).toList();
      }
    } catch (e) {
      Get.snackbar('Lỗi', 'Không thể tải danh sách chi nhánh: $e');
    } finally {
      isLoading.value = false;
    }
  }

  void selectBranch(Branch branch) {
    _storage.write('selected_branch', branch.id);
    _storage.write('selected_branch_name', branch.name);
    Get.to(() => const TableListScreen());
  }

  void logout() {
    _storage.erase();
  }
}
