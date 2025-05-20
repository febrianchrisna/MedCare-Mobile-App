import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:medcareapp/utils/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NetworkHelper {
  // Get auth token from shared preferences
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(ApiConstants.tokenKey);
  }

  // Create headers with auth token if available
  static Future<Map<String, String>> getHeaders({
    bool includeToken = true,
  }) async {
    Map<String, String> headers = {'Content-Type': 'application/json'};

    if (includeToken) {
      final token = await getToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    return headers;
  }

  // HTTP GET request
  static Future<dynamic> get(String url, {bool includeToken = true}) async {
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: await getHeaders(includeToken: includeToken),
      );

      return _processResponse(response);
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // HTTP POST request
  static Future<dynamic> post(
    String url,
    Map<String, dynamic> body, {
    bool includeToken = true,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: await getHeaders(includeToken: includeToken),
        body: json.encode(body),
      );

      return _processResponse(response);
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // HTTP PUT request
  static Future<dynamic> put(
    String url,
    Map<String, dynamic> body, {
    bool includeToken = true,
  }) async {
    try {
      final response = await http.put(
        Uri.parse(url),
        headers: await getHeaders(includeToken: includeToken),
        body: json.encode(body),
      );

      return _processResponse(response);
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // HTTP DELETE request
  static Future<dynamic> delete(String url, {bool includeToken = true}) async {
    try {
      final response = await http.delete(
        Uri.parse(url),
        headers: await getHeaders(includeToken: includeToken),
      );

      return _processResponse(response);
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Process HTTP response
  static dynamic _processResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      return json.decode(response.body);
    } else {
      try {
        final errorData = json.decode(response.body);
        throw Exception(
          errorData['message'] ??
              'Request failed with status: ${response.statusCode}',
        );
      } catch (e) {
        throw Exception('Request failed with status: ${response.statusCode}');
      }
    }
  }
}
