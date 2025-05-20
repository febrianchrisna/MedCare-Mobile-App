import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:medcareapp/models/medicine.dart';
import 'package:medcareapp/providers/medicine_provider.dart';
import 'package:medcareapp/providers/cart_provider.dart';
import 'package:medcareapp/utils/constants.dart';
import 'package:medcareapp/utils/theme.dart';
import 'package:fluttertoast/fluttertoast.dart';

class MedicineDetailScreen extends StatefulWidget {
  final int medicineId;

  const MedicineDetailScreen({Key? key, required this.medicineId})
    : super(key: key);

  @override
  State<MedicineDetailScreen> createState() => _MedicineDetailScreenState();
}

class _MedicineDetailScreenState extends State<MedicineDetailScreen> {
  Medicine? _medicine;
  bool _isLoading = true;
  String? _error;
  int _quantity = 1;

  @override
  void initState() {
    super.initState();
    _loadMedicine();
  }

  Future<void> _loadMedicine() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final provider = Provider.of<MedicineProvider>(context, listen: false);
      final medicine = await provider.getMedicineById(widget.medicineId);

      if (!mounted) return;

      setState(() {
        _medicine = medicine;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _incrementQuantity() {
    if (_medicine != null && _quantity < _medicine!.stock) {
      setState(() {
        _quantity++;
      });
    }
  }

  void _decrementQuantity() {
    if (_quantity > 1) {
      setState(() {
        _quantity--;
      });
    }
  }

  void _addToCart() {
    if (_medicine != null) {
      final cartProvider = Provider.of<CartProvider>(context, listen: false);
      cartProvider.addToCart(_medicine!, _quantity);

      Fluttertoast.showToast(
        msg: "Added to cart",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: AppTheme.successColor,
        textColor: Colors.white,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_medicine?.name ?? 'Medicine Details')),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Error: $_error'),
                    ElevatedButton(
                      onPressed: _loadMedicine,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              )
              : _medicine == null
              ? const Center(child: Text('Medicine not found'))
              : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Medicine Image
                    Container(
                      height: 250,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            spreadRadius: 1,
                            blurRadius: 5,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child:
                          _medicine!.image != null &&
                                  _medicine!.image!.isNotEmpty
                              ? Image.network(
                                _medicine!.image!,
                                fit: BoxFit.contain,
                                errorBuilder:
                                    (context, error, stackTrace) =>
                                        Image.network(
                                          defaultMedicineImage,
                                          fit: BoxFit.contain,
                                        ),
                              )
                              : Image.network(
                                defaultMedicineImage,
                                fit: BoxFit.contain,
                              ),
                    ),

                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Category & Stock badge
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  _medicine!.category,
                                  style: TextStyle(
                                    color: AppTheme.primaryColor,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      _medicine!.stock > 0
                                          ? AppTheme.successColor.withOpacity(
                                            0.1,
                                          )
                                          : AppTheme.dangerColor.withOpacity(
                                            0.1,
                                          ),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  _medicine!.stock > 0
                                      ? 'In Stock (${_medicine!.stock})'
                                      : 'Out of Stock',
                                  style: TextStyle(
                                    color:
                                        _medicine!.stock > 0
                                            ? AppTheme.successColor
                                            : AppTheme.dangerColor,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          // Name & Price
                          Text(
                            _medicine!.name,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          if (_medicine!.dosage != null &&
                              _medicine!.dosage!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              _medicine!.dosage!,
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],

                          const SizedBox(height: 12),

                          Text(
                            'Rp ${_medicine!.price.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryColor,
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Description
                          const Text(
                            'Description',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 8),

                          Text(
                            _medicine!.description,
                            style: const TextStyle(fontSize: 14, height: 1.5),
                          ),

                          const SizedBox(height: 20),

                          // Additional Info
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Manufacturer',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _medicine!.manufacturer ?? 'N/A',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (_medicine!.expiryDate != null)
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Expiry Date',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${_medicine!.expiryDate!.day}/${_medicine!.expiryDate!.month}/${_medicine!.expiryDate!.year}',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      bottomNavigationBar:
          _medicine == null
              ? null
              : Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 10,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Quantity selector
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove),
                            onPressed: _decrementQuantity,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            iconSize: 18,
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              _quantity.toString(),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add),
                            onPressed: _incrementQuantity,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            iconSize: 18,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 16),

                    // Add to cart button
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _medicine!.stock > 0 ? _addToCart : null,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(
                          _medicine!.stock > 0
                              ? 'Add to Cart - Rp ${(_medicine!.price * _quantity).toStringAsFixed(2)}'
                              : 'Out of Stock',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
    );
  }
}
