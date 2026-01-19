import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:forui/forui.dart';
import 'branch_controller.dart';

class BranchListScreen extends StatelessWidget {
  const BranchListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(BranchController());

    return FScaffold(
      header: FHeader(title: const Text('Chọn chi nhánh')),
      child: Column(
        children: [
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value) {
                return const Center(child: CircularProgressIndicator());
              }

              if (controller.branches.isEmpty) {
                return const Center(child: Text('Không tìm thấy chi nhánh'));
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: controller.branches.length,
                itemBuilder: (context, index) {
                  final branch = controller.branches[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: FCard(
                      title: Text(branch.name),
                      subtitle: Text('Mã: ${branch.id}'),
                      child: FButton(
                        onPress: () => controller.selectBranch(branch),
                        child: const Text('Chọn'),
                      ),
                    ),
                  );
                },
              );
            }),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: FButton(
              onPress: controller.logout,
              child: const Text('Đăng xuất'),
            ),
          ),
        ],
      ),
    );
  }
}
