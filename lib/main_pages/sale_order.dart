import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:typed_data';

import '../Login/login.dart';

// Constants


// Models
class Product {
  final String id;
  final String name;
  final double price;
  final int vanInventory;
  final String? imageUrl;

  Product({
    required this.id,
    required this.name,
    required this.price,
    required this.vanInventory,
    this.imageUrl,
  });
}

class OrderItem {
  final Product product;
  int quantity;

  OrderItem({
    required this.product,
    required this.quantity,
  });

  double get subtotal => product.price * quantity;
}

class SalesOrder {
  final String id;
  final List<OrderItem> items;
  final DateTime creationDate;
  String status;
  String? paymentStatus;
  bool validated;
  String? invoiceNumber;

  SalesOrder({
    required this.id,
    required this.items,
    required this.creationDate,
    this.status = 'Draft',
    this.paymentStatus,
    this.validated = false,
    this.invoiceNumber,
  });

  double get total => items.fold<double>(
        0,
        (sum, item) => sum + (item.product.price * item.quantity),
      );
}

// Main app
class SalesOrderApp extends StatelessWidget {
  const SalesOrderApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sales Order Workflow',
      theme: ThemeData(
        primaryColor: primaryColor,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryColor,
          primary: primaryColor,
          secondary: primaryLightColor,
        ),
        scaffoldBackgroundColor: Colors.grey[100],
      ),
      home: const SalesOrderWorkflow(),
    );
  }
}

// Workflow container
class SalesOrderWorkflow extends StatefulWidget {
  const SalesOrderWorkflow({Key? key}) : super(key: key);

  @override
  _SalesOrderWorkflowState createState() => _SalesOrderWorkflowState();
}

class _SalesOrderWorkflowState extends State<SalesOrderWorkflow> {
  int _currentStep = 0;
  List<Product> products = [];
  List<OrderItem> orderItems = [];
  String? customerId;
  String? customerName;
  SalesOrder? salesOrder;

  final List<String> steps = [
    'Select Products',
    'Confirm Order',
    'Payment Process',
    'Validate Transaction',
    'Generate Invoice'
  ];

  @override
  void initState() {
    super.initState();
    loadProducts();
  }

  void loadProducts() {
    final mockProducts = [
      Product(id: '1', name: 'Product A', price: 10.0, vanInventory: 50),
      Product(id: '2', name: 'Product B', price: 15.0, vanInventory: 30),
      Product(id: '3', name: 'Product C', price: 9.0, vanInventory: 26),
      Product(id: '4', name: 'Product D', price: 12.0, vanInventory: 41),
      Product(id: '5', name: 'Product E', price: 20.0, vanInventory: 10),
    ];
    setState(() {
      products = mockProducts;
    });
  }

  void addToOrder(Product product, int quantity) {
    if (quantity > product.vanInventory) {
      _showErrorSnackBar('Cannot exceed van inventory');
      return;
    }

    final updatedOrder = List<OrderItem>.from(orderItems);
    final existingItemIndex =
        updatedOrder.indexWhere((item) => item.product.id == product.id);

    if (existingItemIndex >= 0) {
      final currentQuantity = updatedOrder[existingItemIndex].quantity;
      if (currentQuantity + quantity > product.vanInventory) {
        _showErrorSnackBar('Cannot exceed van inventory');
        return;
      }
      updatedOrder[existingItemIndex].quantity += quantity;
    } else {
      updatedOrder.add(OrderItem(product: product, quantity: quantity));
    }

    setState(() {
      orderItems = updatedOrder;
    });
  }

  void removeItem(String productId) {
    setState(() {
      orderItems =
          orderItems.where((item) => item.product.id != productId).toList();
    });
  }

  void clearOrder() {
    setState(() {
      orderItems = [];
    });
  }

  void confirmOrder() {
    if (orderItems.isEmpty) {
      _showErrorSnackBar('Please add at least one product to the order');
      return;
    }

    setState(() {
      salesOrder = SalesOrder(
        id: 'SO${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
        items: List.from(orderItems),
        creationDate: DateTime.now(),
      );
      _currentStep = 1;
    });
  }

  void recordPayment(String status) {
    setState(() {
      salesOrder!.paymentStatus = status;
      _currentStep = 3;
    });
  }

  void validateOrder() {
    setState(() {
      salesOrder!.validated = true;
      salesOrder!.status = 'Confirmed';
      _currentStep = 4;
    });
  }

