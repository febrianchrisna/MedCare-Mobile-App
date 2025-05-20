import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:medcareapp/models/order.dart';
import 'package:medcareapp/providers/order_provider.dart';
import 'package:medcareapp/providers/auth_provider.dart';
import 'package:medcareapp/screens/orders/order_detail_screen.dart';
import 'package:medcareapp/utils/theme.dart';
import 'package:intl/intl.dart';
import 'package:medcareapp/utils/local_order_updates_manager.dart';

class OrdersScreen extends StatefulWidget {
  // Add a parameter to control whether to show the back button
  final bool showBackButton;

  const OrdersScreen({
    Key? key,
    this.showBackButton =
        true, // Changed from false to true to show back button by default
  }) : super(key: key);

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  @override
  void initState() {
    super.initState();
    // Use addPostFrameCallback to ensure this runs after the initial build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Check if user is authenticated before loading orders
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.isAuthenticated) {
        print('OrdersScreen: User is authenticated, fetching orders');
        // Force refresh orders when screen is opened
        _fetchOrdersWithErrorHandling();
      } else {
        print('OrdersScreen: User is NOT authenticated');
        // Show login prompt if not authenticated
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please log in to view your orders'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    });
  }

  // Add a method to fetch orders with proper error handling
  Future<void> _fetchOrdersWithErrorHandling() async {
    try {
      await Provider.of<OrderProvider>(
        context,
        listen: false,
      ).fetchUserOrders(forceRefresh: true);
    } catch (e) {
      print('Error fetching orders: $e');

      // Check if the widget is still mounted before showing UI
      if (!mounted) return;

      // Check if the error is an authentication error (403)
      if (e.toString().contains('403') ||
          e.toString().contains('Access denied') ||
          e.toString().contains('token is valid')) {
        // Show authentication error dialog
        showDialog(
          context: context,
          builder:
              (ctx) => AlertDialog(
                title: const Text('Authentication Error'),
                content: const Text(
                  'Your session has expired or you\'ve been logged out. '
                  'Please log in again to view your orders.',
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      // Clear current auth data
                      Provider.of<AuthProvider>(
                        context,
                        listen: false,
                      ).logout();
                      // Navigate to login
                      Navigator.pushNamed(context, '/login');
                    },
                    child: const Text('Log In'),
                  ),
                ],
              ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    // If not logged in, show login prompt
    if (!authProvider.isAuthenticated) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('My Orders'),
          // Show back button in login prompt if needed
          automaticallyImplyLeading: widget.showBackButton,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.shopping_bag_outlined,
                size: 80,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              const Text(
                'Please log in to view your orders',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  // Navigate to login screen
                  Navigator.pushNamed(context, '/login');
                },
                child: const Text('Log In'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Orders'),
        automaticallyImplyLeading: widget.showBackButton,
        leading:
            widget.showBackButton
                ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    // Perbaikan: jika tidak bisa pop, arahkan ke home
                    if (Navigator.canPop(context)) {
                      Navigator.of(context).pop();
                    } else {
                      Navigator.of(context).pushReplacementNamed('/home');
                    }
                  },
                )
                : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              Provider.of<OrderProvider>(
                context,
                listen: false,
              ).fetchUserOrders();
            },
          ),
        ],
      ),
      body: Consumer<OrderProvider>(
        builder: (context, orderProvider, child) {
          // Show detailed error information
          if (orderProvider.error != null) {
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 60,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Error: ${orderProvider.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => orderProvider.fetchUserOrders(),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          // Show loading indicator
          if (orderProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final orders = orderProvider.orders;
          if (orders.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.shopping_bag_outlined,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No orders yet',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Your order history will appear here',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              return FutureBuilder<Order>(
                // Apply local updates to each order before displaying
                future: LocalOrderUpdatesManager.applyLocalUpdates(order),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SizedBox(
                      height: 100,
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  final updatedOrder = snapshot.data ?? order;
                  return _buildOrderCard(context, updatedOrder);
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildOrderCard(BuildContext context, Order order) {
    // Log the order data we're displaying
    print(
      'Building order card with: address=${order.address}, payment=${order.paymentMethod}',
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () async {
          // Check if order.id is not null before navigating
          if (order.id != null) {
            // Capture ScaffoldMessengerState before any async operations
            final scaffoldMessenger = ScaffoldMessenger.of(context);

            try {
              // Use async/await pattern with result
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => OrderDetailScreen(orderId: order.id!),
                ),
              );

              // Safety check - if widget is no longer in tree, abort further operations
              if (!mounted) return;

              // Handle navigation result - safely check result with null safety
              if (result != null && (result == 'deleted' || result == true)) {
                // Use pushReplacement with context - wrap in try/catch for better error reporting
                try {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => const OrdersScreen(showBackButton: true),
                    ),
                  );
                } catch (navError) {
                  print('Navigation error after order edit: $navError');
                  // Don't throw - just log the error and continue
                }
              } else {
                // If result isn't what we expect or is null, just refresh orders
                print(
                  'Refreshing orders after returning from details screen. Result: $result',
                );
                try {
                  final provider = Provider.of<OrderProvider>(
                    context,
                    listen: false,
                  );
                  if (provider != null) {
                    await provider.fetchUserOrders(forceRefresh: true);
                  }
                } catch (refreshError) {
                  print('Error refreshing orders: $refreshError');
                }
              }
            } catch (e) {
              print('Error in order card tap handler: $e');

              // Only attempt to show error if mounted (safer approach)
              if (mounted) {
                // Post a task to show error after the current frame is complete
                Future.microtask(() {
                  try {
                    // Use the captured scaffoldMessenger instead of looking it up again
                    scaffoldMessenger.showSnackBar(
                      SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  } catch (snackbarError) {
                    // Fallback error handling if even showing a snackbar fails
                    print('Failed to show error snackbar: $snackbarError');
                  }
                });
              }
            }
          } else {
            // Show an error message if order ID is null
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Cannot view details: Order ID is missing'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Order #${order.id}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  _buildStatusBadge(order.status),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Date: ${DateFormat('MMM dd, yyyy').format(order.createdAt)}',
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
              const SizedBox(height: 8),
              const Divider(),
              ...order.items
                  .take(2)
                  .map(
                    (item) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child:
                                item.medicineImage != null
                                    ? Image.network(
                                      item.medicineImage!,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (_, __, ___) =>
                                              const Icon(Icons.medication),
                                    )
                                    : const Icon(Icons.medication),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  // Display appropriate text when medicine name is unknown
                                  item.medicineName.isEmpty ||
                                          item.medicineName ==
                                              'Unknown Medicine'
                                      ? 'Medicine #${item.medicineId}'
                                      : item.medicineName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  '${item.quantity} × \$${item.price.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
              if (order.items.length > 2)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '+ ${order.items.length - 2} more items',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '\$${order.totalAmount.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ), // Tutup Padding
      ), // Tutup InkWell - Fixed: changed semicolon to comma here
    ); // Tutup Card - Keep semicolon here
  } // Tutup method _buildOrderCard

  Widget _buildStatusBadge(String status) {
    Color badgeColor;
    switch (status.toLowerCase()) {
      case 'pending':
        badgeColor = Colors.orange;
        break;
      case 'processing':
        badgeColor = Colors.blue;
        break;
      case 'shipped':
        badgeColor = Colors.indigo;
        break;
      case 'delivered':
        badgeColor = Colors.green;
        break;
      case 'cancelled':
        badgeColor = Colors.red;
        break;
      default:
        badgeColor = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.1),
        border: Border.all(color: badgeColor),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: badgeColor,
          fontWeight: FontWeight.w500,
          fontSize: 12,
        ),
      ),
    );
  }
}
