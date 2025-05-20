import 'package:medcareapp/models/medicine.dart';

class Order {
  final int? id;
  final String userId;
  final List<OrderItem> items;
  final double totalAmount;
  final String status;
  final String? address;
  final String? paymentMethod;
  final String? notes;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Order({
    this.id,
    required this.userId,
    required this.items,
    required this.totalAmount,
    required this.status,
    this.address,
    this.paymentMethod,
    this.notes,
    required this.createdAt,
    this.updatedAt,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    // Parse items - handle both order_details and items field names
    List<OrderItem> orderItems = [];
    if (json.containsKey('order_details')) {
      orderItems =
          (json['order_details'] as List)
              .map((item) => OrderItem.fromJson(item))
              .toList();
    } else if (json.containsKey('items')) {
      orderItems =
          (json['items'] as List)
              .map((item) => OrderItem.fromJson(item))
              .toList();
    }

    return Order(
      id: json['id'],
      userId: json['userId']?.toString() ?? '',
      items: orderItems,
      totalAmount:
          double.tryParse(json['total_amount']?.toString() ?? '0') ?? 0,
      status: json['status'] ?? 'Pending',
      // Handle both snake_case and camelCase field names
      address: json['shipping_address'] ?? json['address'],
      paymentMethod: json['payment_method'] ?? json['paymentMethod'],
      notes: json['notes'],
      createdAt:
          json['createdAt'] != null
              ? DateTime.parse(json['createdAt'])
              : DateTime.now(),
      updatedAt:
          json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'items': items.map((item) => item.toJson()).toList(),
      'total_amount': totalAmount.toString(),
      'status': status,
      'shipping_address': address,
      'payment_method': paymentMethod,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  // Helper method to parse doubles
  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}

class OrderItem {
  final int medicineId;
  final String medicineName;
  final int quantity;
  final double price;
  final String? medicineImage;

  OrderItem({
    required this.medicineId,
    required this.medicineName,
    required this.quantity,
    required this.price,
    this.medicineImage,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    // Fix for missing or empty medicine name
    String name = 'Unknown Medicine';

    // First try to get the name directly
    if (json.containsKey('medicineName') && json['medicineName'] != null) {
      name = json['medicineName'];
    }
    // Then check if there's a nested medicine object
    else if (json.containsKey('medicine') && json['medicine'] != null) {
      final medicine = json['medicine'];
      if (medicine is Map<String, dynamic> && medicine.containsKey('name')) {
        name = medicine['name'];
      }
    }

    return OrderItem(
      medicineId: json['medicineId'] ?? 0,
      medicineName: name, // Use the determined name
      quantity: json['quantity'] ?? 1,
      price: double.tryParse(json['price']?.toString() ?? '0') ?? 0,
      medicineImage:
          json.containsKey('medicine') && json['medicine'] != null
              ? json['medicine']['image']
              : json['medicineImage'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'medicineId': medicineId,
      'medicineName': medicineName,
      'quantity': quantity,
      'price': price,
      'medicineImage': medicineImage,
    };
  }
}
