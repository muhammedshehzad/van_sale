import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:developer';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main_pages/order_picking_page.dart';
import '../secondary_pages/summary_page.dart';
import '../widgets/customer_dialog.dart';
import '../widgets/page_transition.dart';
import 'cyllo_session_model.dart';
import '../secondary_pages/add_products_page.dart';
import 'sales_order_provider.dart';
import 'dart:developer' as developer;

const Color primaryColor = Color(0xFFA12424);
final Color neutralGrey = const Color(0xFF757575);
final Color backgroundColor = const Color(0xFFF5F5F5);
final Color textColor = const Color(0xFF212121);
const Color primaryLightColor = Color(0xFFD15656);
const Color primaryDarkColor = Color(0xFF6D1717);
const double kBorderRadius = 8.0;

class OrderPickingProvider with ChangeNotifier {
  List<ProductItem> _products = [];
  String? _currentOrderId;
  static const String _orderPrefix = 'S';
  int _lastSequenceNumber = 0;

  String? get currentOrderId => _currentOrderId;

  List<ProductItem> get products => _products;
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  void resetOrderId() {
    _currentOrderId = null;
    notifyListeners();
  }

  final TextEditingController shopNameController = TextEditingController();
  final TextEditingController shopLocationController = TextEditingController();
  final TextEditingController contactPersonController = TextEditingController();
  final TextEditingController contactNumberController = TextEditingController();
  final TextEditingController notesController = TextEditingController();

  DateTime _deliveryDate = DateTime.now().add(const Duration(days: 1));
  String _priority = 'Normal';
  final List<String> _priorityLevels = ['Low', 'Normal', 'High', 'Urgent'];
  String _deliverySlot = 'Morning (9AM-12PM)';
  final List<String> _deliverySlots = [
    'Morning (9AM-12PM)',
    'Afternoon (12PM-4PM)',
    'Evening (4PM-8PM)'
  ];

  bool _isProductListVisible = false;
  List<Product> _availableProducts = [];
  List<Customer> _customers = [];
  bool _isLoadingCustomers = false;

  DateTime get deliveryDate => _deliveryDate;

  String get priority => _priority;

  List<String> get priorityLevels => _priorityLevels;

  String get deliverySlot => _deliverySlot;

  List<String> get deliverySlots => _deliverySlots;

  bool get isProductListVisible => _isProductListVisible;

  List<Product> get availableProducts => _availableProducts;

  List<Customer> get customers => _customers;

  bool get isLoadingCustomers => _isLoadingCustomers;

  void addCustomer(Customer customer) {
    _customers.add(customer);
    _customers.sort((a, b) => a.name.compareTo(b.name));
    notifyListeners();
  }

