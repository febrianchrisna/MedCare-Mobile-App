import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:medcareapp/models/user.dart';
import 'package:medcareapp/services/api_service.dart';
import 'package:medcareapp/utils/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();

  User? _user;
  bool _isAuthenticated = false;
  bool _isLoading = false;
  String? _error;

  // Getters
  User? get user => _user;
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Constructor - load user data on initialization
  AuthProvider() {
    loadUserData();
  }

  // Load user from SharedPreferences
  Future<void> loadUserData() async {
    _isLoading = true;
    notifyListeners();
    try {
      print("AuthProvider: Loading user data from SharedPreferences");
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString(ApiConstants.userKey);
      final token = prefs.getString(ApiConstants.tokenKey);

      if (userJson != null) {
        print("AuthProvider: Found user data in SharedPreferences");
        final userMap = json.decode(userJson);
        _user = User.fromJson(userMap);
        _isAuthenticated =
            token != null; // Only authenticated if we have a token
        print(
          "AuthProvider: User loaded: ${_user?.username}, isAuthenticated: $_isAuthenticated",
        );
      } else if (token != null) {
        // We have a token but no user data, try to fetch user profile
        print("AuthProvider: Found token but no user data, fetching profile");
        final userMap = await _apiService.fetchUserProfile();
        if (userMap != null) {
          _user = User.fromJson(userMap);
          _isAuthenticated = true;
          print("AuthProvider: User fetched from profile: ${_user?.username}");
        }
      }
    } catch (e) {
      print("AuthProvider: Error loading user data: $e");
      _error = 'Failed to load user data';
    }
    _isLoading = false;
    notifyListeners();
  }

  // Login method
  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      print("AuthProvider: Attempting login for $email");

      final response = await _apiService.login(email, password);
      print("AuthProvider: Login response received: $response");

      // Check if login was successful
      if (response['success'] == true || response['token'] != null) {
        // If user data is in the response, use it
        if (response['user'] != null && (response['user'] as Map).isNotEmpty) {
          _user = User.fromJson(response['user']);
          _isAuthenticated = true;
          print(
            "AuthProvider: User set from login response: ${_user?.username}",
          );
        }
        // Otherwise fetch user profile
        else {
          print(
            "AuthProvider: No user data in login response, fetching profile",
          );
          final userMap = await _apiService.fetchUserProfile();
          if (userMap != null) {
            _user = User.fromJson(userMap);
            _isAuthenticated = true;
            print(
              "AuthProvider: User fetched from profile: ${_user?.username}",
            );
          } else {
            // Even without user data, we're still authenticated if we have a token
            _isAuthenticated = true;
            print("AuthProvider: Authenticated with token only, no user data");
          }
        }
      } else {
        _error = 'Invalid login response';
        _isAuthenticated = false;
        print("AuthProvider: Invalid login response");
      }

      _isLoading = false;
      notifyListeners();
      return _isAuthenticated;
    } catch (e) {
      _error = e.toString();
      _isAuthenticated = false;
      _isLoading = false;
      print("AuthProvider: Login error: $_error");
      notifyListeners();
      return false;
    }
  }

  // Logout method
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    try {
      print("AuthProvider: Logging out");
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(ApiConstants.tokenKey);
      await prefs.remove(ApiConstants.userKey);

      _user = null;
      _isAuthenticated = false;
      print("AuthProvider: Logged out successfully");
    } catch (e) {
      _error = 'Failed to logout';
      print("AuthProvider: Logout error: $_error");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Register method
  Future<bool> register(String username, String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      print("AuthProvider: Attempting registration for $email");
      final response = await _apiService.register(username, email, password);

      if (response['token'] != null) {
        // Save token
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(ApiConstants.tokenKey, response['token']);

        // Save user if available
        if (response['user'] != null) {
          await prefs.setString(
            ApiConstants.userKey,
            jsonEncode(response['user']),
          );
          _user = User.fromJson(response['user']);
        } else {
          // Try to fetch user profile
          final userMap = await _apiService.fetchUserProfile();
          if (userMap != null) {
            _user = User.fromJson(userMap);
          }
        }

        _isAuthenticated = true;
        print("AuthProvider: Registration successful");

        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = 'Invalid registration response';
        print("AuthProvider: Invalid registration response");
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = e.toString();
      print("AuthProvider: Registration error: $_error");
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
