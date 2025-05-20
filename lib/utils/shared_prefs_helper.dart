import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:medcareapp/models/order.dart';
import 'package:medcareapp/models/user.dart';
import 'package:medcareapp/utils/constants.dart';

class SharedPrefsHelper {
  // User related methods
  static Future<User?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString(ApiConstants.userKey);
    if (userJson != null) {
      try {
        return User.fromJson(json.decode(userJson));
      } catch (e) {
        print('Error parsing user data: $e');
        return null;
      }
    }
    return null;
  }

  // Order related methods
  static Future<List<Order>> getCachedOrders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ordersJson = prefs.getString('cached_orders');
      if (ordersJson != null) {
        final List<dynamic> orderData = json.decode(ordersJson);
        return orderData.map((data) => Order.fromJson(data)).toList();
      }
    } catch (e) {
      print('Error getting cached orders: $e');
    }
    return [];
  }

  static Future<void> cacheOrders(List<Order> orders) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ordersData = orders.map((order) => order.toJson()).toList();
      await prefs.setString('cached_orders', json.encode(ordersData));
      print('Cached ${orders.length} orders in SharedPreferences');

      // Update last sync time
      await prefs.setInt(
        'last_orders_sync',
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (e) {
      print('Error caching orders: $e');
    }
  }

  static Future<void> clearCachedOrders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('cached_orders');
      print('Cleared cached orders from SharedPreferences');
    } catch (e) {
      print('Error clearing cached orders: $e');
    }
  }

  static Future<bool> shouldSyncWithServer() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSync = prefs.getInt('last_orders_sync') ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;

      // Sync if it's been more than 5 minutes since last sync
      return (now - lastSync) > 5 * 60 * 1000;
    } catch (e) {
      return true;
    }
  }

  static Future<void> saveOfflineOrder(Order order) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<dynamic> offlineOrders = [];

      final offlineOrdersJson = prefs.getString('offline_orders');
      if (offlineOrdersJson != null) {
        offlineOrders = json.decode(offlineOrdersJson);
      }

      offlineOrders.add(order.toJson());
      await prefs.setString('offline_orders', json.encode(offlineOrders));
      print('Saved offline order to SharedPreferences');
    } catch (e) {
      print('Error saving offline order: $e');
    }
  }

  static Future<List<Order>> getOfflineOrders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final offlineOrdersJson = prefs.getString('offline_orders');
      if (offlineOrdersJson != null) {
        final List<dynamic> orderData = json.decode(offlineOrdersJson);
        return orderData.map((data) => Order.fromJson(data)).toList();
      }
    } catch (e) {
      print('Error getting offline orders: $e');
    }
    return [];
  }

  static Future<void> clearOfflineOrders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('offline_orders');
    } catch (e) {
      print('Error clearing offline orders: $e');
    }
  }

  // Clear all app data from SharedPreferences
  static Future<void> clearAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Clear specific keys
      await prefs.remove(ApiConstants.tokenKey);
      await prefs.remove(ApiConstants.userKey);
      await prefs.remove(ApiConstants.cartKey);
      await prefs.remove('cached_orders');
      await prefs.remove('offline_orders');
      await prefs.remove('last_orders_sync');

      // Alternatively, clear all keys (uncommenting may clear data from other apps)
      // await prefs.clear();

      print('Successfully cleared all app data from SharedPreferences');
    } catch (e) {
      print('Error clearing all SharedPreferences data: $e');
    }
  }

  // Get all data stored in SharedPreferences for debugging
  static Future<Map<String, dynamic>> getAllStoredData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      Map<String, dynamic> allData = {};

      for (String key in keys) {
        if (prefs.getString(key) != null) {
          // Try to parse JSON data
          try {
            final value = prefs.getString(key);
            final jsonData = json.decode(value!);
            allData[key] = jsonData;
          } catch (e) {
            // If not JSON, store as is
            allData[key] = prefs.getString(key);
          }
        } else if (prefs.getBool(key) != null) {
          allData[key] = prefs.getBool(key);
        } else if (prefs.getInt(key) != null) {
          allData[key] = prefs.getInt(key);
        } else if (prefs.getDouble(key) != null) {
          allData[key] = prefs.getDouble(key);
        } else if (prefs.getStringList(key) != null) {
          allData[key] = prefs.getStringList(key);
        }
      }

      return allData;
    } catch (e) {
      print('Error getting all stored data: $e');
      return {'error': e.toString()};
    }
  }
}
