import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../data/models/print_station.dart';
import 'print_station_controller.dart';

class PrintStationScreen extends StatelessWidget {
  const PrintStationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.isRegistered<PrintStationController>()
        ? Get.find<PrintStationController>()
        : Get.put(PrintStationController());

    return FScaffold(
      header: FHeader(
        title: Row(
          children: [
            FButton.icon(
              style: FButtonStyle.ghost(),
              onPress: Get.back,
              child: const Icon(Icons.arrow_back),
            ),
            const SizedBox(width: 8),
            const Expanded(child: Text('Trạm in')),
            FButton.icon(
              style: FButtonStyle.ghost(),
              onPress: () => _showKitchenSettings(context, controller),
              child: const Icon(Icons.settings_outlined),
            ),
            FButton.icon(
              style: FButtonStyle.ghost(),
              onPress: controller.loadStation,
              child: const Icon(Icons.refresh),
            ),
          ],
        ),
      ),
      child: Obx(() {
        if (controller.isLoading.value && controller.printers.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        return RefreshIndicator(
          onRefresh: controller.loadStation,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _ConnectionBanner(status: controller.connectionStatus.value),
              if (controller.errorMessage.value != null) ...[
                const SizedBox(height: 12),
                Text(
                  controller.errorMessage.value!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 12),
              _KitchenSelectionCard(
                kitchens: controller.kitchens,
                selectedIds: controller.selectedKitchenIds,
                onTap: () => _showKitchenSettings(context, controller),
              ),
              const SizedBox(height: 20),
              Text(
                'Chọn máy sẽ in',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _PrinterSelectBox(
                printers: controller.availablePrinters,
                selectedPrinterId: controller.selectedPrinterId.value,
                onChanged: (printer) => controller.selectPrinter(printer),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FButton(
                  onPress:
                      controller.isTestingPrinter.value ||
                          controller.isProcessingQueue.value
                      ? null
                      : controller.testSelectedPrinter,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (controller.isTestingPrinter.value)
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        const Icon(Icons.print),
                      const SizedBox(width: 8),
                      Text(
                        controller.isTestingPrinter.value
                            ? 'Đang in thử...'
                            : 'In thử',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Hàng đợi in (${controller.jobs.length})',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (controller.jobs.isEmpty)
                const _EmptyCard(
                  message: 'Hàng đợi trống, đang chờ đơn mới từ bếp',
                  icon: Icons.receipt_long_outlined,
                )
              else
                ...controller.jobs.map(
                  (job) => _PrintJobCard(
                    job: job,
                    isPrinting: controller.isJobPrinting(job),
                    hasError: controller.didJobFail(job),
                    onRetry: controller.retryPrintQueue,
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }

  Future<void> _showKitchenSettings(
    BuildContext context,
    PrintStationController controller,
  ) async {
    final draft = controller.selectedKitchenIds.toSet();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Bếp nhận đơn'),
          content: SizedBox(
            width: double.maxFinite,
            child: controller.kitchens.isEmpty
                ? const Text('Chi nhánh này chưa có bếp để chọn.')
                : ListView(
                    shrinkWrap: true,
                    children: controller.kitchens
                        .map(
                          (kitchen) => CheckboxListTile(
                            value: draft.contains(kitchen.id),
                            title: Text(
                              kitchen.name.isEmpty
                                  ? 'Bếp #${kitchen.id}'
                                  : kitchen.name,
                            ),
                            controlAffinity: ListTileControlAffinity.leading,
                            contentPadding: EdgeInsets.zero,
                            onChanged: (checked) {
                              setState(() {
                                if (checked ?? false) {
                                  draft.add(kitchen.id);
                                } else {
                                  draft.remove(kitchen.id);
                                }
                              });
                            },
                          ),
                        )
                        .toList(),
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () async {
                await controller.saveKitchenSelection(draft);
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
              },
              child: const Text('Lưu'),
            ),
          ],
        ),
      ),
    );
  }
}

class _KitchenSelectionCard extends StatelessWidget {
  final List<PrintStationKitchen> kitchens;
  final Set<int> selectedIds;
  final VoidCallback onTap;

  const _KitchenSelectionCard({
    required this.kitchens,
    required this.selectedIds,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final selectedNames = kitchens
        .where((kitchen) => selectedIds.contains(kitchen.id))
        .map((kitchen) => kitchen.name.isEmpty ? 'Bếp #${kitchen.id}' : kitchen.name)
        .toList();
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        onTap: onTap,
        leading: const Icon(Icons.soup_kitchen_outlined),
        title: const Text('Bếp đang nhận đơn'),
        subtitle: Text(
          selectedNames.isEmpty ? 'Chưa chọn bếp' : selectedNames.join(', '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}

class _ConnectionBanner extends StatelessWidget {
  final String status;

  const _ConnectionBanner({required this.status});

  @override
  Widget build(BuildContext context) {
    final connected = status == 'Đang nhận đơn';
    final color = connected ? Colors.green : Colors.orange;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(90)),
      ),
      child: Row(
        children: [
          Icon(connected ? Icons.wifi : Icons.wifi_find, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              status,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrinterSelectBox extends StatelessWidget {
  final List<PrintStationPrinter> printers;
  final int? selectedPrinterId;
  final ValueChanged<PrintStationPrinter> onChanged;

  const _PrinterSelectBox({
    required this.printers,
    required this.selectedPrinterId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: DropdownButtonFormField<int>(
        key: ValueKey(selectedPrinterId),
        initialValue: selectedPrinterId,
        isExpanded: true,
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.print_outlined),
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
        items: printers
            .map(
              (printer) => DropdownMenuItem<int>(
                value: printer.id,
                child: Text(
                  _printerLabel(printer),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            )
            .toList(),
        onChanged: (printerId) {
          if (printerId == null) return;
          for (final printer in printers) {
            if (printer.id == printerId) {
              onChanged(printer);
              return;
            }
          }
        },
      ),
    );
  }

  String _printerLabel(PrintStationPrinter printer) {
    final name = printer.name.isEmpty ? 'Máy in #${printer.id}' : printer.name;
    if (printer.connection.type == 'local') {
      return '$name · Tích hợp';
    }
    final host = printer.connection.host;
    final address = host.isEmpty
        ? 'Chưa có địa chỉ'
        : '$host:${printer.connection.port}';
    return '$name · $address';
  }
}

class _PrintJobCard extends StatelessWidget {
  final PrintJob job;
  final bool isPrinting;
  final bool hasError;
  final VoidCallback onRetry;

  const _PrintJobCard({
    required this.job,
    required this.isPrinting,
    required this.hasError,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                FBadge(
                  style: FBadgeStyle.primary(),
                  child: Text('Bàn ${job.tableNumber}'),
                ),
                const Spacer(),
                Text(
                  DateFormat('HH:mm:ss').format(job.receivedAt),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '${_formatQuantity(job.quantity)} × ${job.dishName}',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            if (job.cookingMethod.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('Chế biến: ${job.cookingMethod}'),
            ],
            if (job.note.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Ghi chú: ${job.note}',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: _buildQueueStatus(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQueueStatus(BuildContext context) {
    if (isPrinting) {
      return const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 8),
          Text('Đang in...'),
        ],
      );
    }
    if (hasError) {
      return TextButton.icon(
        onPressed: onRetry,
        icon: Icon(Icons.refresh, color: Theme.of(context).colorScheme.error),
        label: const Text('In lại'),
      );
    }
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.schedule, size: 18, color: Colors.grey),
        SizedBox(width: 6),
        Text('Đang chờ'),
      ],
    );
  }

  String _formatQuantity(num value) {
    return value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toString();
  }
}

class _EmptyCard extends StatelessWidget {
  final String message;
  final IconData icon;

  const _EmptyCard({
    required this.message,
    this.icon = Icons.print_disabled_outlined,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey.withAlpha(18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withAlpha(50)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 34, color: Colors.grey),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
