import 'package:flutter/material.dart';
import 'package:medcareapp/models/medicine.dart';
import 'package:medcareapp/services/api_service.dart';
import 'package:medcareapp/services/database_helper.dart';

enum ProviderState { initial, loading, loaded, error }

class MedicineProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  final DatabaseHelper _dbHelper = DatabaseHelper();

  List<Medicine> _medicines = [];
  List<Medicine> _featuredMedicines = [];
  List<String> _categories = [];
  ProviderState _state = ProviderState.initial;
  String? _error;

  // Getters
  List<Medicine> get medicines => _medicines;
  List<Medicine> get featuredMedicines => _featuredMedicines;
  List<String> get categories => _categories;
  bool get isLoading => _state == ProviderState.loading;
  bool get isInitialized => _state == ProviderState.loaded;
  ProviderState get state => _state;
  String? get error => _error;

  // Initialize data from API and store in local database
  Future<void> initializeMedicines() async {
    // Don't reinitialize if we're already loading or loaded
    if (_state == ProviderState.loading || _state == ProviderState.loaded)
      return;

    _state = ProviderState.loading;
    // Notify outside of async operation
    notifyListeners();

    try {
      // Get medicines from API
      final apiMedicines = await _apiService.getMedicines();

      // Store in local database
      await _syncMedicinesToLocal(apiMedicines);

      // Set medicines in state
      _medicines = apiMedicines;
      _featuredMedicines = apiMedicines.where((med) => med.featured).toList();

      // Get categories
      await _fetchCategories();

      _error = null;
      _state = ProviderState.loaded;
    } catch (e) {
      _error = 'Failed to initialize medicines: $e';
      // Try to load from local database as fallback
      await _loadMedicinesFromLocal();
    }

    // Only notify once at the end
    notifyListeners();
  }

  // Fetch categories without notifying listeners
  Future<void> _fetchCategories() async {
    try {
      // First try to get from API
      final apiCategories = await _apiService.getCategories();
      _categories = apiCategories;
    } catch (e) {
      // Fallback to extracting categories from local medicines if API fails
      if (_medicines.isNotEmpty) {
        // Extract unique categories from loaded medicines
        final categorySet = <String>{};
        for (var medicine in _medicines) {
          if (medicine.category.isNotEmpty) {
            categorySet.add(medicine.category);
          }
        }
        _categories = categorySet.toList();
      } else {
        _categories = [];
      }
    }
  }

  // Load medicines from local database as fallback
  Future<void> _loadMedicinesFromLocal() async {
    try {
      _medicines = await _dbHelper.getAllMedicines();
      _featuredMedicines = await _dbHelper.getFeaturedMedicines();
      _state = ProviderState.loaded;
    } catch (e) {
      _error = 'Failed to load medicines from local database: $e';
      _state = ProviderState.error;
    }
  }

  // Get medicine details by ID
  Future<Medicine?> getMedicineById(int id) async {
    try {
      Medicine? medicine;

      try {
        // First try to get from API
        medicine = await _apiService.getMedicineById(id);
      } catch (e) {
        // Fallback to local database
        medicine = await _dbHelper.getMedicineById(id);
      }

      return medicine;
    } catch (e) {
      throw Exception('Failed to get medicine: $e');
    }
  }

  // Filter medicines by category
  Future<List<Medicine>> getMedicinesByCategory(String category) async {
    // Don't call notifyListeners here, as it might be during build
    List<Medicine> medicines = [];

    try {
      // First try to get from API
      medicines = await _apiService.getMedicines(category: category);
    } catch (e) {
      try {
        // Fallback to local database
        medicines = await _dbHelper.getMedicinesByCategory(category);
      } catch (dbError) {
        _error = 'Failed to get medicines by category: $e';
      }
    }

    return medicines;
  }

  // Search medicines
  Future<List<Medicine>> searchMedicines(String query) async {
    // Don't call notifyListeners here, as it might be during build
    List<Medicine> medicines = [];

    try {
      // First try to get from API
      medicines = await _apiService.getMedicines(search: query);
    } catch (e) {
      try {
        // Fallback to local search
        final allMedicines = await _dbHelper.getAllMedicines();
        medicines =
            allMedicines
                .where(
                  (med) =>
                      med.name.toLowerCase().contains(query.toLowerCase()) ||
                      med.description.toLowerCase().contains(
                        query.toLowerCase(),
                      ),
                )
                .toList();
      } catch (dbError) {
        _error = 'Failed to search medicines: $e';
      }
    }

    return medicines;
  }

  // Sync medicines from API to local database
  Future<void> _syncMedicinesToLocal(List<Medicine> medicines) async {
    for (var medicine in medicines) {
      if (medicine.id != null) {
        try {
          await _dbHelper.insertMedicine(medicine);
        } catch (e) {
          // Ignore errors, just continue with next medicine
        }
      }
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