  void generateInvoice() {
    setState(() {
      salesOrder!.invoiceNumber =
          'INV${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
      _currentStep = 4;
    });
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: primaryDarkColor,
      ),
    );
  }

  void goToStep(int step) {
    // Only allow going back or to completed steps
    if (step <= _currentStep) {
      setState(() {
        _currentStep = step;
      });
    }
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return SelectProductsStep(
          products: products,
          orderItems: orderItems,
          onAddToOrder: addToOrder,
          onRemoveItem: removeItem,
          onClearOrder: clearOrder,
          onNext: confirmOrder,
        );
      case 1:
        return ConfirmOrderStep(
          salesOrder: salesOrder!,
          onNext: () => setState(() => _currentStep = 2),
          onBack: () => setState(() => _currentStep = 0),
        );
      case 2:
        return PaymentStep(
          salesOrder: salesOrder!,
          onRecordPayment: recordPayment,
          onBack: () => setState(() => _currentStep = 1),
        );
      case 3:
        return ValidateOrderStep(
          salesOrder: salesOrder!,
          onValidate: validateOrder,
          onBack: () => setState(() => _currentStep = 2),
        );
      case 4:
        return InvoiceStep(
          salesOrder: salesOrder!,
          onGenerateInvoice: generateInvoice,
          onBack: () => setState(() => _currentStep = 3),
          onFinish: () {
            // Reset workflow or navigate to a new order
            setState(() {
              _currentStep = 0;
              orderItems = [];
              salesOrder = null;
            });
          },
        );
      default:
        return Container();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Sales Order',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        backgroundColor: primaryColor,
        elevation: 0,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                salesOrder != null
                    ? Text(
                        'Order: ${salesOrder!.id}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: primaryDarkColor,
                        ),
                      )
                    : const Text(
                        'New Order',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: primaryDarkColor,
                        ),
                      ),
                const SizedBox(height: 16),
                _buildStepper(),
              ],
            ),
          ),
          Expanded(
            child: _buildStepContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildStepper() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(steps.length, (index) {
        return Expanded(
          child: GestureDetector(
            onTap: () => goToStep(index),
            child: Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color:
                        _currentStep >= index ? primaryColor : Colors.grey[300],
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        color: _currentStep >= index
                            ? Colors.white
                            : Colors.grey[600],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  steps[index],
                  style: TextStyle(
                    fontSize: 12,
                    color: _currentStep >= index
                        ? primaryDarkColor
                        : Colors.grey[600],
                    fontWeight: _currentStep == index
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

class SelectProductsStep extends StatelessWidget {
  final List<Product> products;
  final List<OrderItem> orderItems;
  final Function(Product, int) onAddToOrder;
  final Function(String) onRemoveItem;
  final VoidCallback onClearOrder;
  final VoidCallback onNext;

  const SelectProductsStep({
    Key? key,
    required this.products,
    required this.orderItems,
    required this.onAddToOrder,
    required this.onRemoveItem,
    required this.onClearOrder,
    required this.onNext,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Product list
        Expanded(
          child: ListView.builder(
            itemCount: products.length,
            itemBuilder: (context, index) {
              final product = products[index];
              return Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2),
                child: ProductCard(
                  product: product,
                  onAddToOrder: (quantity) {
                    onAddToOrder(product, quantity);
                  },
                ),
              );
            },
          ),
        ),
        // Order summary
        SizedBox(
          height: 220,
          child: OrderSummary(
            order: orderItems,
            onClearOrder: onClearOrder,
            onRemoveItem: onRemoveItem,
          ),
        ),
        // Bottom button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: ElevatedButton(
            onPressed: orderItems.isNotEmpty ? onNext : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Confirm Selection'),
                SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward,
                  color: Colors.white,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class ProductCard extends StatelessWidget {
  final Product product;
  final Function(int) onAddToOrder;

  const ProductCard({
    Key? key,
    required this.product,
    required this.onAddToOrder,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final quantityController = TextEditingController();

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Product image placeholder
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Icon(Icons.inventory),
            ),
            const SizedBox(width: 12),
            // Product details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text('\$${product.price}'),
                  Text('In stock: ${product.vanInventory}'),
                ],
              ),
            ),
            // Quantity input
            SizedBox(
              width: 60,
              child: TextField(
                controller: quantityController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Qty',
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Add but
            ElevatedButton(
              onPressed: () {
                final quantity = int.tryParse(quantityController.text) ?? 0;
                if (quantity > 0) {
                  onAddToOrder(quantity);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                ),
              ),
              child: const Text('Add'),
            )
          ],
        ),
      ),
    );
  }
}

class OrderSummary extends StatelessWidget {
  final List<OrderItem> order;
  final VoidCallback onClearOrder;
  final Function(String) onRemoveItem;

  const OrderSummary({
    Key? key,
    required this.order,
    required this.onClearOrder,
    required this.onRemoveItem,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final total = order.fold<double>(
      0,
      (sum, item) => sum + (item.product.price * item.quantity),
    );

    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with clear button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Order Summary',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (order.isNotEmpty)
                  TextButton(
                    onPressed: onClearOrder,
                    child: const Text('Clear All'),
                  ),
              ],
            ),
            const Divider(),
            // Order items list
            Expanded(
              child: order.isEmpty
                  ? const Center(child: Text('No items in order'))
                  : ListView.builder(
                      itemCount: order.length,
                      itemBuilder: (context, index) {
                        final item = order[index];
                        return Row(
                          children: [
                            Expanded(
                              child: Text(item.product.name),
                            ),
                            Text('${item.quantity} x \$${item.product.price}'),
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline),
                              onPressed: () => onRemoveItem(item.product.id),
                              iconSize: 20,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        );
                      },
                    ),
            ),
            // Total
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  '\$${total.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ConfirmOrderStep extends StatelessWidget {
  final SalesOrder salesOrder;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const ConfirmOrderStep({
    Key? key,
    required this.salesOrder,
    required this.onNext,
    required this.onBack,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Confirm Order Details',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: primaryDarkColor,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Order Reference: ${salesOrder.id}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: primaryDarkColor,
                      ),
                    ),
                    Text(
                      'Date: ${salesOrder.creationDate.day}/${salesOrder.creationDate.month}/${salesOrder.creationDate.year}',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Order Lines',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: primaryDarkColor,
                  ),
                ),
                const Divider(),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: salesOrder.items.length,
                  itemBuilder: (context, index) {
                    final item = salesOrder.items[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            flex: 3,
                            child: Text(
                              item.product.name,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w500),
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: Text(
                              '${item.quantity}',
                              textAlign: TextAlign.right,
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: Text(
                              '\$${item.product.price.toStringAsFixed(2)}',
                              textAlign: TextAlign.right,
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: Text(
                              '\$${item.subtotal.toStringAsFixed(2)}',
                              textAlign: TextAlign.right,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const Text(
                      'Total: ',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      '\$${salesOrder.total.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: primaryDarkColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: onBack,
                style: TextButton.styleFrom(
                  foregroundColor: primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.arrow_back),
                    SizedBox(width: 8),
                    Text('Back'),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: onNext,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: const Row(
                  children: [
                    Text('Next'),
                    SizedBox(width: 8),
                    Icon(
                      Icons.arrow_forward,
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class PaymentStep extends StatefulWidget {
  final SalesOrder salesOrder;
  final Function(String) onRecordPayment;
  final VoidCallback onBack;

  const PaymentStep({
    Key? key,
    required this.salesOrder,
    required this.onRecordPayment,
    required this.onBack,
  }) : super(key: key);

  @override
  _PaymentStepState createState() => _PaymentStepState();
}

class _PaymentStepState extends State<PaymentStep> {
  String selectedPaymentOption = 'paid';
  String paymentMethod = 'cash';
  final TextEditingController _notesController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Record Payment',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: primaryDarkColor,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Order: ${widget.salesOrder.id}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: primaryDarkColor,
                      ),
                    ),
                    Text(
                      'Amount: \$${widget.salesOrder.total.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: primaryDarkColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Payment Status',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: primaryDarkColor,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile<String>(
                        title: const Text('Paid'),
                        value: 'paid',
                        groupValue: selectedPaymentOption,
                        activeColor: primaryColor,
                        onChanged: (value) {
                          setState(() {
                            selectedPaymentOption = value!;
                          });
                        },
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<String>(
                        title: const Text('To Invoice'),
                        value: 'to_invoice',
                        groupValue: selectedPaymentOption,
                        activeColor: primaryColor,
                        onChanged: (value) {
                          setState(() {
                            selectedPaymentOption = value!;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                if (selectedPaymentOption == 'paid') ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Payment Method',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: primaryDarkColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: RadioListTile<String>(
                          title: const Text('Cash'),
                          value: 'cash',
                          groupValue: paymentMethod,
                          activeColor: primaryColor,
                          onChanged: (value) {
                            setState(() {
                              paymentMethod = value!;
                            });
                          },
                        ),
                      ),
                      Expanded(
                        child: RadioListTile<String>(
                          title: const Text('Card'),
                          value: 'card',
                          groupValue: paymentMethod,
                          activeColor: primaryColor,
                          onChanged: (value) {
                            setState(() {
                              paymentMethod = value!;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                const Text(
                  'Notes',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: primaryDarkColor,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _notesController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Add payment notes',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: primaryColor),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: widget.onBack,
                style: TextButton.styleFrom(
                  foregroundColor: primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.arrow_back),
                    SizedBox(width: 8),
                    Text('Back'),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  widget.onRecordPayment(selectedPaymentOption);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: const Row(
                  children: [
                    Text('Record Payment'),
                    SizedBox(width: 8),
                    Icon(
                      Icons.arrow_forward,
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ValidateOrderStep extends StatelessWidget {
  final SalesOrder salesOrder;
  final VoidCallback onValidate;
  final VoidCallback onBack;

  const ValidateOrderStep({
    Key? key,
    required this.salesOrder,
    required this.onValidate,
    required this.onBack,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Validate Order',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: primaryDarkColor,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Order: ${salesOrder.id}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: primaryDarkColor,
                      ),
                    ),
                    Text(
                      'Status: ${salesOrder.status}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange[700],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Payment Status: ${salesOrder.paymentStatus ?? 'Not Set'}',
                  style: TextStyle(
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Validation Summary',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: primaryDarkColor,
                  ),
                ),
                const SizedBox(height: 8),
                _buildValidationItem(
                  'Order Lines',
                  salesOrder.items.isNotEmpty ? 'Valid' : 'No items',
                  salesOrder.items.isNotEmpty,
                ),
                _buildValidationItem(
                  'Payment Information',
                  salesOrder.paymentStatus != null ? 'Recorded' : 'Missing',
                  salesOrder.paymentStatus != null,
                ),
                _buildValidationItem(
                  'Total Amount',
                  '\$${salesOrder.total.toStringAsFixed(2)}',
                  true,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Validation confirms this order is ready to be processed. This will:',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                _buildValidationStep('Update inventory levels'),
                _buildValidationStep('Change order status to "Confirmed"'),
                _buildValidationStep('Allow invoice generation'),
              ],
            ),
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: onBack,
                style: TextButton.styleFrom(
                  foregroundColor: primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.arrow_back),
                    SizedBox(width: 8),
                    Text('Back'),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: onValidate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: const Row(
                  children: [
                    Text('Validate Order'),
                    SizedBox(width: 8),
                    Icon(
                      Icons.check_circle_outline,
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildValidationItem(String label, String value, bool isValid) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[700],
            ),
          ),
          Row(
            children: [
              Text(
                value,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: isValid ? Colors.green[700] : Colors.red[700],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                isValid ? Icons.check_circle : Icons.error,
                color: isValid ? Colors.green[700] : Colors.red[700],
                size: 16,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildValidationStep(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.arrow_right, color: primaryDarkColor),
          const SizedBox(width: 8),
          Text(text),
        ],
      ),
    );
  }
}

class InvoiceStep extends StatelessWidget {
  final SalesOrder salesOrder;
  final VoidCallback onGenerateInvoice;
  final VoidCallback onBack;
  final VoidCallback onFinish;

  const InvoiceStep({
    Key? key,
    required this.salesOrder,
    required this.onGenerateInvoice,
    required this.onBack,
    required this.onFinish,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Generate Invoice',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: primaryDarkColor,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Order: ${salesOrder.id}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: primaryDarkColor,
                      ),
                    ),
                    Text(
                      'Status: ${salesOrder.status}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green[700],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Payment Status: ${salesOrder.paymentStatus ?? 'Not Set'}',
                  style: TextStyle(
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Invoice Details',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: primaryDarkColor,
                  ),
                ),
                const SizedBox(height: 8),
                if (salesOrder.invoiceNumber != null) ...[
                  _buildInvoiceDetail(
                      'Invoice Number', salesOrder.invoiceNumber!),
                  _buildInvoiceDetail('Date',
                      '${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}'),
                  _buildInvoiceDetail(
                      'Amount', '\$${salesOrder.total.toStringAsFixed(2)}'),
                  _buildInvoiceDetail('Status', 'Generated'),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          // Implementation for viewing invoice
                          _viewInvoicePdf(context);
                        },
                        icon: const Icon(
                          Icons.visibility,
                          color: Colors.white,
                        ),
                        label: const Text(
                          'View Invoice',
                          style: TextStyle(color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton.icon(
                        onPressed: () {
                          // Implementation for printing invoice
                          _printInvoice(context);
                        },
                        icon: const Icon(Icons.print, color: Colors.white),
                        label: const Text(
                          'Print Invoice',
                          style: TextStyle(color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Text(
                        'No invoice has been generated yet.',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: onBack,
                style: TextButton.styleFrom(
                  foregroundColor: primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.arrow_back),
                    SizedBox(width: 8),
                    Text('Back'),
                  ],
                ),
              ),
              if (salesOrder.invoiceNumber == null)
                ElevatedButton(
                  onPressed: onGenerateInvoice,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                  ),
                  child: const Row(
                    children: [
                      Text('Generate Invoice'),
                      SizedBox(width: 8),
                      Icon(
                        Icons.receipt,
                        color: Colors.white,
                      ),
                    ],
                  ),
                )
              else
                ElevatedButton(
                  onPressed: onFinish,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                  ),
                  child: const Row(
                    children: [
                      Text(
                        'Complete Order',
                        style: TextStyle(color: Colors.white),
                      ),
                      SizedBox(width: 8),
                      Icon(
                        Icons.check_circle,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceDetail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[700],
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _viewInvoicePdf(BuildContext context) {
    // Create a PDF display dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Invoice Preview'),
        content: SizedBox(
          width: double.maxFinite,
          height: MediaQuery.of(context).size.height * 0.6,
          child: const Center(
            child: Text('PDF preview would be displayed here'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _printInvoice(BuildContext context) {
    // In a real app, this would generate a PDF and print it
    // For now, we'll just show a dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Print Invoice'),
        content: const Text('Sending invoice to printer...'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

// PDF Generation Helper Class
class InvoiceGenerator {
  static Future<Uint8List> generateInvoice(SalesOrder order) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'INVOICE',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Invoice #: ${order.invoiceNumber}'),
                      pw.Text(
                          'Date: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}'),
                      pw.Text('Order Ref: ${order.id}'),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Divider(),
              pw.SizedBox(height: 10),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Bill To:',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text(
                    'Ship To:',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Customer Name'),
                      pw.Text('Address Line 1'),
                      pw.Text('City, State, ZIP'),
                      pw.Text('Phone: XXX-XXX-XXXX'),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Customer Name'),
                      pw.Text('Address Line 1'),
                      pw.Text('City, State, ZIP'),
                      pw.Text('Phone: XXX-XXX-XXXX'),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Table(
                border: pw.TableBorder.all(),
                columnWidths: {
                  0: const pw.FlexColumnWidth(1),
                  1: const pw.FlexColumnWidth(3),
                  2: const pw.FlexColumnWidth(1),
                  3: const pw.FlexColumnWidth(1),
                  4: const pw.FlexColumnWidth(1),
                },
                children: [
                  pw.TableRow(
                    decoration:
                        const pw.BoxDecoration(color: PdfColors.grey300),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(
                          'Item #',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(
                          'Description',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(
                          'Quantity',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(
                          'Unit Price',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(
                          'Amount',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  ...order.items.asMap().entries.map((item) {
                    return pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(item.value.product.id),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(item.value.product.name),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text('${item.value.quantity}'),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(
                              '\$${item.value.product.price.toStringAsFixed(2)}'),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(
                              '\$${(item.value.product.price * item.value.quantity).toStringAsFixed(2)}'),
                        ),
                      ],
                    );
                  }).toList(),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Container(
                alignment: pw.Alignment.centerRight,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Row(
                      mainAxisSize: pw.MainAxisSize.min,
                      children: [
                        pw.Text(
                          'Subtotal: ',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                        pw.Text('\$${order.total.toStringAsFixed(2)}'),
                      ],
                    ),
                    pw.Row(
                      mainAxisSize: pw.MainAxisSize.min,
                      children: [
                        pw.Text(
                          'Tax: ',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                        pw.Text('\$0.00'),
                      ],
                    ),
                    pw.Divider(thickness: 2),
                    pw.Row(
                      mainAxisSize: pw.MainAxisSize.min,
                      children: [
                        pw.Text(
                          'Total: ',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                        pw.Text(
                          '\$${order.total.toStringAsFixed(2)}',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Divider(),
              pw.SizedBox(height: 10),
              pw.Text(
                'Payment Status: ${order.paymentStatus == 'paid' ? 'Paid' : 'To be invoiced'}',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: order.paymentStatus == 'paid'
                      ? PdfColors.green
                      : PdfColors.black,
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text('Thank you for your business!'),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }
}
