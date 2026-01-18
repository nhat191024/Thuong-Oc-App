class User {
  final int id;
  final String username;
  final String name;

  User({required this.id, required this.username, required this.name});

  factory User.fromJson(Map<String, dynamic> json) {
    return User(id: json['id'] ?? 0, username: json['username'] ?? '', name: json['name'] ?? '');
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'username': username, 'name': name};
  }
}
