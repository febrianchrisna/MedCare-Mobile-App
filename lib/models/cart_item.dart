import 'package:medcareapp/models/medicine.dart';

class CartItem {
  final int? id;
  final int medicineId;
  final String medicineName;
  final String? medicineImage;
  final double price;
  int quantity;

  CartItem({
    this.id,
    required this.medicineId,
    required this.medicineName,
    this.medicineImage,
    required this.price,
    required this.quantity,
  });

  double get total => price * quantity;

  factory CartItem.fromMedicine(Medicine medicine, {int quantity = 1}) {
    return CartItem(
      medicineId: medicine.id!,
      medicineName: medicine.name,
      medicineImage: medicine.image,
      price: medicine.price,
      quantity: quantity,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'medicineId': medicineId,
      'medicineName': medicineName,
      'medicineImage': medicineImage,
      'price': price,
      'quantity': quantity,
    };
  }

  factory CartItem.fromMap(Map<String, dynamic> map) {
    return CartItem(
      id: map['id'],
      medicineId: map['medicineId'],
      medicineName: map['medicineName'],
      medicineImage: map['medicineImage'],
      price: map['price'],
      quantity: map['quantity'],
    );
  }
}
