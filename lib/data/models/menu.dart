class DishVariant {
  final int id;
  final String name;
  final int additionalPrice;

  DishVariant({required this.id, required this.name, required this.additionalPrice});

  factory DishVariant.fromJson(Map<String, dynamic> json) {
    return DishVariant(
      id: json['id'],
      name: json['name'],
      additionalPrice: json['additional_price'] ?? 0,
    );
  }
}

class Food {
  final int id;
  final String name;
  final bool isFavorite;
  final int price;
  final String? image;
  final List<DishVariant> dishes;

  Food({
    required this.id,
    required this.name,
    required this.isFavorite,
    required this.price,
    this.image,
    required this.dishes,
  });

  factory Food.fromJson(Map<String, dynamic> json) {
    return Food(
      id: json['id'],
      name: json['name'],
      isFavorite: json['is_favorite'] ?? false,
      price: json['price'] ?? 0,
      image: json['image'],
      dishes: (json['dishes'] as List?)?.map((x) => DishVariant.fromJson(x)).toList() ?? [],
    );
  }
}

class MenuCategory {
  final int id;
  final String name;
  final List<Food> foods;

  MenuCategory({required this.id, required this.name, required this.foods});

  factory MenuCategory.fromJson(Map<String, dynamic> json) {
    return MenuCategory(
      id: json['id'],
      name: json['name'],
      foods: (json['foods'] as List?)?.map((x) => Food.fromJson(x)).toList() ?? [],
    );
  }
}
