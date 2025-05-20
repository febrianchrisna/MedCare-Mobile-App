import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:medcareapp/models/cart_item.dart';
import 'package:medcareapp/models/medicine.dart';
import 'package:medcareapp/services/database_helper.dart';
import 'package:medcareapp/utils/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CartProvider extends ChangeNotifier {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  List<CartItem> _items = [];
  bool _isLoading = false;
  String? _error;

  // Getters
  List<CartItem> get items => _items;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get itemCount => _items.fold(0, (sum, item) => sum + item.quantity);
  double get total =>
      _items.fold(0, (sum, item) => sum + (item.price * item.quantity));
  bool get isEmpty => _items.isEmpty;

  // Initialize cart
  Future<void> initCart() async {
    _setLoading(true);
    try {
      await _loadCartFromStorage();
    } catch (e) {
      _error = 'Failed to initialize cart: $e';
    } finally {
      _setLoading(false);
    }
  }

  // Load cart from database and shared preferences
  Future<void> _loadCartFromStorage() async {
    try {
      // Load from SQLite
      _items = await _dbHelper.getCartItems();

      // Alternatively, load from SharedPreferences if needed
      final prefs = await SharedPreferences.getInstance();
      final cartJson = prefs.getString(ApiConstants.cartKey);

      if (cartJson != null && _items.isEmpty) {
        final List<dynamic> cartData = json.decode(cartJson);
        _items = cartData.map((item) => CartItem.fromMap(item)).toList();

        // Sync back to SQLite
        await _syncCartToDatabase();
      }

      notifyListeners();
    } catch (e) {
      _error = 'Failed to load cart: $e';
    }
  }

  // Add item to cart
  Future<void> addToCart(Medicine medicine, [int quantity = 1]) async {
    if (medicine.id == null) {
      _error = 'Invalid medicine';
      notifyListeners();
      return;
    }

    _setLoading(true);
    try {
      // Check if item already exists in cart
      final existingItem = await _dbHelper.getCartItemByMedicineId(
        medicine.id!,
      );

      if (existingItem != null) {
        // Update quantity
        existingItem.quantity += quantity;
        await _dbHelper.updateCartItem(existingItem);

        // Update local list
        final index = _items.indexWhere(
          (item) => item.medicineId == medicine.id,
        );
        if (index != -1) {
          _items[index].quantity += quantity;
        } else {
          _items.add(existingItem);
        }
      } else {
        // Add new item
        final newItem = CartItem.fromMedicine(medicine, quantity: quantity);
        final id = await _dbHelper.insertCartItem(newItem);

        // Add to local list with database ID
        _items.add(
          CartItem(
            id: id,
            medicineId: newItem.medicineId,
            medicineName: newItem.medicineName,
            medicineImage: newItem.medicineImage,
            price: newItem.price,
            quantity: newItem.quantity,
          ),
        );
      }

      // Update SharedPreferences
      await _saveCartToPreferences();

      notifyListeners();
    } catch (e) {
      _error = 'Failed to add to cart: $e';
    } finally {
      _setLoading(false);
    }
  }

  // Update item quantity
  Future<void> updateQuantity(int itemId, int quantity) async {
    if (quantity <= 0) {
      await removeItem(itemId);
      return;
    }

    _setLoading(true);
    try {
      // Find the item
      final index = _items.indexWhere((item) => item.id == itemId);
      if (index == -1) {
        _error = 'Item not found';
        return;
      }

      // Update quantity
      _items[index].quantity = quantity;

      // Update in database
      await _dbHelper.updateCartItem(_items[index]);

      // Update SharedPreferences
      await _saveCartToPreferences();

      notifyListeners();
    } catch (e) {
      _error = 'Failed to update quantity: $e';
    } finally {
      _setLoading(false);
    }
  }

  // Remove item
  Future<void> removeItem(int itemId) async {
    _setLoading(true);
    try {
      // Remove from database
      await _dbHelper.deleteCartItem(itemId);

      // Remove from local list
      _items.removeWhere((item) => item.id == itemId);

      // Update SharedPreferences
      await _saveCartToPreferences();

      notifyListeners();
    } catch (e) {
      _error = 'Failed to remove item: $e';
    } finally {
      _setLoading(false);
    }
  }

  // Clear cart
  Future<void> clearCart() async {
    _setLoading(true);
    try {
      // Clear database
      await _dbHelper.clearCart();

      // Clear local list
      _items.clear();

      // Clear SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(ApiConstants.cartKey);

      notifyListeners();
    } catch (e) {
      _error = 'Failed to clear cart: $e';
    } finally {
      _setLoading(false);
    }
  }

  // Sync cart items to database
  Future<void> _syncCartToDatabase() async {
    try {
      // Clear existing cart items in database
      await _dbHelper.clearCart();

      // Insert all items
      for (var item in _items) {
        await _dbHelper.insertCartItem(item);
      }
    } catch (e) {
      _error = 'Failed to sync cart to database: $e';
    }
  }

  // Save cart to SharedPreferences
  Future<void> _saveCartToPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartData = _items.map((item) => item.toMap()).toList();
      await prefs.setString(ApiConstants.cartKey, json.encode(cartData));
    } catch (e) {
      _error = 'Failed to save cart to preferences: $e';
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
