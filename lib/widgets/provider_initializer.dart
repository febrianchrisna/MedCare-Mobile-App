import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:medcareapp/providers/medicine_provider.dart';
import 'package:medcareapp/providers/auth_provider.dart';
import 'package:medcareapp/providers/cart_provider.dart';
import 'package:medcareapp/providers/order_provider.dart';

class ProviderInitializer extends StatefulWidget {
  final Widget child;

  const ProviderInitializer({Key? key, required this.child}) : super(key: key);

  @override
  State<ProviderInitializer> createState() => _ProviderInitializerState();
}

class _ProviderInitializerState extends State<ProviderInitializer> {
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    // Defer initialization to after first frame to avoid build-time errors
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeProviders();
    });
  }

  // Separate method to initialize all providers
  Future<void> _initializeProviders() async {
    if (_initialized) return;

    try {
      // Initialize auth provider first
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.loadUserData();

      // Initialize medicine provider
      final medicineProvider = Provider.of<MedicineProvider>(
        context,
        listen: false,
      );
      await medicineProvider.initializeMedicines();

      // Initialize cart and orders if user is authenticated
      if (authProvider.isAuthenticated) {
        final cartProvider = Provider.of<CartProvider>(context, listen: false);
        await cartProvider.initCart();

        // Pre-load orders if needed
        final orderProvider = Provider.of<OrderProvider>(
          context,
          listen: false,
        );

        // Make sure to set the user ID from auth provider
        if (authProvider.user?.id != null) {
          print(
            'DEBUG: Setting userId in OrderProvider: ${authProvider.user!.id}',
          );
          orderProvider.setUserId(authProvider.user!.id.toString());
        } else {
          print('WARNING: User authenticated but no ID available');
        }

        await orderProvider.fetchUserOrders();
      }

      _initialized = true;
    } catch (e) {
      debugPrint('Error initializing providers: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
