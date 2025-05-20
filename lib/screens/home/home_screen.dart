import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:medcareapp/providers/auth_provider.dart';
import 'package:medcareapp/providers/medicine_provider.dart';
import 'package:medcareapp/providers/cart_provider.dart';
import 'package:medcareapp/screens/cart/cart_screen.dart';
import 'package:medcareapp/screens/medicine/medicine_list_screen.dart';
import 'package:medcareapp/screens/profile/profile_screen.dart';
import 'package:medcareapp/screens/home/home_tab.dart';
import 'package:medcareapp/utils/theme.dart';
import 'package:badges/badges.dart' as badges;

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    // Initialize after build is complete
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<MedicineProvider>(
        context,
        listen: false,
      ).initializeMedicines();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cartProvider = Provider.of<CartProvider>(context);

    // Define screens for bottom navigation
    final List<Widget> _screens = [
      const HomeTab(),
      const MedicineListScreen(),
      const CartScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppTheme.primaryColor,
        unselectedItemColor: Colors.grey,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.medication_outlined),
            activeIcon: Icon(Icons.medication),
            label: 'Medicines',
          ),
          BottomNavigationBarItem(
            icon: badges.Badge(
              badgeContent: Text(
                cartProvider.itemCount.toString(),
                style: const TextStyle(color: Colors.white, fontSize: 10),
              ),
              badgeStyle: const badges.BadgeStyle(
                badgeColor: AppTheme.primaryColor,
              ),
              showBadge: cartProvider.itemCount > 0,
              child: const Icon(Icons.shopping_cart_outlined),
            ),
            activeIcon: badges.Badge(
              badgeContent: Text(
                cartProvider.itemCount.toString(),
                style: const TextStyle(color: Colors.white, fontSize: 10),
              ),
              badgeStyle: const badges.BadgeStyle(
                badgeColor: AppTheme.primaryColor,
              ),
              showBadge: cartProvider.itemCount > 0,
              child: const Icon(Icons.shopping_cart),
            ),
            label: 'Cart',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
