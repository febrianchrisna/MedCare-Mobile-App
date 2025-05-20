import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:medcareapp/models/medicine.dart';
import 'package:medcareapp/providers/cart_provider.dart';
import 'package:medcareapp/utils/constants.dart';
import 'package:medcareapp/utils/theme.dart';

class MedicineCard extends StatelessWidget {
  final Medicine medicine;
  final VoidCallback onTap;

  const MedicineCard({Key? key, required this.medicine, required this.onTap})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          padding: const EdgeInsets.all(12),
          // Define maximum height to prevent overflow
          constraints: const BoxConstraints(minHeight: 200, maxHeight: 280),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image Container with fixed aspect ratio
              Expanded(
                flex: 3, // Give more space to the image
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      image: DecorationImage(
                        image:
                            medicine.image != null && medicine.image!.isNotEmpty
                                ? NetworkImage(medicine.image!)
                                : NetworkImage(defaultMedicineImage),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // Name with ellipsis
              Expanded(
                flex: 1,
                child: Text(
                  medicine.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // Description with ellipsis
              Expanded(
                flex: 2,
                child: Text(
                  medicine.description,
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // Price and Add Button Row
              SizedBox(
                height: 30, // Fixed height for the bottom row
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Price
                    Text(
                      '\$${medicine.price.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),

                    // Add to cart button
                    AddToCartButton(medicine: medicine),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AddToCartButton extends StatelessWidget {
  final Medicine medicine;

  const AddToCartButton({Key? key, required this.medicine}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);

    return InkWell(
      onTap:
          medicine.stock > 0
              ? () {
                cartProvider.addToCart(medicine);
                Fluttertoast.showToast(
                  msg: "Added to cart",
                  backgroundColor: AppTheme.successColor,
                  textColor: Colors.white,
                );
              }
              : null,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: medicine.stock > 0 ? AppTheme.primaryColor : Colors.grey,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.add, color: Colors.white, size: 18),
      ),
    );
  }
}
