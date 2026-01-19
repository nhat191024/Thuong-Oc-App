import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:forui/forui.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'table_controller.dart';
import '../bill/bill_screen.dart';
import '../branch/branch_list_screen.dart';

class TableListScreen extends StatelessWidget {
  const TableListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(TableController());
    final RefreshController refreshController = RefreshController(initialRefresh: false);

    return FScaffold(
      header: FHeader(
        title: Row(
          children: [
            FButton.icon(
              style: FButtonStyle.ghost(),
              onPress: () {
                 if (Navigator.canPop(context)) {
                   Get.back();
                 } else {
                   Get.offAll(() => const BranchListScreen());
                 }
              },
              child: const Icon(Icons.arrow_back),
            ),
            const SizedBox(width: 8),
            Obx(() => Text(controller.branchName.value)),
            const Spacer(),
            FButton.icon(
              style: FButtonStyle.ghost(),
              onPress: () async {
                await controller.fetchTables();
                refreshController.refreshCompleted();
              },
              child: const Icon(Icons.refresh),
            ),
          ],
        ),
      ),
      child: SmartRefresher(
        enablePullDown: true,
        header: const ClassicHeader(),
        controller: refreshController,
        onRefresh: () async {
          await controller.fetchTables();
          refreshController.refreshCompleted();
        },
        child: Obx(() {
          if (controller.isLoading.value) {
            return const Center(child: CircularProgressIndicator());
          }
          if (controller.tables.isEmpty) {
            return const Center(child: Text('Không có bàn nào'));
          }

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 0.85,
            ),
            itemCount: controller.tables.length,
            itemBuilder: (context, index) {
              final table = controller.tables[index];
              final isActive = table.isActive == 'active';

              return GestureDetector(
                onTap: () {
                  Get.to(() => const BillScreen(), arguments: table);
                },
                child: FCard(
                  title: Text(
                    table.tableNumber,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Align(
                    alignment: Alignment.center,
                    child: FBadge(
                      style: isActive ? FBadgeStyle.primary() : FBadgeStyle.secondary(),
                      child: Text(isActive ? 'Hoạt động' : 'Trống', style: TextStyle(fontSize: 10)),
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.table_restaurant,
                      size: 40,
                      color: isActive ? Colors.green : Colors.grey,
                    ),
                  ),
                ),
              );
            },
          );
        }),
      ),
    );
  }
}
