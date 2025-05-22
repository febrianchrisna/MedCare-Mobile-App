class User {
  final dynamic id;
  final String username;
  final String email;
  final String role;
  final String? phone;
  final String? address;
  final String? avatar;

  User({
    required this.id,
    required this.username,
    required this.email,
    required this.role,
    this.phone,
    this.address,
    this.avatar,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    // Handle both 'avatar' and 'profileImage' field names from API
    final avatar = json['avatar'] ?? json['profileImage'];

    return User(
      id: json['id'],
      username: json['username'],
      email: json['email'],
      role: json['role'] ?? 'customer',
      phone: json['phone'],
      address: json['address'],
      avatar: avatar,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'role': role,
      'phone': phone,
      'address': address,
      'avatar': avatar,
    };
  }

  @override
  String toString() {
    return toJson().toString();
  }
}