  void showCreateCustomerDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => CreateCustomerDialog(
        onCustomerCreated: (Customer newCustomer) {
          addCustomer(newCustomer);

          shopNameController.text = newCustomer.name;
          shopLocationController.text = newCustomer.city ?? '';
          contactPersonController.text = newCustomer.name;
          contactNumberController.text = newCustomer.phone ?? '';

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Customer created successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        },
      ),
    );
  }

  void addNewProduct(BuildContext context) async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final nameController = TextEditingController();
        final quantityController = TextEditingController();
        final salePriceController = TextEditingController();
        final costController = TextEditingController();
        final barcodeController = TextEditingController();
        String selectedUnit = 'Pieces';
        String selectedCategory = 'General';
        String selectedProductType = 'product';

        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(kBorderRadius),
          ),
          elevation: 4,
          backgroundColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Add New Product',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: primaryDarkColor,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.grey),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildDropdownField(
                    label: 'Product Type',
                    value: selectedProductType,
                    items: ['product', 'consu', 'service'],
                    onChanged: (value) => selectedProductType = value,
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: nameController,
                    label: 'Product Name',
                    validator: (value) => value == null || value.isEmpty
                        ? 'Please enter product name'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  _buildDropdownField(
                    label: 'Category',
                    value: selectedCategory,
                    items: ProductItem().categories,
                    onChanged: (value) => selectedCategory = value,
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: quantityController,
                    label: 'Initial Quantity',
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty)
                        return 'Please enter quantity';
                      if (int.tryParse(value) == null || int.parse(value) < 0) {
                        return 'Please enter a valid quantity';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildDropdownField(
                    label: 'Unit of Measure',
                    value: selectedUnit,
                    items: ProductItem().units,
                    onChanged: (value) => selectedUnit = value,
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: costController,
                    label: 'Product Cost',
                    keyboardType:
                        TextInputType.numberWithOptions(decimal: true),
                    validator: (value) {
                      if (value == null || value.isEmpty)
                        return 'Please enter cost price';
                      if (double.tryParse(value) == null ||
                          double.parse(value) < 0) {
                        return 'Please enter a valid cost price';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: salePriceController,
                    label: 'Sale Price',
                    keyboardType:
                        TextInputType.numberWithOptions(decimal: true),
                    validator: (value) {
                      if (value == null || value.isEmpty)
                        return 'Please enter sale price';
                      if (double.tryParse(value) == null ||
                          double.parse(value) < 0) {
                        return 'Please enter a valid sale price';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.grey[600],
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(kBorderRadius),
                          ),
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(kBorderRadius),
                          ),
                          elevation: 2,
                        ),
                        onPressed: () async {
                          if (nameController.text.isNotEmpty &&
                              quantityController.text.isNotEmpty &&
                              int.tryParse(quantityController.text) != null &&
                              int.parse(quantityController.text) >= 0 &&
                              salePriceController.text.isNotEmpty &&
                              double.tryParse(salePriceController.text) !=
                                  null &&
                              double.parse(salePriceController.text) >= 0 &&
                              costController.text.isNotEmpty &&
                              double.tryParse(costController.text) != null &&
                              double.parse(costController.text) >= 0) {
                            final newProduct = ProductItem();
                            newProduct.nameController.text =
                                nameController.text;
                            newProduct.quantityController.text =
                                quantityController.text;
                            newProduct.salePriceController.text =
                                salePriceController.text;
                            newProduct.costController.text =
                                costController.text;
                            newProduct.barcodeController.text =
                                barcodeController.text;
                            newProduct.selectedUnit = selectedUnit;
                            newProduct.selectedCategory = selectedCategory;
                            newProduct.selectedProductType =
                                selectedProductType;

                            try {
                              final client =
                                  await SessionManager.getActiveClient();
                              if (client == null) {
                                throw Exception(
                                    'No active Odoo session found. Please log in again.');
                              }

                              final productData = {
                                'name': nameController.text,
                                'default_code':
                                    'PROD-${DateTime.now().millisecondsSinceEpoch}',
                                'list_price':
                                    double.parse(salePriceController.text),
                                'standard_price':
                                    double.parse(costController.text),
                                'barcode': barcodeController.text.isNotEmpty
                                    ? barcodeController.text
                                    : false,
                                'type': selectedProductType,
                                'uom_id': _mapUnitToOdooId(selectedUnit),
                                'uom_po_id': _mapUnitToOdooId(selectedUnit),
                                'categ_id':
                                    _mapCategoryToOdooId(selectedCategory),
                              };

                              final productId = await client.callKw({
                                'model': 'product.product',
                                'method': 'create',
                                'args': [productData],
                                'kwargs': {},
                              });

                              if (int.parse(quantityController.text) > 0) {
                                await client.callKw({
                                  'model': 'stock.quant',
                                  'method': 'create',
                                  'args': [
                                    {
                                      'product_id': productId,
                                      'location_id': 8,
                                      'quantity':
                                          int.parse(quantityController.text)
                                              .toDouble(),
                                    }
                                  ],
                                  'kwargs': {},
                                });
                              }

                              newProduct.odooId = productId;
                              _products.add(newProduct);
                              notifyListeners();

                              final salesProvider =
                                  Provider.of<SalesOrderProvider>(context,
                                      listen: false);
                              try {
                                await salesProvider.loadProducts();
                                _availableProducts = salesProvider.products;
                                notifyListeners();
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text(
                                          'Failed to refresh products: $e'),
                                      backgroundColor: Colors.red),
                                );
                              }

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      'Product added successfully to Odoo (ID: $productId)'),
                                  backgroundColor: Colors.green,
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content:
                                      Text('Failed to add product to Odoo: $e'),
                                  backgroundColor: Colors.red,
                                  duration: const Duration(seconds: 3),
                                ),
                              );
                            }

                            Navigator.of(context).pop();
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text(
                                    'Please fill in all required fields correctly'),
                                backgroundColor: primaryColor,
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(kBorderRadius),
                                ),
                                behavior: SnackBarBehavior.floating,
                                margin: const EdgeInsets.all(16),
                              ),
                            );
                          }
                        },
                        child: const Text(
                          'Add Product',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  int _mapUnitToOdooId(String unit) {
    switch (unit) {
      case 'Pieces':
        return 1;
      case 'Kilograms':
        return 2;

      default:
        return 1;
    }
  }

  int _mapCategoryToOdooId(String category) {
    switch (category) {
      case 'General':
        return 1;
      case 'Electronics':
        return 2;

      default:
        return 1;
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey[600]),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(kBorderRadius),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(kBorderRadius),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(kBorderRadius),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey[50],
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      style: const TextStyle(fontSize: 14, color: Colors.black87),
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String value,
    required List<String> items,
    required Function(String) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey[600]),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(kBorderRadius),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(kBorderRadius),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(kBorderRadius),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey[50],
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      items: items.map((String item) {
        return DropdownMenuItem<String>(
          value: item,
          child: Text(item,
              style: const TextStyle(fontSize: 14, color: Colors.black87)),
        );
      }).toList(),
      onChanged: (String? newValue) {
        if (newValue != null) onChanged(newValue);
      },
      dropdownColor: Colors.white,
      icon: const Icon(Icons.arrow_drop_down, color: primaryDarkColor),
    );
  }

  Future<void> initialize(BuildContext context) async {
    final provider = Provider.of<SalesOrderProvider>(context, listen: false);
    await provider.loadProducts();
    _availableProducts = provider.products;
    print('Initialized with ${_availableProducts.length} products');
    await loadCustomers();
    resetOrderId();
    notifyListeners();
  }

  void disposeControllers() {
    shopNameController.dispose();
    shopLocationController.dispose();
    contactPersonController.dispose();
    contactNumberController.dispose();
    notesController.dispose();
  }

  Future<void> _loadLastSequenceNumber() async {
    final prefs = await SharedPreferences.getInstance();
    _lastSequenceNumber = prefs.getInt('last_order_sequence') ?? 0;
  }

  Future<void> _saveLastSequenceNumber() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('last_order_sequence', _lastSequenceNumber);
  }

  Future<String> generateOrderId() async {
    final client = await SessionManager.getActiveClient();
    if (client == null) {
      throw Exception('No active Odoo session found. Please log in again.');
    }

    await _loadLastSequenceNumber();
    String newOrderId;
    int maxAttempts = 100;
    int attempt = 0;

    do {
      if (attempt >= maxAttempts) {
        print('Unable to generate unique order ID after $maxAttempts attempts');
      }

      _lastSequenceNumber++;
      final sequencePart = _lastSequenceNumber.toString().padLeft(5, '0');
      newOrderId = '$_orderPrefix$sequencePart';

      // developer.log('Generated order ID attempt #$attempt: $newOrderId');

      final exists = await _checkOrderIdExists(client, newOrderId);
      // developer.log('Order ID $newOrderId exists in Odoo: $exists');

      if (exists) {
        attempt++;
        continue;
      }

      break;
    } while (true);

    _currentOrderId = newOrderId;
    await _saveLastSequenceNumber();
    // developer.log('Final generated order ID: $_currentOrderId');
    notifyListeners();
    return _currentOrderId!;
  }

  Future<bool> _checkOrderIdExists(dynamic client, String orderId) async {
    try {
      // developer.log('Checking if order ID exists: $orderId');

      // Try the standard domain format first
      final domain = [
        ['name', '=', orderId]
      ];
      // developer.log('Attempting with domain: $domain');

      final result = await client.callKw({
        'model': 'sale.order',
        'method': 'search_count',
        'args': [domain],
        'kwargs': {},
      });

      // developer.log(
      //     'Odoo search_count result for $orderId: $result (type: ${result.runtimeType})');

      final count =
          (result is int) ? result : int.tryParse(result.toString()) ?? 0;
      return count > 0;
    } catch (e) {
      // developer.log('Error with search_count for $orderId: $e', error: e);

      try {
        developer.log('Falling back to search method for $orderId');
        final searchResult = await client.callKw({
          'model': 'sale.order',
          'method': 'search',
          'args': [
            [
              ['name', '=', orderId]
            ]
          ],
          'kwargs': {},
        });

        // developer.log(
        //     'Odoo search result for $orderId: $searchResult (type: ${searchResult.runtimeType})');
        return searchResult is List && searchResult.isNotEmpty;
      } catch (searchError) {
        developer.log('Fallback search failed for $orderId: $searchError',
            error: searchError);
        throw Exception('Failed to verify order ID uniqueness: $searchError');
      }
    }
  }

  void showProductSelectionPage(BuildContext context) {
    final salesProvider =
        Provider.of<SalesOrderProvider>(context, listen: false);
    salesProvider.loadProducts().then((_) {
      _availableProducts = salesProvider.products;
      print('Available products count: ${_availableProducts.length}');
      if (_availableProducts.isEmpty) {
        print('Warning: No products retrieved from server');
      }

      Navigator.pushAndRemoveUntil(
        context,
        SlidingPageTransitionRL(
          page: ProductSelectionPage(
            availableProducts: availableProducts,
            onAddProduct: (product, quantity) {
              addProductFromList(product, quantity,
                  salesProvider: salesProvider);
            },
          ),
        ),
        (Route<dynamic> route) => false,
      );
    }).catchError((e) {
      print('Error loading products for page: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to load products. Please try again.'),
          backgroundColor: Colors.red,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(kBorderRadius),
          ),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
        ),
      );
    });
  }

  Future<void> loadCustomers() async {
    _isLoadingCustomers = true;
    notifyListeners();

    try {
      final client = await SessionManager.getActiveClient();
      if (client != null) {
        final result = await client.callKw({
          'model': 'res.partner',
          'method': 'search_read',
          'args': [],
          'kwargs': {
            'fields': [
              'id',
              'name',
              'phone',
              'email',
              'city',
              'company_id',
            ],
          },
        });

        final List<Customer> fetchedCustomers =
            (result as List).map((customerData) {
          return Customer(
            id: customerData['id'].toString(),
            name: customerData['name'] ?? 'Unnamed Customer',
            phone:
                customerData['phone'] is String ? customerData['phone'] : null,
            email:
                customerData['email'] is String ? customerData['email'] : null,
            city: customerData['city'] is String ? customerData['city'] : null,
            companyId: customerData['company_id'] ?? false,
          );
        }).toList();

        fetchedCustomers.sort((a, b) => a.name.compareTo(b.name));
        _customers = fetchedCustomers;

        log("Successfully fetched ${fetchedCustomers.length} customers");
        if (_customers.isEmpty) {
          log("No customers found");
        } else {
          final firstCustomer = _customers[0];
          log("First customer details:");
          log("Name: ${firstCustomer.name}");
          log("Phone: ${firstCustomer.phone ?? 'N/A'}");
          log("Email: ${firstCustomer.email ?? 'N/A'}");
          log("City: ${firstCustomer.city ?? 'N/A'}");
          log("Company ID: ${firstCustomer.companyId}");
        }
      }
    } catch (e) {
      log("Error fetching customers: $e");
    } finally {
      _isLoadingCustomers = false;
      notifyListeners();
    }
  }

  void addProductFromList(Product product, int quantity,
      {required SalesOrderProvider salesProvider}) {
    final newProduct = ProductItem();
    newProduct.nameController.text = product.name;
    newProduct.quantityController.text = quantity.toString();
    newProduct.selectedCategory =
        product.categId is List && product.categId.length == 2
            ? product.categId[1].toString()
            : 'General';
    newProduct.stockQuantity = product.vanInventory;
    newProduct.imageUrl = product.imageUrl;
    _products.add(newProduct);
    _isProductListVisible = false;

    if (product.vanInventory > 0) {
      salesProvider.updateInventory(product.id, quantity);
    }
    notifyListeners();
  }

  void removeProduct(int index) {
    _products.removeAt(index);
    notifyListeners();
  }

  void submitForm(BuildContext context) async {
    if (formKey.currentState!.validate() && _products.isNotEmpty) {
      final orderId = _currentOrderId ?? await generateOrderId();

      Map<String, dynamic> formData = {
        'order_id': orderId,
        'shop_info': {
          'name': shopNameController.text,
          'location': shopLocationController.text,
          'contact_person': contactPersonController.text,
          'contact_number': contactNumberController.text,
        },
        'delivery_info': {
          'date': DateFormat('yyyy-MM-dd').format(_deliveryDate),
          'priority': _priority,
          'slot': _deliverySlot,
        },
        'products': _products
            .map((product) => {
                  'name': product.nameController.text,
                  'quantity': int.parse(product.quantityController.text),
                  'unit': product.selectedUnit,
                  'category': product.selectedCategory,
                  'urgency': product.selectedUrgency,
                  'notes': product.notesController.text,
                  'stock_quantity': product.stockQuantity,
                })
            .toList(),
        'additional_notes': notesController.text,
      };

      print('Generated Order ID: $orderId');
      print(formData);

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => FormSummaryPage(formData: formData),
        ),
      );
    } else if (_products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          padding: const EdgeInsets.all(16),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          margin: const EdgeInsets.all(10),
          duration: const Duration(seconds: 2),
          content: const Text('Please add at least one product'),
          backgroundColor: primaryColor,
        ),
      );
    }
  }

  Future<void> selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _deliveryDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: primaryColor,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _deliveryDate) {
      _deliveryDate = picked;
      notifyListeners();
    }
  }

  void toggleProductListVisibility(BuildContext context) {
    final provider = Provider.of<SalesOrderProvider>(context, listen: false);
    provider.loadProducts().then((_) {
      _availableProducts = provider.products;
      _isProductListVisible = !_isProductListVisible;
      notifyListeners();
    });
  }

  void setPriority(String newValue) {
    _priority = newValue;
    notifyListeners();
  }

  void setDeliverySlot(String newValue) {
    _deliverySlot = newValue;
    notifyListeners();
  }
}