import 'dart:developer';

import 'package:animated_custom_dropdown/custom_dropdown.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:provider/provider.dart';
import '../provider_and_models/cyllo_session_model.dart';
import '../provider_and_models/order_picking_provider.dart';
import '../provider_and_models/sales_order_provider.dart';

class SaleOrderPage extends StatefulWidget {
  final List<Product> selectedProducts;
  final Map<String, int> quantities;
  final double totalAmount;
  final String orderId;
  final VoidCallback? onClearSelections;
  final Map<String, List<Map<String, dynamic>>>? productAttributes;

  const SaleOrderPage({
    Key? key,
    required this.selectedProducts,
    required this.quantities,
    required this.totalAmount,
    required this.orderId,
    this.onClearSelections,
    this.productAttributes,
  }) : super(key: key);

  @override
  State<SaleOrderPage> createState() => _SaleOrderPageState();
}

class _SaleOrderPageState extends State<SaleOrderPage> {
  Customer? _selectedCustomer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final orderPickingProvider =
          Provider.of<OrderPickingProvider>(context, listen: false);
      if (orderPickingProvider.customers.isEmpty) {
        orderPickingProvider.loadCustomers();
      }
    });
  }

  void _showDuplicateOrderDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.grey[200]!,
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.error_outline,
                            color: Colors.red,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Duplicate Order',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        color: Colors.grey[600],
                        size: 24,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order ID ${widget.orderId} already exists.',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Please use a different order ID to proceed.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(16),
                  ),
                  border: Border(
                    top: BorderSide(
                      color: Colors.grey[200]!,
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () {
                        widget.onClearSelections
                            ?.call(); // Call the callback here
                        Navigator.of(context).pop(); // Close dialog
                        Navigator.pop(context); // Return to previous screen
                      },
                      child: Text(
                        'Go Back',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: primaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createSaleOrderInOdoo(BuildContext context) async {
    final salesOrderProvider =
        Provider.of<SalesOrderProvider>(context, listen: false);
    final orderPickingProvider =
        Provider.of<OrderPickingProvider>(context, listen: false);

    try {
      if (salesOrderProvider.isOrderIdConfirmed(widget.orderId)) {
        _showDuplicateOrderDialog(context);
        return;
      }

      if (_selectedCustomer == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Please select a customer before confirming the order'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }

      final client = await SessionManager.getActiveClient();
      if (client == null) {
        throw Exception('No active Odoo session found. Please log in again.');
      }

      final orderLines = <dynamic>[];
      for (var product in widget.selectedProducts) {
        final attributes = widget.productAttributes?[product.id];
        if (attributes != null && attributes.isNotEmpty) {
          for (var combo in attributes) {
            final qty = combo['quantity'] as int;
            final attrs = combo['attributes'] as Map<String, String>;
            double extraCost = 0;
            for (var attr in product.attributes!) {
              final value = attrs[attr.name];
              if (value != null && attr.extraCost != null) {
                extraCost += attr.extraCost![value] ?? 0;
              }
            }
            final adjustedPrice = product.price + extraCost;
            orderLines.add([
              0,
              0,
              {
                'product_id': int.parse(product.id),
                'name':
                    '${product.name} (${attrs.entries.map((e) => '${e.key}: ${e.value}').join(', ')})',
                'product_uom_qty': qty,
                'price_unit': adjustedPrice,
              }
            ]);
          }
        } else {
          final quantity = widget.quantities[product.id] ?? 0;
          if (quantity > 0) {
            orderLines.add([
              0,
              0,
              {
                'product_id': int.parse(product.id),
                'name': product.name,
                'product_uom_qty': quantity,
                'price_unit': product.price,
              }
            ]);
          }
        }
      }

      final saleOrderId = await client.callKw({
        'model': 'sale.order',
        'method': 'create',
        'args': [
          {
            'name': widget.orderId,
            'partner_id': int.parse(_selectedCustomer!.id),
            'order_line': orderLines,
            'state': 'sale',
            'date_order':
                DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
          }
        ],
        'kwargs': {},
      });

      final orderItems = widget.selectedProducts
          .map((product) => OrderItem(
                product: product,
                quantity: widget.quantities[product.id] ?? 0,
              ))
          .toList();

      await salesOrderProvider.confirmOrderInCyllo(
        orderId: widget.orderId,
        items: orderItems,
      );

      _showOrderConfirmationDialog(context, widget.orderId, orderItems,
          widget.totalAmount, salesOrderProvider);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to confirm order: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _showCustomerSelectionDialog(BuildContext context) {
    final orderPickingProvider =
        Provider.of<OrderPickingProvider>(context, listen: false);
    bool _isConfirmLoading =
        false;

    Customer? localSelectedCustomer = _selectedCustomer;


    if (orderPickingProvider.customers.isEmpty &&
        !orderPickingProvider.isLoadingCustomers) {
      orderPickingProvider.loadCustomers();
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: Colors.transparent,
          child: Consumer<OrderPickingProvider>(
            builder: (context, orderPickingProvider, child) {
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header remains the same
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(16),
                        ),
                        border: Border(
                          bottom: BorderSide(
                            color: Colors.grey[200]!,
                            width: 1,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: primaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.person,
                                  color: primaryColor,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Select Customer',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.close,
                              color: Colors.grey[600],
                              size: 24,
                            ),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          orderPickingProvider.isLoadingCustomers
                              ? const Center(
                                  child: SizedBox(
                                      height: 40,
                                      child: CircularProgressIndicator()))
                              : CustomDropdown<Customer>.search(
                                  items: orderPickingProvider.customers,
                                  hintText: 'Select or search customer...',
                                  searchHintText: 'Search customers...',
                                  noResultFoundText: orderPickingProvider
                                          .customers.isEmpty
                                      ? 'No customers found. Create a new customer?'
                                      : 'No matching customers found',
                                  noResultFoundBuilder: orderPickingProvider
                                          .customers.isEmpty
                                      ? (context, searchText) {
                                          return GestureDetector(
                                            onTap: () => orderPickingProvider
                                                .showCreateCustomerDialog(
                                                    context),
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 12,
                                                      horizontal: 16),
                                              child: Row(
                                                children: [
                                                  const Icon(Icons.add_circle,
                                                      color: primaryColor),
                                                  const SizedBox(width: 8),
                                                  const Text(
                                                    'Create New Customer',
                                                    style: TextStyle(
                                                      color: primaryColor,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        }
                                      : null,
                                  decoration: CustomDropdownDecoration(
                                    closedBorder:
                                        Border.all(color: Colors.grey[300]!),
                                    closedBorderRadius:
                                        BorderRadius.circular(8),
                                    expandedBorderRadius:
                                        BorderRadius.circular(8),
                                    listItemDecoration: ListItemDecoration(
                                      selectedColor:
                                          primaryColor.withOpacity(0.1),
                                    ),
                                    headerStyle: const TextStyle(
                                      color: Colors.black87,
                                      fontSize: 16,
                                    ),
                                    searchFieldDecoration:
                                        SearchFieldDecoration(
                                      hintStyle:
                                          TextStyle(color: Colors.grey[600]),
                                      fillColor: Colors.white,
                                      border: OutlineInputBorder(
                                        borderSide: BorderSide(
                                            color: Colors.grey[300]!),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderSide: BorderSide(
                                          color: primaryColor,
                                          width: 2,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                  initialItem: localSelectedCustomer,
                                  headerBuilder:
                                      (context, customer, isSelected) {
                                    return Text(customer.name);
                                  },
                                  listItemBuilder: (context, customer,
                                      isSelected, onItemSelect) {
                                    return GestureDetector(
                                      onTap: () {
                                        onItemSelect();
                                        setDialogState(() {
                                          localSelectedCustomer = customer;
                                        });
                                        setState(() {
                                          _selectedCustomer = customer;
                                        });
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 12, horizontal: 16),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    customer.name,
                                                    style: TextStyle(
                                                      color: isSelected
                                                          ? primaryColor
                                                          : Colors.black87,
                                                      fontWeight: isSelected
                                                          ? FontWeight.bold
                                                          : FontWeight.normal,
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                                  Text(
                                                    customer.email ??
                                                        'No email',
                                                    style: TextStyle(
                                                      color: Colors.grey[600],
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            if (isSelected)
                                              Icon(
                                                Icons.check_circle,
                                                color: primaryColor,
                                                size: 20,
                                              ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                  onChanged: (Customer? newCustomer) {
                                    if (newCustomer != null) {
                                      setDialogState(() {
                                        localSelectedCustomer = newCustomer;
                                      });
                                      setState(() {
                                        _selectedCustomer = newCustomer;
                                      });
                                    }
                                  },
                                  validator: (value) {
                                    if (value == null) {
                                      return 'Please select a customer';
                                    }
                                    return null;
                                  },
                                  excludeSelected: false,
                                  canCloseOutsideBounds: true,
                                  closeDropDownOnClearFilterSearch: true,
                                ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              TextButton.icon(
                                onPressed: () => orderPickingProvider
                                    .showCreateCustomerDialog(context),
                                icon: const Icon(Icons.add_circle_outline,
                                    color: primaryColor, size: 16),
                                label: const Text(
                                  'Create Customer',
                                  style: TextStyle(color: primaryColor),
                                ),
                              ),
                              TextButton.icon(
                                onPressed: () {
                                  orderPickingProvider.loadCustomers();
                                  setDialogState(() {
                                    localSelectedCustomer = null;
                                  });
                                  setState(() {
                                    _selectedCustomer = null;
                                  });
                                },
                                icon: const Icon(Icons.refresh,
                                    color: primaryColor, size: 16),
                                label: const Text(
                                  'Refresh',
                                  style: TextStyle(color: primaryColor),
                                ),
                              ),
                            ],
                          ),
                          if (localSelectedCustomer != null) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey[200]!),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Selected Customer Details:',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: primaryDarkColor,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.person_outline,
                                        color: Colors.grey[600],
                                        size: 16,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          localSelectedCustomer!.name,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.black87,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.phone_outlined,
                                        color: Colors.grey[600],
                                        size: 16,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          localSelectedCustomer!.phone ??
                                              'No phone',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey[600],
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.email_outlined,
                                        color: Colors.grey[600],
                                        size: 16,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          localSelectedCustomer!.email ??
                                              'No email',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey[600],
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.location_city_outlined,
                                        color: Colors.grey[600],
                                        size: 16,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          localSelectedCustomer!.city ??
                                              'No city',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey[600],
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(16),
                        ),
                        border: Border(
                          top: BorderSide(
                            color: Colors.grey[200]!,
                            width: 1,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: () => Navigator.of(context).pop(),
                            child: Text(
                              'Cancel',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                          Consumer<SalesOrderProvider>(
                            builder: (context, salesOrderProvider, child) {
                              return ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryColor,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                onPressed: localSelectedCustomer == null ||
                                        _isConfirmLoading
                                    ? null
                                    : () async {
                                        setDialogState(() {
                                          _isConfirmLoading =
                                              true; // Start loading
                                        });
                                        setState(() {
                                          _selectedCustomer =
                                              localSelectedCustomer;
                                        });
                                        try {
                                          await _createSaleOrderInOdoo(context);
                                        } finally {
                                          setDialogState(() {
                                            _isConfirmLoading =
                                                false; // Stop loading
                                          });
                                        }
                                      },
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text(
                                      'Confirm',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Visibility(
                                      visible: _isConfirmLoading,
                                      child: const Padding(
                                        padding: EdgeInsets.only(left: 8),
                                        child: SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                    Colors.white),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _showOrderConfirmationDialog(
    BuildContext context,
    String orderId,
    List<OrderItem> items,
    double totalAmount,
    SalesOrderProvider salesOrderProvider,
  ) {
    final currencyFormat = NumberFormat.currency(symbol: '\$');
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                  border: Border(
                      bottom: BorderSide(color: Colors.grey[200]!, width: 1)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.check_circle,
                              color: Colors.green, size: 24),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Order Confirmed',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87),
                        ),
                      ],
                    ),
                    IconButton(
                      icon:
                          Icon(Icons.close, color: Colors.grey[600], size: 24),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              // Content Section
              SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.receipt_long,
                              size: 16, color: primaryColor),
                          const SizedBox(width: 8),
                          Text(
                            'Order ID: $orderId',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: primaryColor),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...items
                        .map(
                          (item) => Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: Colors.grey[200]!, width: 1),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.product.name,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black87,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Wrap(
                                        spacing: 12,
                                        children: [
                                          Text(
                                            'Qty: ${item.quantity}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          Flexible(
                                            child: Text(
                                              'Code: ${item.product.defaultCode ?? 'N/A'}',
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[600]),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  flex: 1,
                                  child: Text(
                                    currencyFormat.format(item.subtotal),
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: primaryColor,
                                    ),
                                    textAlign: TextAlign.end,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey[200]!, width: 1),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.attach_money,
                                  color: primaryColor, size: 20),
                              const SizedBox(width: 8),
                              const Text(
                                'Total Amount',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87),
                              ),
                            ],
                          ),
                          Text(
                            currencyFormat.format(totalAmount),
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: primaryColor),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius:
                      const BorderRadius.vertical(bottom: Radius.circular(16)),
                  border: Border(
                      top: BorderSide(color: Colors.grey[200]!, width: 1)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () {
                        salesOrderProvider.clearOrder();
                        salesOrderProvider.resetInventory();
                        salesOrderProvider.notifyOrderConfirmed();
                        widget.onClearSelections?.call();
                        Navigator.of(context).pop();
                        Navigator.popUntil(context, (route) => route.isFirst);
                      },
                      child: Text(
                        'Done',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: primaryColor),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: '\$');
    final totalItems = widget.selectedProducts.fold<int>(
        0, (sum, product) => sum + (widget.quantities[product.id] ?? 0));

    double recalculatedTotal = 0;
    for (var product in widget.selectedProducts) {
      final attributes = widget.productAttributes?[product.id];
      if (attributes != null && attributes.isNotEmpty) {
        for (var combo in attributes) {
          final qty = combo['quantity'] as int;
          final attrs = combo['attributes'] as Map<String, String>;
          double extraCost = 0;
          for (var attr in product.attributes ?? []) {
            final value = attrs[attr.name];
            if (value != null && attr.extraCost != null) {
              extraCost += attr.extraCost![value] ?? 0;
            }
          }
          recalculatedTotal += (product.price + extraCost) * qty;
        }
      } else {
        final quantity = widget.quantities[product.id] ?? 0;
        recalculatedTotal += product.price * quantity;
      }
    }

    // Log for debugging
    final displayTotal = recalculatedTotal;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          'Order Summary - ${widget.orderId}',
          style:
              const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: primaryColor,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Selected Products (${widget.selectedProducts.length})',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  Text(
                    'Items: $totalItems',
                    style: TextStyle(
                      fontSize: 14,
                      color: neutralGrey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.separated(
                  itemCount: widget.selectedProducts.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final product = widget.selectedProducts[index];
                    final quantity = widget.quantities[product.id] ?? 0;
                    final attributes = widget.productAttributes?[product.id];
                    double subtotal = 0;

                    List<Widget> attributeDetails = [];
                    if (attributes != null && attributes.isNotEmpty) {
                      for (var combo in attributes) {
                        final qty = combo['quantity'] as int;
                        final attrs =
                            combo['attributes'] as Map<String, String>;
                        double extraCost = 0;
                        for (var attr in product.attributes ?? []) {
                          final value = attrs[attr.name];
                          if (value != null && attr.extraCost != null) {
                            extraCost += attr.extraCost![value] ?? 0;
                          }
                        }
                        final adjustedPrice = product.price + extraCost;
                        subtotal += adjustedPrice * qty;

                        attributeDetails.add(
                          Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    '${attrs.entries.map((e) => '${e.key}: ${e.value}').join(', ')} - Qty: $qty',
                                    style: TextStyle(
                                      color: Colors.grey[700],
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                Text(
                                  '+${currencyFormat.format(extraCost)}',
                                  style: TextStyle(
                                    color: Colors.redAccent,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                    } else {
                      subtotal = product.price * quantity;
                    }

                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.symmetric(
                          horizontal: 0, vertical: 6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 70,
                                  height: 70,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    border:
                                        Border.all(color: Colors.grey[200]!),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: product.imageUrl != null &&
                                            product.imageUrl!.isNotEmpty
                                        ? Image.memory(
                                            base64Decode(product.imageUrl!
                                                .split(',')
                                                .last),
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stackTrace) =>
                                                    Container(
                                              color: Colors.grey[100],
                                              child: Center(
                                                child: Icon(
                                                  Icons.inventory_2_rounded,
                                                  color: primaryColor,
                                                  size: 24,
                                                ),
                                              ),
                                            ),
                                          )
                                        : Container(
                                            color: Colors.grey[100],
                                            child: Center(
                                              child: Icon(
                                                Icons.inventory_2_rounded,
                                                color: primaryColor,
                                                size: 24,
                                              ),
                                            ),
                                          ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        product.name ?? 'Unknown Product',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black87,
                                          height: 1.2,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Text(
                                            'SKU:',
                                            style: TextStyle(
                                              color: Colors.grey[700],
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            product.defaultCode ?? 'N/A',
                                            style: TextStyle(
                                              color: Colors.grey[800],
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Builder(
                                        builder: (context) {
                                          final attributes = widget
                                              .productAttributes?[product.id];
                                          final totalQuantity =
                                              widget.quantities[product.id] ??
                                                  0;
                                          final pricing =
                                              _calculateProductPricing(
                                            product: product,
                                            attributes: attributes,
                                            totalQuantity: totalQuantity,
                                          );

                                          return Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Text(
                                                    'Qty: $totalQuantity',
                                                    style: TextStyle(
                                                      color: Colors.grey[700],
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                  const Spacer(),
                                                  Text(
                                                    'Total: ',
                                                    style: TextStyle(
                                                      color: Colors.grey[800],
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                  Text(
                                                    currencyFormat.format(
                                                        pricing.subtotal),
                                                    style: TextStyle(
                                                      color: primaryColor,
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            Builder(
                              builder: (context) {
                                final attributes =
                                    widget.productAttributes?[product.id];
                                final totalQuantity =
                                    widget.quantities[product.id] ?? 0;
                                final pricing = _calculateProductPricing(
                                  product: product,
                                  attributes: attributes,
                                  totalQuantity: totalQuantity,
                                );
                                if (pricing.attributeDetails.isNotEmpty) {
                                  return ExpansionTile(
                                    tilePadding: EdgeInsets.zero,
                                    childrenPadding: EdgeInsets.zero,
                                    shape: const Border(),
                                    collapsedShape: const Border(),
                                    title: Text(
                                      'Price Details',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                    children: [
                                      ...pricing.attributeDetails.map(
                                        (detail) => Padding(
                                          padding: const EdgeInsets.only(
                                              bottom: 6, left: 8, right: 8),
                                          child: Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: Colors.grey[50],
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              border: Border.all(
                                                  color: Colors.grey[200]!),
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  detail.attributesText,
                                                  style: TextStyle(
                                                    color: Colors.grey[800],
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        '${detail.quantity} × ${currencyFormat.format(product.price)}' +
                                                            (detail.extraCost >
                                                                    0
                                                                ? ' + ${detail.quantity} × ${currencyFormat.format(detail.extraCost)}'
                                                                : ''),
                                                        style: TextStyle(
                                                          color:
                                                              Colors.grey[700],
                                                          fontSize: 11,
                                                        ),
                                                      ),
                                                    ),
                                                    Text(
                                                      currencyFormat.format(
                                                          detail.lineTotal),
                                                      style: TextStyle(
                                                        color: primaryColor,
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                } else {
                                  return const SizedBox.shrink();
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total Items:',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: textColor,
                          ),
                        ),
                        Text(
                          totalItems.toString(),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total Amount:',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        Text(
                          currencyFormat.format(recalculatedTotal),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: primaryColor),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(kBorderRadius),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'Back to Selection',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Consumer<SalesOrderProvider>(
                      builder: (context, provider, child) {
                        return ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(kBorderRadius),
                            ),
                          ),
                          onPressed: provider.isLoading
                              ? null
                              : () => _showCustomerSelectionDialog(context),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                'Confirm',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Visibility(
                                visible: provider.isLoading,
                                child: const Padding(
                                  padding: EdgeInsets.only(left: 8),
                                  child: SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PricingData {
  final double subtotal;
  final List<AttributeDetail> attributeDetails;

  PricingData({
    required this.subtotal,
    required this.attributeDetails,
  });
}

class AttributeDetail {
  final String attributesText;
  final double extraCost;
  final int quantity;
  final double lineTotal;

  AttributeDetail({
    required this.attributesText,
    required this.extraCost,
    required this.quantity,
    required this.lineTotal,
  });
}

// Helper method to calculate product pricing
PricingData _calculateProductPricing({
  required Product product,
  List<Map<String, dynamic>>? attributes,
  required int totalQuantity,
}) {
  double subtotal = 0;
  List<AttributeDetail> attributeDetails = [];

  if (attributes != null && attributes.isNotEmpty) {
    for (var combo in attributes) {
      final qty = combo['quantity'] as int;
      final attrs = combo['attributes'] as Map<String, String>;
      double extraCost = 0;

      // Calculate extra cost for this combination
      for (var attr in product.attributes ?? []) {
        final value = attrs[attr.name];
        if (value != null && attr.extraCost != null) {
          extraCost += attr.extraCost![value] ?? 0;
        }
      }

      final lineTotal = (product.price + extraCost) * qty;
      subtotal += lineTotal;

      // Format attribute text
      final attrDescription =
          attrs.entries.map((e) => '${e.key}: ${e.value}').join(', ');

      // Create attribute detail
      attributeDetails.add(
        AttributeDetail(
          attributesText:
              qty > 1 ? '$attrDescription (Qty: $qty)' : attrDescription,
          extraCost: extraCost,
          quantity: qty,
          lineTotal: lineTotal,
        ),
      );
    }
  } else {
    // No attributes, use base price and total quantity
    subtotal = product.price * totalQuantity;
  }

  return PricingData(
    subtotal: subtotal,
    attributeDetails: attributeDetails,
  );
}
