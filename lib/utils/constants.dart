class ApiConstants {
  // Base URL - ensure this is correct
  static const String baseUrl =
      'https://medcare-be-663618957788.us-central1.run.app';

  // Auth
  static const String login = '$baseUrl/login';
  static const String register = '$baseUrl/register';
  static const String logout = '$baseUrl/logout';
  static const String refreshToken = '$baseUrl/refresh';

  // User
  static const String tokenKey = 'auth_token';
  static const String userKey = 'user_data';
  static const String userProfile = '$baseUrl/users/me';
  static const String updateProfile = '$baseUrl/profile'; // Add this line

  // Medicines
  static const String medicines = '$baseUrl/medicines';
  static const String medicineById = '$baseUrl/medicines/';
  static const String categories = '$baseUrl/medicines/categories';

  // Orders
  static const String orders = '$baseUrl/orders';
  static const String orderById = '$baseUrl/orders/';
  static const String userOrders = '$baseUrl/user/orders';

  // Cart
  static const String cartKey = 'cart_data';
}

// Default medicine image for fallback
const String defaultMedicineImage =
    'https://images.unsplash.com/photo-1584308666744-24d5c474f2ae?ixlib=rb-1.2.1&auto=format&fit=crop&w=800&q=60';

// Default profile image for fallback
const String defaultProfileImage =
    'https://upload.wikimedia.org/wikipedia/commons/8/89/Portrait_Placeholder.png';
