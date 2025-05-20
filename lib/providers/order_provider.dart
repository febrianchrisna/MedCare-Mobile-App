import 'package:flutter/material.dart';
import 'package:medcareapp/models/order.dart';
import 'package:medcareapp/services/api_service.dart';
import 'package:medcareapp/services/database_helper.dart';
import 'package:medcareapp/utils/local_order_updates_manager.dart';
import 'package:medcareapp/utils/shared_prefs_helper.dart';

enum OrderState { initial, loading, loaded, error }

class OrderProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  final DatabaseHelper _dbHelper = DatabaseHelper();

  List<Order> _orders = [];
  Order? _currentOrder;
  OrderState _state = OrderState.initial;
  String? _error;
  String? _userId;

  // Getters
  List<Order> get orders => _orders;
  Order? get currentOrder => _currentOrder;
  OrderState get state => _state;
  bool get isLoading => _state == OrderState.loading;
  String? get error => _error;

  // Set current user ID
  void setUserId(String id) {
    _userId = id;
  }

  // Get all user orders - combining local storage and API
  Future<void> fetchUserOrders({bool forceRefresh = false}) async {
    // Always get user from SharedPrefs (or AuthProvider if passed)
    final user = await SharedPrefsHelper.getUser();
    final userId = user?.id != null ? user!.id.toString() : _userId;

    // Add debugging for user ID
    print('DEBUG: Fetching orders with userId: $userId');
    print('DEBUG: User object: ${user?.toJson()}');
    print('DEBUG: Force refresh: $forceRefresh');

    if (userId == null) {
      _error = 'User not authenticated';
      _state = OrderState.error;
      notifyListeners();
      return;
    }
    _userId = userId;

    _state = OrderState.loading;
    notifyListeners();

    try {
      // STEP 1: If we're not forcing a refresh, check SharedPreferences cache
      if (!forceRefresh) {
        final cachedOrders = await SharedPrefsHelper.getCachedOrders();
        if (cachedOrders.isNotEmpty) {
          // Show cached data immediately to improve perceived performance
          _orders = cachedOrders;
          _state = OrderState.loaded;
          notifyListeners();
        }

        // STEP 2: Then check SQLite database for more complete data if not forcing refresh
        final dbOrders = await _dbHelper.getOrdersByUserId(_userId!);
        if (dbOrders.isNotEmpty) {
          _orders = dbOrders;
          _state = OrderState.loaded;
          notifyListeners();

          // Only proceed to API if we need to sync and not forcing refresh
          final shouldSync = await SharedPrefsHelper.shouldSyncWithServer();
          if (!shouldSync && !forceRefresh) return;
        }
      } else {
        // If forcing refresh, clear cached data
        print('Force refreshing orders - clearing cached data');
        await SharedPrefsHelper.clearCachedOrders();
      }

      // STEP 3: Finally, try to get fresh data from API
      try {
        final apiOrders = await _apiService.getUserOrders();
        print('Fetched ${apiOrders.length} orders from API');

        // Always store in SQLite on refresh
        await _dbHelper.clearOrdersForUser(_userId!);
        for (var order in apiOrders) {
          print('Saving order ${order.id} to database');
          await _dbHelper.insertOrder(order);
        }

        // Cache in SharedPreferences for faster loading next time
        await SharedPrefsHelper.cacheOrders(apiOrders);

        // Update state with the most recent data
        _orders = apiOrders;
        _state = OrderState.loaded;
        _error = null;
      } catch (e) {
        print('Error fetching orders from API: $e');
        // If we have local data, keep showing it
        if (_orders.isNotEmpty) {
          _error = 'Could not refresh data: $e';
          // Status still "loaded" since we're showing data
          _state = OrderState.loaded;
        } else {
          _error = 'Failed to fetch orders: $e';
          _state = OrderState.error;
        }
      }
    } catch (e) {
      print('General error in fetchUserOrders: $e');
      _error = 'Error: $e';
      _state = OrderState.error;
    }

    // Apply local updates to all orders before completing
    try {
      List<Order> updatedOrders = [];
      for (var order in _orders) {
        final updatedOrder = await LocalOrderUpdatesManager.applyLocalUpdates(
          order,
        );
        updatedOrders.add(updatedOrder);
      }
      _orders = updatedOrders;
      print('DEBUG: Applied local updates to all orders in fetchUserOrders');
    } catch (e) {
      print('Error applying local updates to orders: $e');
    }

    notifyListeners();
  }

  // Create new order
  Future<bool> createOrder(Order order) async {
    _state = OrderState.loading;
    notifyListeners();

    // Debug order creation
    print('DEBUG: Creating order with user ID: ${order.userId}');
    print('DEBUG: Order items count: ${order.items.length}');
    print('DEBUG: Order total: ${order.totalAmount}');

    try {
      // Try to create via API first
      try {
        final createdOrder = await _apiService.createOrder(order);
        print('Order created successfully with ID: ${createdOrder.id}');

        // Save to local DB
        await _dbHelper.insertOrder(createdOrder);
        print('Order saved to local database');

        // Clear cached orders to force fresh fetch next time
        await SharedPrefsHelper.clearCachedOrders();

        // Add to memory list
        _orders.add(createdOrder);

        // Cache updated list
        await SharedPrefsHelper.cacheOrders(_orders);

        _state = OrderState.loaded;
        _error = null;
        notifyListeners();
        return true;
      } catch (e) {
        print('DEBUG: API order creation failed: $e');

        // If API fails, save as offline order
        // Give it a temporary negative ID
        final tempOrder = Order(
          id: -DateTime.now().millisecondsSinceEpoch,
          userId: order.userId,
          items: order.items,
          totalAmount: order.totalAmount,
          status: 'Pending (Offline)',
          address: order.address,
          paymentMethod: order.paymentMethod,
          notes: order.notes,
          createdAt: DateTime.now(),
        );

        // Save to SQLite
        await _dbHelper.insertOrder(tempOrder);
        print('Offline order saved to local database');

        // Also save to SharedPreferences for sync later
        await SharedPrefsHelper.saveOfflineOrder(tempOrder);

        // Add to memory list
        _orders.add(tempOrder);

        // Clear cached orders to force fresh fetch next time
        await SharedPrefsHelper.clearCachedOrders();

        _state = OrderState.loaded;
        _error = 'Order saved offline. Will sync when connection is restored.';
        notifyListeners();
        return true;
      }
    } catch (e) {
      print('Error in createOrder: $e');
      _error = 'Failed to create order: $e';
      _state = OrderState.error;
      notifyListeners();
      return false;
    }
  }

  // Cancel order (delete)
  Future<bool> cancelOrder(int orderId) async {
    _state = OrderState.loading;
    notifyListeners();

    try {
      // Try API first
      try {
        await _apiService.deleteOrder(orderId);
      } catch (e) {
        // If API fails but order exists locally, just mark it
        if (orderId > 0) {
          await _dbHelper.updateOrderStatus(orderId, 'Cancelled (Offline)');

          // Update memory list
          final index = _orders.indexWhere((o) => o.id == orderId);
          if (index >= 0) {
            final oldOrder = _orders[index];
            _orders[index] = Order(
              id: oldOrder.id,
              userId: oldOrder.userId,
              items: oldOrder.items,
              totalAmount: oldOrder.totalAmount,
              status: 'Cancelled (Offline)',
              address: oldOrder.address,
              paymentMethod: oldOrder.paymentMethod,
              notes: oldOrder.notes,
              createdAt: oldOrder.createdAt,
              updatedAt: oldOrder.updatedAt != null ? DateTime.now() : null,
            );
          }

          // Update cache
          await SharedPrefsHelper.cacheOrders(_orders);

          _state = OrderState.loaded;
          return true;
        }
      }

      // Delete from SQLite
      await _dbHelper.deleteOrder(orderId);

      // Update memory list
      _orders.removeWhere((order) => order.id == orderId);

      // Update cache
      await SharedPrefsHelper.cacheOrders(_orders);

      _state = OrderState.loaded;
      return true;
    } catch (e) {
      _error = 'Failed to cancel order: $e';
      _state = OrderState.error;
      return false;
    } finally {
      notifyListeners();
    }
  }

  // Update order
  Future<bool> updateOrder(int orderId, Map<String, dynamic> updates) async {
    _state = OrderState.loading;
    notifyListeners();

    try {
      // Get the current order
      Order? order = await _dbHelper.getOrderById(orderId);
      if (order == null) {
        throw Exception('Order not found');
      }

      String updatedStatus = updates['status'] ?? order.status;

      // Try API first
      try {
        await _apiService.updateOrder(orderId, updates);
      } catch (e) {
        // Mark as offline update
        updatedStatus = updatedStatus + ' (Offline Update)';
      }

      // Create updated order with modified status
      final updatedOrder = Order(
        id: order.id,
        userId: order.userId,
        items: order.items,
        totalAmount: order.totalAmount,
        status: updatedStatus,
        address: updates['address'] ?? order.address,
        paymentMethod: updates['paymentMethod'] ?? order.paymentMethod,
        notes: updates['notes'] ?? order.notes,
        createdAt: order.createdAt,
        updatedAt: DateTime.now(),
      );

      // Update in SQLite
      await _dbHelper.updateOrder(updatedOrder);

      // Update memory list
      final index = _orders.indexWhere((o) => o.id == orderId);
      if (index >= 0) {
        _orders[index] = updatedOrder;
      }

      // Update cache
      await SharedPrefsHelper.cacheOrders(_orders);

      _state = OrderState.loaded;
      return true;
    } catch (e) {
      _error = 'Failed to update order: $e';
      _state = OrderState.error;
      return false;
    } finally {
      notifyListeners();
    }
  }

  // Update user order (for pending orders only)
  Future<bool> updateUserOrder(
    int orderId,
    Map<String, dynamic> updates,
  ) async {
    _state = OrderState.loading;
    notifyListeners();

    try {
      try {
        // Save to local update manager before API call
        await LocalOrderUpdatesManager.saveOrderUpdate(orderId, updates);
        print('DEBUG: Saved local update in provider: ${orderId}, ${updates}');

        // Continue with API update (even if it doesn't work)
        final apiOrder = await _apiService.updateUserOrder(orderId, updates);

        // Find the order in our list to update it
        final index = _orders.indexWhere((o) => o.id == orderId);
        if (index >= 0) {
          // Apply our update directly to the in-memory order list
          final originalOrder = _orders[index];
          final updatedOrder = Order(
            id: originalOrder.id,
            userId: originalOrder.userId,
            items: originalOrder.items,
            totalAmount: originalOrder.totalAmount,
            status: originalOrder.status,
            address: updates['address'] ?? originalOrder.address,
            paymentMethod:
                updates['paymentMethod'] ?? originalOrder.paymentMethod,
            notes: updates['notes'] ?? originalOrder.notes,
            createdAt: originalOrder.createdAt,
            updatedAt: DateTime.now(),
          );

          // Update in memory
          _orders[index] = updatedOrder;
          print('DEBUG: Updated order in memory list at index ${index}');
          print(
            'DEBUG: addr=${updatedOrder.address}, payment=${updatedOrder.paymentMethod}',
          );
        }

        // Update cache
        await SharedPrefsHelper.cacheOrders(_orders);

        _state = OrderState.loaded;
        _error = null;
        notifyListeners();
        return true;
      } catch (e) {
        print('DEBUG: API update failed: $e');
        _error = 'Failed to update order on server: $e';
        _state = OrderState.error;
        notifyListeners();
        return false;
      }
    } catch (e) {
      print('Error in updateUserOrder: $e');
      _error = 'Error updating order: $e';
      _state = OrderState.error;
      notifyListeners();
      return false;
    }
  }

  // Get order by ID
  Future<Order> getOrderById(int orderId, {bool forceRefresh = false}) async {
    try {
      // Get base order using existing code
      Order order;

      // Try memory cache first if not forcing refresh
      if (!forceRefresh) {
        if (_currentOrder != null && _currentOrder!.id == orderId) {
          order = _currentOrder!;
        } else {
          final cachedOrder = _orders.firstWhere(
            (o) => o.id == orderId,
            orElse:
                () => Order(
                  id: -1,
                  userId: '',
                  items: [],
                  totalAmount: 0,
                  status: '',
                  createdAt: DateTime.now(),
                ),
          );

          if (cachedOrder.id != -1) {
            order = cachedOrder;
          } else {
            // If not in memory, try database
            final dbOrder = await _dbHelper.getOrderById(orderId);
            if (dbOrder != null) {
              order = dbOrder;
            } else {
              // Finally try API
              order = await _apiService.getOrderById(orderId);
            }
          }
        }
      } else {
        // If forcing refresh, go directly to API
        order = await _apiService.getOrderById(orderId);
      }

      // Apply local updates before returning
      final updatedOrder = await LocalOrderUpdatesManager.applyLocalUpdates(
        order,
      );
      print('DEBUG: getOrderById applied local updates: ${orderId}');
      print(
        'DEBUG: before: addr=${order.address}, payment=${order.paymentMethod}',
      );
      print(
        'DEBUG: after: addr=${updatedOrder.address}, payment=${updatedOrder.paymentMethod}',
      );
      return updatedOrder;
    } catch (e) {
      print('Error in getOrderById: $e');
      throw Exception('Failed to get order: $e');
    }
  }

  // Sync offline orders with server
  Future<void> syncOfflineOrders() async {
    // Get offline orders from SharedPreferences
    final offlineOrders = await SharedPrefsHelper.getOfflineOrders();

    if (offlineOrders.isEmpty) return;

    // Try to sync each order
    for (var order in offlineOrders) {
      try {
        if (order.id! < 0) {
          // This is a new order created offline
          final cleanedStatus = order.status.replaceAll(' (Offline)', '');

          final newOrder = Order(
            userId: order.userId,
            items: order.items,
            totalAmount: order.totalAmount,
            status: cleanedStatus,
            address: order.address,
            paymentMethod: order.paymentMethod,
            notes: order.notes,
            createdAt: order.createdAt,
          ); // Create via API
          final createdOrder = await _apiService.createOrder(newOrder);

          // Remove local version and add server version
          await _dbHelper.deleteOrder(order.id!);
          await _dbHelper.insertOrder(createdOrder);
        } else if (order.status.contains('Cancelled')) {
          // This is an order that was cancelled offline
          await _apiService.deleteOrder(order.id!);
          await _dbHelper.deleteOrder(order.id!);
        }
      } catch (e) {
        // Keep trying other orders
        print('Failed to sync order ${order.id}: $e');
        continue;
      }
    }
    // Clear synced offline orders
    await SharedPrefsHelper.clearOfflineOrders();
    // Refresh orders list
    await fetchUserOrders();
  }

  // Clear all data (for logout)
  Future<void> clearAllData() async {
    _userId = null;
    _orders = [];
    _currentOrder = null;
    _state = OrderState.initial;
    _error = null;
    if (_userId != null) {
      await _dbHelper.deleteAllUserOrders(_userId!);
    }
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Method to clear cached data for a specific order
  Future<void> clearOrderCache(int orderId) async {
    print('Clearing cache for order $orderId');

    try {
      // Remove from in-memory list
      final index = _orders.indexWhere((o) => o.id == orderId);
      if (index >= 0) {
        _orders.removeAt(index);
      }

      // Clear the current order if it matches
      if (_currentOrder != null && _currentOrder!.id == orderId) {
        _currentOrder = null;
      }

      // Remove from database
      await _dbHelper.deleteOrder(orderId);

      // Update SharedPreferences cache
      await SharedPrefsHelper.cacheOrders(_orders);

      print('Cache cleared for order $orderId');
    } catch (e) {
      print('Error clearing order cache: $e');
    }
  }
}
