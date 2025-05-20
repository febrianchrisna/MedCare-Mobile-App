import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:medcareapp/models/order.dart';
import 'package:medcareapp/providers/order_provider.dart';
import 'package:medcareapp/utils/theme.dart';
import 'package:intl/intl.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:medcareapp/utils/local_order_updates_manager.dart';

class OrderDetailScreen extends StatefulWidget {
  final int orderId;

  const OrderDetailScreen({Key? key, required this.orderId}) : super(key: key);

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen>
    with WidgetsBindingObserver {
  bool _isLoading = true;
  Order? _order;
  String? _error;

  // Edit mode state
  bool _isEditMode = false;
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _addressController;
  String _selectedPaymentMethod = 'Cash on Delivery';

  // Payment method options
  final List<String> _paymentMethods = [
    'Cash on Delivery',
    'Credit Card',
    'Bank Transfer',
    'Digital Wallet',
  ];

  @override
  void initState() {
    super.initState();
    _addressController = TextEditingController();
    // Add this widget as an observer to detect app lifecycle changes
    WidgetsBinding.instance.addObserver(this);
    // Use addPostFrameCallback to ensure this runs after the initial build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadOrderDetails(forceRefresh: true);
    });
  }

  @override
  void dispose() {
    // Remove this widget as an observer
    WidgetsBinding.instance.removeObserver(this);
    _addressController.dispose();
    super.dispose();
  }

  // Add this method to detect when the screen becomes visible again
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Refresh data when app is resumed
      _loadOrderDetails(forceRefresh: true);
    }
  }

  // Modify to accept a forceRefresh parameter
  Future<void> _loadOrderDetails({bool forceRefresh = false}) async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final orderProvider = Provider.of<OrderProvider>(context, listen: false);
      final order = await orderProvider.getOrderById(
        widget.orderId,
        forceRefresh: forceRefresh,
      );

      // Apply local updates after getting from provider
      final locallyUpdatedOrder =
          await LocalOrderUpdatesManager.applyLocalUpdates(order);

      if (!mounted) return;

      // Initialize form fields with current values
      _addressController.text = locallyUpdatedOrder.address ?? '';
      _selectedPaymentMethod =
          locallyUpdatedOrder.paymentMethod ?? 'Cash on Delivery';

      setState(() {
        _order = locallyUpdatedOrder;
        _isLoading = false;
      });

      print(
        'DEBUG: Loaded order details: addr=${_order!.address}, payment=${_order!.paymentMethod}',
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
      print('Error loading order details: $_error');
    }
  }

  // Toggle edit mode
  void _toggleEditMode() {
    setState(() {
      _isEditMode = !_isEditMode;

      // Reset form data when entering edit mode
      if (_isEditMode && _order != null) {
        _addressController.text = _order!.address ?? '';
        _selectedPaymentMethod = _order!.paymentMethod ?? 'Cash on Delivery';
      }
    });
  }

  // Save changes
  Future<void> _saveChanges() async {
    if (_formKey.currentState!.validate() && _order != null) {
      setState(() {
        _isLoading = true;
      });

      final updates = {
        'address': _addressController.text,
        'paymentMethod': _selectedPaymentMethod,
      };

      try {
        // IMPORTANT: Save local updates first before API call
        if (_order!.id != null) {
          await LocalOrderUpdatesManager.saveOrderUpdate(_order!.id!, updates);
          print(
            'DEBUG: Saved local update in order detail: ${_order!.id}, ${updates}',
          );

          // Debug - show all updates
          await LocalOrderUpdatesManager.debugPrintAllUpdates();
        }

        final orderProvider = Provider.of<OrderProvider>(
          context,
          listen: false,
        );
        final success = await orderProvider.updateUserOrder(
          _order!.id!,
          updates,
        );

        if (!mounted) return;

        if (success) {
          // Create locally updated order to show in UI
          final updatedOrder = Order(
            id: _order!.id,
            userId: _order!.userId,
            items: _order!.items,
            totalAmount: _order!.totalAmount,
            status: _order!.status,
            address: _addressController.text,
            paymentMethod: _selectedPaymentMethod,
            notes: _order!.notes,
            createdAt: _order!.createdAt,
            updatedAt: DateTime.now(),
          );

          setState(() {
            _order = updatedOrder;
            _isEditMode = false;
            _isLoading = false;
          });

          print(
            'DEBUG: Updated order in UI: addr=${_order!.address}, payment=${_order!.paymentMethod}',
          );

          Fluttertoast.showToast(
            msg: "Order updated successfully",
            backgroundColor: AppTheme.successColor,
            textColor: Colors.white,
          );

          // Return true to signal an update happened
          Navigator.of(context).pop(true);
        } else {
          // ...existing error handling...
        }
      } catch (e) {
        if (!mounted) return;

        setState(() {
          _error = e.toString();
          _isLoading = false;
        });

        Fluttertoast.showToast(
          msg: "Error: $_error",
          backgroundColor: AppTheme.dangerColor,
          textColor: Colors.white,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Replace WillPopScope with PopScope
    return PopScope(
      // Handle back button press with canPop and onPopInvoked
      canPop: !_isLoading && !_isEditMode,
      onPopInvoked: (didPop) {
        // If already popped, no need to do anything
        if (didPop) return;

        // If we're in edit mode, cancel edit instead of going back
        if (_isEditMode) {
          setState(() {
            _isEditMode = false;
          });
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Order #${widget.orderId}'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              // Handle back button press in app bar
              if (_isEditMode) {
                // If in edit mode, just cancel edit
                setState(() {
                  _isEditMode = false;
                });
              } else {
                // Otherwise navigate back normally
                Navigator.of(context).pop();
              }
            },
          ),
          actions: [
            // Show edit button only for pending orders
            if (_order != null && _order!.status.toLowerCase() == 'pending')
              IconButton(
                icon: Icon(_isEditMode ? Icons.close : Icons.edit),
                onPressed: _toggleEditMode,
                tooltip: _isEditMode ? 'Cancel Edit' : 'Edit Order',
              ),
          ],
        ),
        body:
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 60,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Error: $_error',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadOrderDetails,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
                : _order == null
                ? const Center(child: Text('Order not found'))
                : _isEditMode
                ? _buildEditForm()
                : _buildOrderDetails(),
        bottomNavigationBar:
            _isLoading || _error != null || _order == null
                ? null
                : _isEditMode
                ? _buildEditBottomBar()
                : _buildBottomBar(),
      ),
    );
  }

  Widget _buildEditForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Current order information
            Card(
              margin: const EdgeInsets.only(bottom: 20),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Order #${_order!.id}',
                          style: const TextStyle(fontSize: 16),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _getStatusColor(
                              _order!.status,
                            ).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _order!.status,
                            style: TextStyle(
                              color: _getStatusColor(_order!.status),
                              fontWeight: FontWeight.w500,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Date: ${DateFormat('MMM dd, yyyy').format(_order!.createdAt)}',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    Text(
                      'Total: \$${_order!.totalAmount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const Text(
              'Edit Order Details',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Address field
            const Text(
              'Shipping Address',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _addressController,
              decoration: const InputDecoration(
                hintText: 'Enter your delivery address',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
              maxLines: 3,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your shipping address';
                }
                return null;
              },
            ),

            const SizedBox(height: 20),

            // Payment method field
            const Text(
              'Payment Method',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedPaymentMethod,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
              items:
                  _paymentMethods.map((method) {
                    return DropdownMenuItem(value: method, child: Text(method));
                  }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedPaymentMethod = value!;
                });
              },
            ),

            const SizedBox(height: 16),

            // Note about editing
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.amber),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'You can only edit the shipping address and payment method while the order is in \'Pending\' status.',
                      style: TextStyle(color: Colors.amber[800]),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _toggleEditMode,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('Cancel'),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: _saveChanges,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                backgroundColor: AppTheme.primaryColor,
              ),
              child: const Text('Save Changes'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderDetails() {
    final order = _order!;

    // Apply any last-minute visual updates for debugging
    print(
      'Building order details UI with: id=${order.id}, address=${order.address}, payment=${order.paymentMethod}',
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Order Status Card
          Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Order Status',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: _getStatusColor(order.status).withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _getStatusIcon(order.status),
                          color: _getStatusColor(order.status),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              order.status,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _getStatusColor(order.status),
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _getStatusDescription(order.status),
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
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
          ),

          // Order Details
          Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Order Details',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      // Edit button for pending orders
                      if (order.status.toLowerCase() == 'pending')
                        TextButton.icon(
                          onPressed: _toggleEditMode,
                          icon: const Icon(Icons.edit, size: 16),
                          label: const Text('Edit'),
                          style: TextButton.styleFrom(
                            foregroundColor: AppTheme.primaryColor,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildDetailRow('Order ID', '#${order.id}'),
                  _buildDetailRow(
                    'Order Date',
                    DateFormat('MMMM dd, yyyy').format(order.createdAt),
                  ),
                  if (order.updatedAt != null)
                    _buildDetailRow(
                      'Last Updated',
                      DateFormat('MMMM dd, yyyy').format(order.updatedAt!),
                    ),
                  _buildDetailRow(
                    'Payment Method',
                    order.paymentMethod ?? 'N/A',
                  ),
                  _buildDetailRow('Shipping Address', order.address ?? 'N/A'),
                ],
              ),
            ),
          ),

          // Order Items
          Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Order Items',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: order.items.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (context, index) {
                      final item = order.items[index];
                      return Row(
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child:
                                item.medicineImage != null
                                    ? Image.network(
                                      item.medicineImage!,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (_, __, ___) =>
                                              const Icon(Icons.medication),
                                    )
                                    : const Icon(Icons.medication),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.medicineName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Quantity: ${item.quantity}',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '\$${(item.price * item.quantity).toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const Divider(thickness: 1),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '\$${order.totalAmount.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    final order = _order!;

    // Don't show actions for completed orders
    final canCancel =
        order.status.toLowerCase() == 'pending' ||
        order.status.toLowerCase() == 'processing';

    if (!canCancel) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: () => _showCancelDialog(),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red[50],
          foregroundColor: Colors.red,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: Colors.red),
          ),
        ),
        child: const Text('Delete Order'),
      ),
    );
  }

  void _showCancelDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Order'),
            content: const Text(
              'Are you sure you want to delete this order? This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('No'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await _cancelOrder();
                },
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Yes, Delete'),
              ),
            ],
          ),
    );
  }

  Future<void> _cancelOrder() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final orderProvider = Provider.of<OrderProvider>(context, listen: false);
      final success = await orderProvider.cancelOrder(_order!.id!);

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order deleted successfully')),
        );
        // Go back to orders screen after deleting
        Navigator.pop(context);
      } else {
        setState(() {
          _error = orderProvider.error;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'processing':
        return Colors.blue;
      case 'shipped':
        return Colors.indigo;
      case 'delivered':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Icons.hourglass_empty;
      case 'processing':
        return Icons.sync;
      case 'shipped':
        return Icons.local_shipping;
      case 'delivered':
        return Icons.check_circle;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }

  String _getStatusDescription(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Your order has been placed and is awaiting confirmation.';
      case 'processing':
        return 'Your order is being processed and prepared for shipping.';
      case 'shipped':
        return 'Your order has been shipped and is on its way.';
      case 'delivered':
        return 'Your order has been delivered successfully.';
      case 'cancelled':
        return 'Your order has been cancelled.';
      default:
        return 'Status unknown.';
    }
  }
}
