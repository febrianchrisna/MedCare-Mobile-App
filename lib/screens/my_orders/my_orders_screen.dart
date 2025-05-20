import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:medcareapp/models/order.dart';
import 'package:medcareapp/providers/order_provider.dart';
import 'package:medcareapp/widgets/debug_button.dart';

class MyOrdersScreen extends StatelessWidget {
  const MyOrdersScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Orders')),
      body: Consumer<OrderProvider>(
        builder: (context, orderProvider, child) {
          if (orderProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (orderProvider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Error: ${orderProvider.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => orderProvider.fetchUserOrders(),
                    child: const Text('Try Again'),
                  ),
                ],
              ),
            );
          }

          if (orderProvider.orders.isEmpty) {
            return const Center(
              child: Text('No orders found. Start shopping!'),
            );
          }

          return ListView.builder(
            itemCount: orderProvider.orders.length,
            itemBuilder: (context, index) {
              final order = orderProvider.orders[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text('Order #${order.id}'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Status: ${order.status}'),
                      Text('Total: \$${order.totalAmount.toStringAsFixed(2)}'),
                      Text(
                        'Date: ${order.createdAt.toString().substring(0, 10)}',
                      ),
                    ],
                  ),
                  trailing: Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    // Navigate to order details
                    // Navigator.push(context, MaterialPageRoute(
                    //   builder: (context) => OrderDetailsScreen(orderId: order.id!),
                    // ));
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: Builder(
        builder: (context) {
          // Only show debug button in debug mode
          bool isDebugMode = false;
          assert(() {
            isDebugMode = true;
            return true; // assert must return a boolean
          }());
          return isDebugMode ? const DebugButton() : const SizedBox.shrink();
        },
      ),
    );
  }
}
