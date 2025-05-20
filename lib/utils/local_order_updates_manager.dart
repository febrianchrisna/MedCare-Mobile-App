import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:medcareapp/models/order.dart';

/// Manages local updates to orders when server doesn't update correctly
class LocalOrderUpdatesManager {
  static const String _storageKey = 'local_order_updates';

  // Save a local update for an order
  static Future<void> saveOrderUpdate(
    int orderId,
    Map<String, dynamic> updates,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Get existing updates
      Map<String, dynamic> allUpdates = {};
      final storedUpdates = prefs.getString(_storageKey);
      if (storedUpdates != null) {
        allUpdates = json.decode(storedUpdates);
      }

      // Update or add the order's updates
      allUpdates[orderId.toString()] = updates;

      // Save back to storage
      await prefs.setString(_storageKey, json.encode(allUpdates));

      print('LOCAL UPDATE: Saved for order $orderId: $updates');
    } catch (e) {
      print('Error saving local order update: $e');
    }
  }

  // Get local updates for a specific order
  static Future<Map<String, dynamic>?> getOrderUpdates(int orderId) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final storedUpdates = prefs.getString(_storageKey);
      if (storedUpdates != null) {
        final allUpdates = json.decode(storedUpdates) as Map<String, dynamic>;
        if (allUpdates.containsKey(orderId.toString())) {
          print(
            'LOCAL UPDATE: Found for order $orderId: ${allUpdates[orderId.toString()]}',
          );
          return allUpdates[orderId.toString()];
        }
      }
      return null;
    } catch (e) {
      print('Error getting local order update: $e');
      return null;
    }
  }

  // Apply local updates to an order object
  static Future<Order> applyLocalUpdates(Order order) async {
    if (order.id == null) return order;

    try {
      final updates = await getOrderUpdates(order.id!);
      if (updates == null) return order;

      // Create a new order with applied updates
      final updatedOrder = Order(
        id: order.id,
        userId: order.userId,
        items: order.items,
        totalAmount: order.totalAmount,
        status: updates['status'] ?? order.status,
        address: updates['address'] ?? order.address,
        paymentMethod: updates['paymentMethod'] ?? order.paymentMethod,
        notes: updates['notes'] ?? order.notes,
        createdAt: order.createdAt,
        updatedAt: DateTime.now(),
      );

      print(
        'LOCAL UPDATE: Applied to order ${order.id}: old address="${order.address}", ' +
            'new address="${updatedOrder.address}", old payment="${order.paymentMethod}", ' +
            'new payment="${updatedOrder.paymentMethod}"',
      );

      return updatedOrder;
    } catch (e) {
      print('Error applying local updates: $e');
      return order;
    }
  }

  // Clear all local updates
  static Future<void> clearAllUpdates() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
      print('LOCAL UPDATE: Cleared all local updates');
    } catch (e) {
      print('Error clearing local updates: $e');
    }
  }

  // Debug method to print all stored updates
  static Future<void> debugPrintAllUpdates() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedUpdates = prefs.getString(_storageKey);
      if (storedUpdates != null) {
        print('LOCAL UPDATE: All stored updates: $storedUpdates');
      } else {
        print('LOCAL UPDATE: No updates stored');
      }
    } catch (e) {
      print('Error printing stored updates: $e');
    }
  }
}
