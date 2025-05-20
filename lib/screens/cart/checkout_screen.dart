import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:medcareapp/providers/cart_provider.dart';
import 'package:medcareapp/providers/auth_provider.dart';
import 'package:medcareapp/providers/order_provider.dart';
import 'package:medcareapp/screens/cart/order_success_screen.dart';
import 'package:medcareapp/utils/theme.dart';
import 'package:medcareapp/services/api_service.dart';
import 'package:medcareapp/models/order.dart'; // Add this import

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({Key? key}) : super(key: key);

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _addressController = TextEditingController();
  String _paymentMethod = 'Cash on Delivery';
  final _notesController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  final List<String> _paymentMethods = [
    'Cash on Delivery',
    'Credit Card',
    'Bank Transfer',
    'Digital Wallet',
  ];

  @override
  void dispose() {
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _placeOrder() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      try {
        final cartProvider = Provider.of<CartProvider>(context, listen: false);
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final orderProvider = Provider.of<OrderProvider>(
          context,
          listen: false,
        );
        final items = cartProvider.items;

        // Ensure we have a valid user ID
        final userId = authProvider.user?.id?.toString();
        if (userId == null || userId.isEmpty) {
          throw Exception('Cannot create order: User ID not available');
        }

        print('DEBUG in checkout: Using userId: $userId');
        print('DEBUG in checkout: User object: ${authProvider.user?.toJson()}');

        // Create order items list with null safety
        final orderItems =
            items
                .map(
                  (item) => OrderItem(
                    medicineId: item.medicineId,
                    medicineName: item.medicineName,
                    quantity: item.quantity,
                    price: item.price,
                    medicineImage: item.medicineImage,
                  ),
                )
                .toList();

        // Create Order object with notes field included
        final order = Order(
          userId: userId,
          items: orderItems,
          totalAmount: cartProvider.total,
          status: 'Pending',
          address: _addressController.text,
          paymentMethod: _paymentMethod,
          notes: _notesController.text,
          createdAt: DateTime.now(),
        );

        // Debug the order structure before sending
        print('Creating order with OrderProvider: ${order.toJson()}');

        // Use OrderProvider to create the order instead of direct API call
        final success = await orderProvider.createOrder(order);

        if (!success) {
          throw Exception(orderProvider.error ?? 'Failed to create order');
        }

        // Clear cart
        await cartProvider.clearCart();

        // Explicitly refresh orders
        await orderProvider.fetchUserOrders(forceRefresh: true);

        // Navigate to success screen
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const OrderSuccessScreen()),
          );
        }
      } catch (e) {
        setState(() {
          _error = e.toString();
        });
        print('Error creating order: $_error');
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartProvider = Provider.of<CartProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;

    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // User Info
                      Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Contact Information',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text('Name: ${user?.username ?? ""}'),
                              const SizedBox(height: 4),
                              Text('Email: ${user?.email ?? ""}'),
                            ],
                          ),
                        ),
                      ),

                      // Shipping Address
                      Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Shipping Address',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _addressController,
                                decoration: const InputDecoration(
                                  hintText: 'Enter your complete address',
                                  labelText: 'Address',
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter your shipping address';
                                  }
                                  return null;
                                },
                                maxLines: 3,
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Payment Method
                      Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Payment Method',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              DropdownButtonFormField<String>(
                                value: _paymentMethod,
                                decoration: const InputDecoration(
                                  labelText: 'Select Payment Method',
                                ),
                                items:
                                    _paymentMethods.map((method) {
                                      return DropdownMenuItem(
                                        value: method,
                                        child: Text(method),
                                      );
                                    }).toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _paymentMethod = value!;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Order Notes
                      Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Additional Notes (Optional)',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _notesController,
                                decoration: const InputDecoration(
                                  hintText: 'Enter any special instructions',
                                  labelText: 'Notes',
                                ),
                                maxLines: 3,
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Order Summary
                      Card(
                        margin: const EdgeInsets.only(bottom: 24),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Order Summary',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Items:'),
                                  Text('${cartProvider.itemCount}'),
                                ],
                              ),
                              const Divider(),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Subtotal:'),
                                  Text(
                                    'Rp ${cartProvider.total.toStringAsFixed(2)}',
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: const [
                                  Text('Shipping:'),
                                  Text('Rp 0.00'),
                                ],
                              ),
                              const Divider(),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Total:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    'Rp ${cartProvider.total.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: AppTheme.primaryColor,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Error message
                      if (_error != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.dangerColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.error_outline,
                                color: AppTheme.dangerColor,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: TextStyle(color: AppTheme.dangerColor),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Place Order Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _placeOrder,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: Text(
                            _isLoading ? 'Placing Order...' : 'Place Order',
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
    );
  }
}
