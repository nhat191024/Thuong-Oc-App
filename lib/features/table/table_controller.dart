import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:dio/dio.dart';
import '../../core/api/api_service.dart';
import '../../data/models/table.dart';

class TableController extends GetxController {
  final ApiService _apiService = ApiService();
  final GetStorage _storage = GetStorage();

  final tables = <TableModel>[].obs;
  final isLoading = false.obs;
  final branchName = ''.obs;

  @override
  void onInit() {
    super.onInit();
    branchName.value = _storage.read('selected_branch_name') ?? 'Branch';
    fetchTables();
  }

  Future<void> fetchTables() async {
    final branchId = _storage.read('selected_branch');
    if (branchId == null) return;

    isLoading.value = true;
    try {
      final response = await _apiService.dio.get(
        '/tables',
        queryParameters: {'branch_id': branchId},
      );

      final data = response.data;
      List<dynamic> listData = [];

      print(data);

      if (data is Map && data['data'] != null && data['data'] is List) {
        listData = data['data'];
      } else if (data is List) {
        listData = data;
      }

      if (listData.isNotEmpty) {
        tables.value = listData.map((e) => TableModel.fromJson(e)).toList();
      }
    } catch (e) {
      debugPrint(e.toString());
      Get.snackbar('Lỗi', 'Không thể tải danh sách bàn: $e');
    } finally {
      isLoading.value = false;
    }
  }

  void selectTable(TableModel table) {
    Get.snackbar('Selected', 'Table ${table.tableNumber}');
  }
}
