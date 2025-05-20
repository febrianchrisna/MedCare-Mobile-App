class Medicine {
  final int? id;
  final String name;
  final String description;
  final double price;
  final String? image;
  final String category;
  final int stock;
  final String? manufacturer;
  final String? dosage;
  final DateTime? expiryDate;
  final bool featured;

  Medicine({
    this.id,
    required this.name,
    required this.description,
    required this.price,
    this.image,
    required this.category,
    required this.stock,
    this.manufacturer,
    this.dosage,
    this.expiryDate,
    this.featured = false,
  });

  factory Medicine.fromJson(Map<String, dynamic> json) {
    return Medicine(
      id: json['id'],
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      price: double.parse(json['price'].toString()),
      image: json['image'],
      category: json['category'] ?? '',
      stock: int.parse(json['stock'].toString()),
      manufacturer: json['manufacturer'],
      dosage: json['dosage'],
      expiryDate:
          json['expiry_date'] != null
              ? DateTime.parse(json['expiry_date'])
              : null,
      featured: json['featured'] == true || json['featured'] == 1,
    );
  }

  // For SQLite storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'image': image,
      'category': category,
      'stock': stock,
      'manufacturer': manufacturer,
      'dosage': dosage,
      'expiry_date': expiryDate?.toIso8601String(),
      'featured': featured ? 1 : 0,
    };
  }

  // For creating a copy with some changed properties
  Medicine copyWith({
    int? id,
    String? name,
    String? description,
    double? price,
    String? image,
    String? category,
    int? stock,
    String? manufacturer,
    String? dosage,
    DateTime? expiryDate,
    bool? featured,
  }) {
    return Medicine(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      image: image ?? this.image,
      category: category ?? this.category,
      stock: stock ?? this.stock,
      manufacturer: manufacturer ?? this.manufacturer,
      dosage: dosage ?? this.dosage,
      expiryDate: expiryDate ?? this.expiryDate,
      featured: featured ?? this.featured,
    );
  }
}
