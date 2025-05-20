import 'package:flutter/material.dart';
import 'package:medcareapp/utils/theme.dart'; // Fixed import path
import 'package:medcareapp/screens/orders/orders_screen.dart';

class OrderSuccessScreen extends StatelessWidget {
  const OrderSuccessScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Order Success')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 100),
            const SizedBox(height: 16),
            const Text(
              'Your order has been placed successfully!',
              style: TextStyle(fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            _buildViewOrderButton(context),
          ],
        ),
      ),
    );
  }

  Widget _buildViewOrderButton(BuildContext context) {
    return ElevatedButton(
      onPressed: () {
        // Navigate to orders screen with back button enabled
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const OrdersScreen(showBackButton: true),
          ),
        );
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.primaryColor,
        minimumSize: const Size(double.infinity, 50),
      ),
      child: const Text('View My Orders'),
    );
  }
}
