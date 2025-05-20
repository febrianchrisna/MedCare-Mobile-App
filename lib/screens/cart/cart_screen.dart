import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:medcareapp/models/cart_item.dart';
import 'package:medcareapp/providers/cart_provider.dart';
import 'package:medcareapp/providers/auth_provider.dart';
import 'package:medcareapp/screens/cart/checkout_screen.dart';
import 'package:medcareapp/screens/medicine/medicine_detail_screen.dart';
import 'package:medcareapp/utils/constants.dart';
import 'package:medcareapp/utils/theme.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final cartProvider = Provider.of<CartProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final items = cartProvider.items;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Cart'),
        actions: [
          if (items.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () {
                showDialog(
                  context: context,
                  builder:
                      (context) => AlertDialog(
                        title: const Text('Clear Cart'),
                        content: const Text(
                          'Are you sure you want to remove all items from your cart?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () {
                              cartProvider.clearCart();
                              Navigator.pop(context);
                            },
                            child: Text(
                              'Clear',
                              style: TextStyle(color: AppTheme.dangerColor),
                            ),
                          ),
                        ],
                      ),
                );
              },
            ),
        ],
      ),
      body:
          cartProvider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : items.isEmpty
              ? _buildEmptyCart(context)
              : _buildCartList(context, items, cartProvider),
      bottomNavigationBar:
          items.isEmpty
              ? null
              : _buildCheckoutBar(context, cartProvider, authProvider),
    );
  }

  Widget _buildEmptyCart(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_cart_outlined, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text(
            'Your cart is empty',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add items to your cart to proceed with checkout',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              // FIX: Don't use Navigator.pop() as it may cause black screen
              // Instead, navigate to Home tab or Medicine list

              // Option 1: Switch to Home tab using bottom navigation
              int homeTabIndex = 0; // Home is usually the first tab (index 0)
              if (context.findAncestorStateOfType<ScaffoldState>() != null) {
                Navigator.of(
                  context,
                ).pushNamedAndRemoveUntil('/home', (route) => false);
              }

              // Option 2: Directly navigate to the Medicine list (if Option 1 doesn't work)
              // Navigator.of(context).pushReplacement(
              //   MaterialPageRoute(builder: (_) => const MedicineListScreen()),
              // );
            },
            child: const Text('Continue Shopping'),
          ),
        ],
      ),
    );
  }

  Widget _buildCartList(
    BuildContext context,
    List<CartItem> items,
    CartProvider cartProvider,
  ) {
    return ListView.builder(
      itemCount: items.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final item = items[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Medicine Image
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (_) => MedicineDetailScreen(
                              medicineId: item.medicineId,
                            ),
                      ),
                    );
                  },
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      image: DecorationImage(
                        image:
                            item.medicineImage != null &&
                                    item.medicineImage!.isNotEmpty
                                ? NetworkImage(item.medicineImage!)
                                : NetworkImage(defaultMedicineImage),
                        fit: BoxFit.cover,
                        onError:
                            (_, __) => const NetworkImage(defaultMedicineImage),
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 16),

                // Medicine Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.medicineName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Rp ${item.price.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Quantity controls
                      Row(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              children: [
                                InkWell(
                                  onTap: () {
                                    if (item.quantity > 1) {
                                      cartProvider.updateQuantity(
                                        item.id!,
                                        item.quantity - 1,
                                      );
                                    } else {
                                      // Show delete confirmation for last item
                                      showDialog(
                                        context: context,
                                        builder:
                                            (context) => AlertDialog(
                                              title: const Text('Remove Item'),
                                              content: const Text(
                                                'Are you sure you want to remove this item from your cart?',
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed:
                                                      () => Navigator.pop(
                                                        context,
                                                      ),
                                                  child: const Text('Cancel'),
                                                ),
                                                TextButton(
                                                  onPressed: () {
                                                    cartProvider.removeItem(
                                                      item.id!,
                                                    );
                                                    Navigator.pop(context);
                                                  },
                                                  child: Text(
                                                    'Remove',
                                                    style: TextStyle(
                                                      color:
                                                          AppTheme.dangerColor,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                      );
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    child: const Icon(Icons.remove, size: 16),
                                  ),
                                ),
                                Container(
                                  width: 36,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  child: Text(
                                    item.quantity.toString(),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                InkWell(
                                  onTap: () {
                                    cartProvider.updateQuantity(
                                      item.id!,
                                      item.quantity + 1,
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    child: const Icon(Icons.add, size: 16),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: Icon(
                              Icons.delete_outline,
                              color: AppTheme.dangerColor,
                            ),
                            onPressed: () {
                              cartProvider.removeItem(item.id!);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCheckoutBar(
    BuildContext context,
    CartProvider cartProvider,
    AuthProvider authProvider,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Text(
                'Rp ${cartProvider.total.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed:
                  authProvider.isAuthenticated
                      ? () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CheckoutScreen(),
                          ),
                        );
                      }
                      : () {
                        // Arahkan ke halaman login jika belum login
                        Navigator.pushNamed(context, '/login');
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Harus login dahulu untuk checkout'),
                          ),
                        );
                      },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(
                authProvider.isAuthenticated
                    ? 'Proceed to Checkout'
                    : 'Harus login dahulu',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
