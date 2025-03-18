import 'dart:convert';
import 'dart:developer';
import 'package:animated_custom_dropdown/custom_dropdown.dart';
import 'package:flutter/material.dart';
import 'cyllo_session_model.dart';

Map<String, int> _temporaryInventory = {};

class Product with CustomDropdownListFilter {
  final String id;
  final String name;
  final double price;
  final int vanInventory;
  final String? imageUrl;
  final String? defaultCode;
  final List<dynamic>? sellerIds;
  final List<dynamic>? taxesIds;
  final dynamic categId;
  final dynamic propertyStockProduction;
  final dynamic propertyStockInventory;

  Product({
    required this.id,
    required this.name,
    required this.price,
    required this.vanInventory,
    this.imageUrl,
    this.defaultCode,
    this.sellerIds,
    this.taxesIds,
    this.categId,
    this.propertyStockProduction,
    this.propertyStockInventory,
  });

  @override
  String toString() => name;

  bool filter(String query) {
    final lowercaseQuery = query.toLowerCase();
    return name.toLowerCase().contains(lowercaseQuery) ||
        (defaultCode != null &&
            defaultCode!.toLowerCase().contains(lowercaseQuery));
  }
}

class Customer with CustomDropdownListFilter {
  final String id;
  final String name;
  final String? phone;
  final String? email;
  final String? city;
  final dynamic companyId;

  Customer({
    required this.id,
    required this.name,
    this.phone,
    this.email,
    this.city,
    this.companyId,
  });

  @override
  String toString() => name;

  @override
  bool filter(String query) {
    return name.toLowerCase().contains(query.toLowerCase());
  }
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

class SalesOrderProvider with ChangeNotifier {
  int _currentStep = 0;
  List<Product> _products = [];
  List<OrderItem> _orderItems = [];
  String? _customerId;
  String? _customerName;
  SalesOrder? _salesOrder;
  bool _isLoading = false;
  final Set<String> _confirmedOrderIds = {};

  bool isOrderIdConfirmed(String orderId) {
    return _confirmedOrderIds.contains(orderId);
  }

  int get currentStep => _currentStep;

  List<Product> get products => _products;

  List<OrderItem> get orderItems => _orderItems;

  String? get customerId => _customerId;

  String? get customerName => _customerName;

  SalesOrder? get salesOrder => _salesOrder;

  bool get isLoading => _isLoading;

  void setCurrentStep(int step) {
    if (step <= _currentStep) {
      _currentStep = step;
      notifyListeners();
    }
  }

  int getAvailableQuantity(String productId) {
    return _temporaryInventory[productId] ??
        _products.firstWhere((p) => p.id == productId).vanInventory;
  }

  void addToOrder(Product product, int quantity) {
    if (quantity > getAvailableQuantity(product.id)) {
      log('Cannot exceed available inventory');
      return;
    }

    final updatedOrder = List<OrderItem>.from(_orderItems);
    final existingItemIndex =
        updatedOrder.indexWhere((item) => item.product.id == product.id);

    if (existingItemIndex >= 0) {
      final currentQuantity = updatedOrder[existingItemIndex].quantity;
      if (currentQuantity + quantity > getAvailableQuantity(product.id)) {
        log('Cannot exceed available inventory');
        return;
      }
      updatedOrder[existingItemIndex].quantity += quantity;
    } else {
      updatedOrder.add(OrderItem(product: product, quantity: quantity));
    }

    _orderItems = updatedOrder;
    updateInventory(product.id, quantity);
    notifyListeners();
  }

  void updateInventory(String productId, int quantity) {
    final currentInventory = getAvailableQuantity(productId);
    _temporaryInventory[productId] = currentInventory - quantity;
    notifyListeners();
  }

