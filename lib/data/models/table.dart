class TableModel {
  final String id;
  final String name;
  final String tableNumber;
  final String isActive;

  TableModel({
    required this.id,
    required this.name,
    required this.tableNumber,
    required this.isActive,
  });

  factory TableModel.fromJson(Map<String, dynamic> json) {
    return TableModel(
      id: json['id'].toString(),
      name: json['name'],
      tableNumber: json['table_number'].toString(),
      isActive: json['is_active'],
    );
  }
}
