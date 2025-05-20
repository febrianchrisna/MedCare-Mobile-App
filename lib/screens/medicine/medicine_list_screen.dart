import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:medcareapp/models/medicine.dart';
import 'package:medcareapp/providers/medicine_provider.dart';
import 'package:medcareapp/screens/medicine/medicine_detail_screen.dart';
import 'package:medcareapp/widgets/medicine_card.dart';

class MedicineListScreen extends StatefulWidget {
  final String? category;

  const MedicineListScreen({Key? key, this.category}) : super(key: key);

  @override
  State<MedicineListScreen> createState() => _MedicineListScreenState();
}

class _MedicineListScreenState extends State<MedicineListScreen> {
  String _searchQuery = '';
  String? _selectedCategory;
  List<Medicine> _filteredMedicines = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.category;
    _loadMedicines();
  }

  Future<void> _loadMedicines() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final medicineProvider = Provider.of<MedicineProvider>(
        context,
        listen: false,
      );

      if (_selectedCategory != null && _selectedCategory!.isNotEmpty) {
        _filteredMedicines = await medicineProvider.getMedicinesByCategory(
          _selectedCategory!,
        );
      } else if (_searchQuery.isNotEmpty) {
        _filteredMedicines = await medicineProvider.searchMedicines(
          _searchQuery,
        );
      } else {
        _filteredMedicines = medicineProvider.medicines;
      }
    } catch (e) {
      // Handle error
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading medicines: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _updateCategory(String? category) {
    setState(() {
      _selectedCategory = category;
      _searchQuery = '';
    });
    _loadMedicines();
  }

  void _performSearch(String query) {
    setState(() {
      _searchQuery = query;
      _selectedCategory = null;
    });
    _loadMedicines();
  }

  @override
  Widget build(BuildContext context) {
    final medicineProvider = Provider.of<MedicineProvider>(context);
    final categories = medicineProvider.categories;

    return Scaffold(
      appBar: AppBar(title: const Text('Medicines')),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search medicines...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onSubmitted: _performSearch,
            ),
          ),

          // Categories Filter
          SizedBox(
            height: 50,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: categories.length + 1, // +1 for "All" option
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: FilterChip(
                      label: const Text('All'),
                      selected: _selectedCategory == null,
                      onSelected: (selected) {
                        if (selected) {
                          _updateCategory(null);
                        }
                      },
                    ),
                  );
                }

                final category = categories[index - 1];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: FilterChip(
                    label: Text(category),
                    selected: _selectedCategory == category,
                    onSelected: (selected) {
                      if (selected) {
                        _updateCategory(category);
                      }
                    },
                  ),
                );
              },
            ),
          ),

          // Medicines Grid
          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _filteredMedicines.isEmpty
                    ? const Center(child: Text('No medicines found'))
                    : GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.7,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                          ),
                      itemCount: _filteredMedicines.length,
                      itemBuilder: (context, index) {
                        return MedicineCard(
                          medicine: _filteredMedicines[index],
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (_) => MedicineDetailScreen(
                                      medicineId: _filteredMedicines[index].id!,
                                    ),
                              ),
                            );
                          },
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}
