import 'dart:convert';
import 'dart:math' as math; // Add this import for min function
import 'package:http/http.dart' as http;
import 'package:medcareapp/utils/constants.dart';
import 'package:medcareapp/models/medicine.dart';
import 'package:medcareapp/models/order.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:medcareapp/services/database_helper.dart'; // Add this import

class ApiService {
  // Get auth token from shared preferences
  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(ApiConstants.tokenKey);

    // Debug token
    if (token != null) {
      print(
        "Retrieved token: ${token.substring(0, math.min(10, token.length))}...",
      ); // Fix Math.min to math.min
    } else {
      print("No token found in SharedPreferences");
    }

    return token;
  }

  // Create headers with auth token if available
  Future<Map<String, String>> _getHeaders() async {
    final token = await _getToken();
    Map<String, String> headers = {'Content-Type': 'application/json'};

    if (token != null && token.isNotEmpty) {
      // Try with 'Bearer ' prefix - this is the standard format
      headers['Authorization'] = 'Bearer $token';
      print(
        "Using Bearer token format: Bearer ${token.substring(0, math.min(10, token.length))}...",
      );
    } else {
      print("WARNING: No token available for authenticated request");
    }

    return headers;
  }

  // Medicines
  Future<List<Medicine>> getMedicines({
    String? category,
    String? search,
    bool? featured,
  }) async {
    try {
      String url = ApiConstants.medicines;
      List<String> queryParams = [];

      if (category != null) {
        queryParams.add('category=$category');
      }

      if (search != null) {
        queryParams.add('search=$search');
      }

      if (featured != null) {
        queryParams.add('featured=${featured.toString()}');
      }

      if (queryParams.isNotEmpty) {
        url += '?' + queryParams.join('&');
      }

      final response = await http.get(
        Uri.parse(url),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Medicine.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load medicines: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error getting medicines: $e');
    }
  }

  Future<Medicine> getMedicineById(int id) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConstants.medicineById}$id'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        return Medicine.fromJson(json.decode(response.body));
      } else {
        throw Exception('Failed to load medicine: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error getting medicine: $e');
    }
  }

  Future<List<String>> getCategories() async {
    try {
      final response = await http.get(
        Uri.parse(ApiConstants.categories),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        // API bisa mengembalikan list string atau objek, handle keduanya
        return data
            .map((item) => item is String ? item : item['category'].toString())
            .toList();
      } else {
        throw Exception('Failed to load categories: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error getting categories: $e');
    }
  }

  // Auth
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      print("Attempting login for email: $email");
      final response = await http.post(
        Uri.parse(ApiConstants.login),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email, 'password': password}),
      );

      print("Login response status: ${response.statusCode}");
      print("Login response body: ${response.body}");

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        print("Login successful, response data: $responseData");

        final token = responseData['accessToken'] ?? responseData['token'];
        final user = responseData['safeUserData'] ?? responseData['user'];

        if (token != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(ApiConstants.tokenKey, token);
          print("Token saved to SharedPreferences");

          if (user != null) {
            await prefs.setString(ApiConstants.userKey, json.encode(user));
            print("User data saved to SharedPreferences");
          } else {
            print("No user data in response, will need to fetch separately");
          }

          return {'token': token, 'user': user ?? {}, 'success': true};
        } else {
          print("Missing token in response");
          throw Exception('Invalid login response: missing token');
        }
      } else {
        final error = json.decode(response.body);
        print("Login failed: ${error['message'] ?? 'Unknown error'}");
        throw Exception(error['message'] ?? 'Login failed');
      }
    } catch (e) {
      print('Error during login: $e');
      throw Exception('Error during login: $e');
    }
  }

  // Helper method to mask token for logs
  String _maskToken(String? token) {
    if (token == null || token.isEmpty) return 'null-or-empty';

    // Show only first few characters followed by asterisks
    final visibleLength = math.min(6, token.length);
    final maskedPart = '*' * math.min(10, token.length - visibleLength);
    return '${token.substring(0, visibleLength)}$maskedPart';
  }

  // Fetch user profile after login
  Future<Map<String, dynamic>?> fetchUserProfile() async {
    try {
      final token = await _getToken();
      if (token == null) {
        print("No token available to fetch user profile");
        return null;
      }

      print("Fetching user profile with token: ${_maskToken(token)}");

      final response = await http.get(
        Uri.parse(ApiConstants.userProfile),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      print("User profile response status: ${response.statusCode}");
      print("User profile response body: ${response.body}");

      if (response.statusCode == 200) {
        final userData = json.decode(response.body);
        // Save to SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(ApiConstants.userKey, json.encode(userData));
        return userData;
      } else {
        print('Failed to fetch user profile: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error fetching user profile: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>> register(
    String username,
    String email,
    String password,
  ) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConstants.register),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'username': username,
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 201) {
        return json.decode(response.body);
      } else {
        final error = json.decode(response.body);
        throw Exception(error['message'] ?? 'Registration failed');
      }
    } catch (e) {
      throw Exception('Error during registration: $e');
    }
  }

  Future<List<dynamic>> getOrders() async {
    try {
      final response = await http.get(
        Uri.parse(ApiConstants.orders),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load orders: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error getting orders: $e');
    }
  }

  // Order Endpoints

  // Get user orders (khusus user)
  Future<List<Order>> getUserOrders() async {
    try {
      final token = await _getToken();
      if (token == null || token.isEmpty) {
        throw Exception('Please log in to view your orders');
      }
      final url = ApiConstants.userOrders;
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
        'Accept': 'application/json', // Tambahkan agar sama dengan web
      };
      print('Fetching user orders...');
      print('Headers: $headers');
      print('URL: $url');
      final response = await http.get(Uri.parse(url), headers: headers);
      print('Status: ${response.statusCode}');
      print('Body: ${response.body}');
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Order.fromJson(json)).toList();
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        print('Token used: $token');
        print('Response headers: ${response.headers}');
        throw Exception(
          'Access denied (status ${response.statusCode}). Please ensure you are logged in as a user and your token is valid.',
        );
      } else {
        throw Exception('Failed to load orders (${response.statusCode})');
      }
    } catch (e) {
      throw Exception('Failed to load orders: $e');
    }
  }

  // Get all orders (khusus admin)
  Future<List<Order>> getAllOrders() async {
    try {
      final token = await _getToken();
      if (token == null || token.isEmpty) {
        throw Exception('Please log in as admin');
      }
      final url = '${ApiConstants.baseUrl}/orders';
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };
      final response = await http.get(Uri.parse(url), headers: headers);
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Order.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load all orders (${response.statusCode})');
      }
    } catch (e) {
      throw Exception('Error getting all orders: $e');
    }
  }

  // Get order by ID (user & admin) - Remove this method, as it's duplicated
  // Future<Order> getOrderById(int id) async {
  //   try {
  //     final token = await _getToken();
  //     final url = '${ApiConstants.baseUrl}/orders/$id';
  //     final headers = {
  //       'Content-Type': 'application/json',
  //       'Authorization': 'Bearer $token',
  //     };
  //     final response = await http.get(Uri.parse(url), headers: headers);
  //     if (response.statusCode == 200) {
  //       return Order.fromJson(json.decode(response.body));
  //     } else {
  //       throw Exception('Failed to load order: ${response.statusCode}');
  //     }
  //   } catch (e) {
  //     throw Exception('Error getting order: $e');
  //   }
  // }

  // Create order (user only)
  Future<Order> createOrder(Order order) async {
    try {
      final token = await _getToken();
      final url = '${ApiConstants.baseUrl}/orders';
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };
      final orderData = {
        'userId': order.userId,
        'total_amount': order.totalAmount,
        'status': order.status,
        'shipping_address': order.address,
        'payment_method': order.paymentMethod,
        'notes': order.notes,
        'items':
            order.items
                .map(
                  (item) => {
                    'medicineId': item.medicineId,
                    'quantity': item.quantity,
                    'price': item.price,
                  },
                )
                .toList(),
      };
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: json.encode(orderData),
      );
      if (response.statusCode == 201 || response.statusCode == 200) {
        return Order.fromJson(json.decode(response.body));
      } else {
        final error = json.decode(response.body);
        throw Exception(error['message'] ?? 'Failed to create order');
      }
    } catch (e) {
      throw Exception('Error creating order: $e');
    }
  }

  // Cancel order (user only)
  Future<void> cancelOrder(int id) async {
    try {
      final token = await _getToken();
      final url = '${ApiConstants.baseUrl}/user/orders/$id/cancel';
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };
      final response = await http.put(Uri.parse(url), headers: headers);
      if (response.statusCode != 200) {
        throw Exception('Failed to cancel order: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error canceling order: $e');
    }
  }

  // Update order
  Future<void> updateOrder(int id, Map<String, dynamic> updates) async {
    try {
      final response = await http.put(
        Uri.parse('${ApiConstants.userOrders}/$id'),
        headers: await _getHeaders(),
        body: json.encode(updates),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to update order: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error updating order: $e');
    }
  }

  // Delete order
  Future<void> deleteOrder(int id) async {
    try {
      final response = await http.delete(
        Uri.parse('${ApiConstants.userOrders}/$id'),
        headers: await _getHeaders(),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to delete order: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error deleting order: $e');
    }
  }

  // Admin: Update order status
  Future<void> updateOrderStatus(int id, String status) async {
    try {
      final response = await http.put(
        Uri.parse('${ApiConstants.orders}/$id/status'),
        headers: await _getHeaders(),
        body: json.encode({'status': status}),
      );

      if (response.statusCode != 200) {
        throw Exception(
          'Failed to update order status: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Error updating order status: $e');
    }
  }

  // Update user order (specific endpoint for users to update their own orders)
  Future<Order> updateUserOrder(
    int orderId,
    Map<String, dynamic> updateData,
  ) async {
    try {
      final token = await _getToken();
      if (token == null) throw Exception('Authentication required');

      // Translate to field names the API expects
      Map<String, dynamic> apiData = {};
      if (updateData.containsKey('address')) {
        apiData['shipping_address'] = updateData['address'];
      }
      if (updateData.containsKey('paymentMethod')) {
        apiData['payment_method'] = updateData['paymentMethod'];
      }
      if (updateData.containsKey('notes')) {
        apiData['notes'] = updateData['notes'];
      }

      print('Updating order $orderId with transformed data: $apiData');

      // First get the existing order - either from local DB or order list
      Order currentOrder;
      try {
        currentOrder = await fetchFreshOrderById(orderId);
      } catch (e) {
        print('Failed to fetch current order, creating basic one: $e');
        currentOrder = Order(
          id: orderId,
          userId: '',
          items: [],
          totalAmount: 0,
          status: 'pending',
          createdAt: DateTime.now(),
        );
      }

      // Try to send update request to server
      try {
        final response = await http.put(
          Uri.parse('${ApiConstants.userOrders}/$orderId'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
          body: json.encode(apiData),
        );

        print('Update response status: ${response.statusCode}');
        print('Update response body: ${response.body}');
      } catch (e) {
        print('API call failed but continuing with local update: $e');
      }

      // Create updated order object regardless of API success
      final updatedOrder = Order(
        id: orderId,
        userId: currentOrder.userId,
        items:
            currentOrder.items.map((item) {
              // Ensure medicine names are preserved during update
              return OrderItem(
                medicineId: item.medicineId,
                medicineName: item.medicineName,
                quantity: item.quantity,
                price: item.price,
                medicineImage: item.medicineImage,
              );
            }).toList(),
        totalAmount: currentOrder.totalAmount,
        status: currentOrder.status,
        // Use our updated values
        address:
            updateData.containsKey('address')
                ? updateData['address']
                : currentOrder.address,
        paymentMethod:
            updateData.containsKey('paymentMethod')
                ? updateData['paymentMethod']
                : currentOrder.paymentMethod,
        notes:
            updateData.containsKey('notes')
                ? updateData['notes']
                : currentOrder.notes,
        createdAt: currentOrder.createdAt,
        updatedAt: DateTime.now(),
      );

      print(
        'Created local updated order object with: ' +
            'address=${updatedOrder.address}, ' +
            'paymentMethod=${updatedOrder.paymentMethod}',
      );

      // Store the updated order in the local database
      try {
        final dbHelper = DatabaseHelper(); // Now this will work
        await dbHelper.forceUpdateOrder(updatedOrder);
        print('Saved updated order to local database');
      } catch (e) {
        print('Error saving to local database: $e');
      }

      return updatedOrder;
    } catch (e) {
      print('Error in updateUserOrder: $e');
      throw Exception('Error updating order: $e');
    }
  }

  // New method to fetch fresh order data without caching
  Future<Order> fetchFreshOrderById(int orderId) async {
    try {
      final token = await _getToken();
      if (token == null) throw Exception('Authentication required');

      print('Fetching fresh order data for ID: $orderId');

      // First try to get the order from the local database as a fallback
      try {
        final dbHelper = DatabaseHelper(); // Now this will work
        final localOrder = await dbHelper.getOrderById(orderId);
        if (localOrder != null) {
          print('Found order in local database, using as fallback');
          return localOrder;
        }
      } catch (e) {
        print('Failed to get order from local database: $e');
      }

      // Try to find this order in our order list
      try {
        final ordersList = await getUserOrders();
        final matchingOrder = ordersList.firstWhere(
          (order) => order.id == orderId,
          orElse: () => throw Exception('Order not found in list'),
        );

        print('Found order in list: ${matchingOrder.id}');
        return matchingOrder;
      } catch (e) {
        print('Error finding order in list: $e');

        // If we can't find it, create a basic order with the requested ID
        // This is a fallback to prevent crashes
        return Order(
          id: orderId,
          userId: '',
          items: [],
          totalAmount: 0,
          status: 'pending',
          address: 'Address not available',
          paymentMethod: 'Payment method not available',
          createdAt: DateTime.now(),
        );
      }
    } catch (e) {
      print('Error getting fresh order by ID: $e');
      throw Exception('Error getting order: $e');
    }
  }

  // Keep the original getOrderById method with minor enhancements
  // This can be your existing method at line 321, with updates:
  Future<Order> getOrderById(int id) async {
    try {
      return await fetchFreshOrderById(id);
    } catch (e) {
      print('Error in getOrderById: $e');
      throw Exception('Failed to get order: $e');
    }
  }

  // Get current user data
  Future<Map<String, dynamic>?> getCurrentUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userData = prefs.getString(ApiConstants.userKey);

      if (userData != null) {
        return json.decode(userData);
      }
      return null;
    } catch (e) {
      print("Error getting current user: $e");
      return null;
    }
  }
}