  Future<void> confirmOrderInCyllo({
    required String orderId,
    required List<OrderItem> items,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      _salesOrder = SalesOrder(
        id: orderId,
        items: items,
        creationDate: DateTime.now(),
        status: 'Confirmed',
        validated: true,
      );
      _orderItems = [];
      _temporaryInventory.clear();
      _confirmedOrderIds.add(orderId);
      notifyListeners();
    } catch (e) {
      log('Error confirming order: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearConfirmedOrderIds() {
    _confirmedOrderIds.clear();
    notifyListeners();
  }

  void resetInventory() {
    _temporaryInventory = {
      for (var product in _products) product.id: product.vanInventory
    };
    notifyListeners();
  }

  void removeItem(String productId) {
    _orderItems =
        _orderItems.where((item) => item.product.id != productId).toList();
    notifyListeners();
  }

  void clearOrder() {
    _orderItems = [];
    notifyListeners();
  }

  void confirmOrder() {
    if (_orderItems.isEmpty) {
      log('Please add at least one product to the order');
      return;
    }

    _salesOrder = SalesOrder(
      id: 'SO0008',
      items: List.from(_orderItems),
      creationDate: DateTime.now(),
    );
    _currentStep = 0;
    notifyListeners();
  }

  Future<void> loadProducts() async {
    _isLoading = true;
    notifyListeners();

    try {
      final client = await SessionManager.getActiveClient();
      if (client != null) {
        final result = await client.callKw({
          'model': 'product.product',
          'method': 'search_read',
          'args': [
            [
              ['product_tmpl_id.detailed_type', '=', 'product']
            ]
          ],
          'kwargs': {
            'fields': [
              'id',
              'name',
              'list_price',
              'qty_available',
              'image_1920',
              'default_code',
              'seller_ids',
              'taxes_id',
              'categ_id',
              'property_stock_production',
              'property_stock_inventory',
            ],
          },
        });

        final List<Product> fetchedProducts =
            (result as List).map((productData) {
          String? imageUrl;
          final imageData = productData['image_1920'];

          if (imageData != false &&
              imageData is String &&
              imageData.isNotEmpty) {
            try {
              base64Decode(imageData);
              imageUrl = 'data:image/jpeg;base64,$imageData';
            } catch (e) {
              log("Invalid base64 image data for product ${productData['id']}: $e");
              imageUrl = null;
            }
          }

          String? defaultCode;
          if (productData['default_code'] is String) {
            defaultCode = productData['default_code'];
          } else {
            defaultCode = null;
          }

          return Product(
            id: productData['id'].toString(),
            name: productData['name'] is String
                ? productData['name']
                : 'Unnamed Product',
            price: (productData['list_price'] as num?)?.toDouble() ?? 0.0,
            vanInventory: (productData['qty_available'] as num?)?.toInt() ?? 0,
            imageUrl: imageUrl,
            defaultCode: defaultCode,
            sellerIds: productData['seller_ids'] is List
                ? productData['seller_ids']
                : [],
            taxesIds:
                productData['taxes_id'] is List ? productData['taxes_id'] : [],
            categId: productData['categ_id'] ?? false,
            propertyStockProduction:
                productData['property_stock_production'] ?? false,
            propertyStockInventory:
                productData['property_stock_inventory'] ?? false,
          );
        }).toList();

        fetchedProducts.sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        _products = fetchedProducts;

        log("Successfully fetched ${fetchedProducts.length} storable products");
        log("Total products: ${_products.length}");

        if (_products.isEmpty) {
          log("No storable products found");
        } else {
          final firstProduct = _products[0];
          log("First product details:");
          log("Default Code: ${firstProduct.defaultCode ?? 'N/A'}");
          log("Seller IDs: ${firstProduct.sellerIds}");
          log("Taxes IDs: ${firstProduct.taxesIds}");
          log("Category: ${firstProduct.categId}");
          log("Production Location: ${firstProduct.propertyStockProduction}");
          log("Inventory Location: ${firstProduct.propertyStockInventory}");
        }
      }
    } catch (e) {
      log("Error fetching products: $e");
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
