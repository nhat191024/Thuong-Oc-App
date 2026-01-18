class BillDetail {
  final int id;
  final String name;
  final int quantity;
  final int price;
  final int total;
  final String? cookingMethod;
  final String? note;

  BillDetail({
    required this.id,
    required this.name,
    required this.quantity,
    required this.price,
    required this.total,
    this.cookingMethod,
    this.note,
  });

  factory BillDetail.fromJson(Map<String, dynamic> json) {
    return BillDetail(
      id: json['id'],
      name: json['name'],
      quantity: json['quantity'] ?? 0,
      price: json['price'] ?? 0,
      total: json['total'] ?? 0,
      cookingMethod: json['cooking_method'],
      note: json['note'],
    );
  }
}

class BillCustomer {
  final int? id;
  final String? name;
  final String? phone;

  BillCustomer({this.id, this.name, this.phone});

  factory BillCustomer.fromJson(Map<String, dynamic> json) {
    return BillCustomer(id: json['id'], name: json['name'], phone: json['phone']);
  }
}

class Bill {
  final int id;
  final String tableId;
  final String tableNumber;
  final String timeIn;
  final BillCustomer? customer;
  final List<BillDetail> details;
  final int totalAmount;
  final int discountPercent;
  final int discountAmount;
  final String? voucherCode;
  final int finalAmount;
  final String payStatus;

  Bill({
    required this.id,
    required this.tableId,
    required this.tableNumber,
    required this.timeIn,
    this.customer,
    required this.details,
    required this.totalAmount,
    required this.discountPercent,
    required this.discountAmount,
    this.voucherCode,
    required this.finalAmount,
    required this.payStatus,
  });

  factory Bill.fromJson(Map<String, dynamic> json) {
    return Bill(
      id: json['id'],
      tableId: json['table_id'].toString(),
      tableNumber: json['table_number'].toString(),
      timeIn: json['time_in'],
      customer: json['customer'] != null ? BillCustomer.fromJson(json['customer']) : null,
      details: (json['details'] as List?)?.map((x) => BillDetail.fromJson(x)).toList() ?? [],
      totalAmount: json['total_amount'] ?? 0,
      discountPercent: json['discount_percent'] ?? 0,
      discountAmount: json['discount_amount'] ?? 0,
      voucherCode: json['voucher_code'],
      finalAmount: json['final_amount'] ?? 0,
      payStatus: json['pay_status'],
    );
  }
}
