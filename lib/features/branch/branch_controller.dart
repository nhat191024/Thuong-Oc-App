import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:dio/dio.dart';
import '../../core/api/api_service.dart';
import '../../data/models/branch.dart';
import '../auth/login_controller.dart';
import '../auth/login_screen.dart';
import '../table/table_list_screen.dart';
import '../bill/bill_screen.dart';
import '../bill/bill_controller.dart';

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

  void handleQRScan(String? code) {
    if (code == null || code.isEmpty) return;

    String? tableId;
    final uri = Uri.tryParse(code);

    if (uri != null && uri.queryParameters['id'] != null) {
      tableId = uri.queryParameters['id'];
    } else {
      tableId = code;
    }

    if (tableId != null) {
      try {
        Get.delete<BillController>(force: true);
      } catch (e) {
        debugPrint('BillController not found: $e');
      }
      Get.to(() => const BillScreen(), arguments: tableId);
    }
  }

  Future<void> logout() async {
    try {
      await _apiService.dio.post('/logout');
      Get.snackbar('Thông báo', 'Đăng xuất thành công');
    } catch (e) {
      Get.snackbar('Lỗi', 'Đăng xuất thất bại: $e');
    } finally {
      _storage.erase();
      if (Get.isRegistered<LoginController>()) {
        Get.delete<LoginController>();
      }
      Get.offAll(() => const LoginScreen());
    }
  }
}
