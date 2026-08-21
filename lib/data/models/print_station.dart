class PrintStationPrinter {
  final int id;
  final String name;
  final PrinterConnection connection;

  const PrintStationPrinter({
    required this.id,
    required this.name,
    required this.connection,
  });

  factory PrintStationPrinter.fromJson(Map<String, dynamic> json) {
    return PrintStationPrinter(
      id: int.tryParse(json['id'].toString()) ?? 0,
      name: json['name']?.toString() ?? '',
      connection: PrinterConnection.fromJson(
        Map<String, dynamic>.from(json['connection'] as Map? ?? const {}),
      ),
    );
  }
}

class PrinterConnection {
  final String type;
  final String host;
  final int port;
  final int timeoutSeconds;

  const PrinterConnection({
    required this.type,
    required this.host,
    required this.port,
    required this.timeoutSeconds,
  });

  factory PrinterConnection.fromJson(Map<String, dynamic> json) {
    return PrinterConnection(
      type: json['type']?.toString() ?? '',
      host: json['host']?.toString() ?? '',
      port: int.tryParse(json['port'].toString()) ?? 0,
      timeoutSeconds: int.tryParse(json['timeout_seconds'].toString()) ?? 3,
    );
  }
}

class PrintStationMeta {
  final int branchId;
  final String channel;
  final String pusherChannel;
  final String event;
  final String authEndpoint;

  const PrintStationMeta({
    required this.branchId,
    required this.channel,
    required this.pusherChannel,
    required this.event,
    required this.authEndpoint,
  });

  factory PrintStationMeta.fromJson(Map<String, dynamic> json) {
    return PrintStationMeta(
      branchId: int.tryParse(json['branch_id'].toString()) ?? 0,
      channel: json['channel']?.toString() ?? '',
      pusherChannel: json['pusher_channel']?.toString() ?? '',
      event: json['event']?.toString() ?? 'print.job.requested',
      authEndpoint:
          json['auth_endpoint']?.toString() ?? '/api/broadcasting/auth',
    );
  }
}

class PrintStationKitchen {
  final int id;
  final String name;
  final String channel;
  final String pusherChannel;

  const PrintStationKitchen({
    required this.id,
    required this.name,
    required this.channel,
    required this.pusherChannel,
  });

  factory PrintStationKitchen.fromJson(Map<String, dynamic> json) {
    return PrintStationKitchen(
      id: int.tryParse(json['id'].toString()) ?? 0,
      name: json['name']?.toString() ?? '',
      channel: json['channel']?.toString() ?? '',
      pusherChannel: json['pusher_channel']?.toString() ?? '',
    );
  }

  String privateChannelName(int branchId) {
    final value = pusherChannel.isNotEmpty
        ? pusherChannel
        : channel.isNotEmpty
        ? channel
        : 'print-stations.$branchId.kitchens.$id';
    return value.replaceFirst(RegExp(r'^private-'), '');
  }
}

class PrintJob {
  final String requestId;
  final String tableNumber;
  final String dishName;
  final String cookingMethod;
  final num quantity;
  final String note;
  final DateTime receivedAt;

  const PrintJob({
    required this.requestId,
    required this.tableNumber,
    required this.dishName,
    required this.cookingMethod,
    required this.quantity,
    required this.note,
    required this.receivedAt,
  });

  factory PrintJob.fromJson(Map<String, dynamic> json) {
    return PrintJob(
      requestId: json['request_id']?.toString() ?? '',
      tableNumber: json['table_number']?.toString() ?? '',
      dishName: json['dish_name']?.toString() ?? '',
      cookingMethod: json['cooking_method']?.toString() ?? '',
      quantity: json['quantity'] is num
          ? json['quantity'] as num
          : num.tryParse(json['quantity'].toString()) ?? 0,
      note: json['note']?.toString() ?? '',
      receivedAt: DateTime.now(),
    );
  }
}
