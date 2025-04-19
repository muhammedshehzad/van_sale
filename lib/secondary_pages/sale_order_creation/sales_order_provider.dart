import 'dart:convert';
import 'dart:developer';
import 'package:animated_custom_dropdown/custom_dropdown.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../authentication/cyllo_session_model.dart';

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
  final List<ProductAttribute>? attributes;

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
    this.attributes,
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

class ProductAttribute {
  final String name;
  final List<String> values;
  final Map<String, double>? extraCost;

  ProductAttribute({required this.name, required this.values, this.extraCost});
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
  final Map<String, List<Map<String, dynamic>>>? productAttributes;

  OrderItem({
    required this.product,
    required this.quantity,
    this.productAttributes,
  });

  double get subtotal {
    double total = 0;
    final attributes = productAttributes?[product.id];
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
        total += (product.price + extraCost) * qty;
      }
    } else {
      total = product.price * quantity;
    }
    return total;
  }
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
        (sum, item) => sum + item.subtotal,
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
  String? _draftOrderId;
  List<Product> _draftSelectedProducts = [];
  Map<String, int> _draftQuantities = {};
  Map<String, List<Map<String, dynamic>>> _draftProductAttributes = {};

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

  String? get draftOrderId => _draftOrderId;

  List<Product> get draftSelectedProducts => _draftSelectedProducts;

  Map<String, int> get draftQuantities => _draftQuantities;

  Map<String, List<Map<String, dynamic>>> get draftProductAttributes =>
      _draftProductAttributes;

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

  Future<int?> _findExistingDraftOrder(String orderId) async {
    try {
      final client = await SessionManager.getActiveClient();
      if (client == null) {
        throw Exception('No active Odoo session found. Please log in again.');
      }

      final result = await client.callKw({
        'model': 'sale.order',
        'method': 'search',
        'args': [
          [
            ['name', '=', orderId],
            ['state', '=', 'draft'],
          ]
        ],
        'kwargs': {},
      });

      if (result is List && result.isNotEmpty) {
        return result[0] as int; // Return the Odoo ID of the existing draft
      }
      return null;
    } catch (e) {
      log('Error searching for draft order: $e');
      return null;
    }
  }

  Future<void> createDraftSaleOrder({
    required String orderId,
    required List<Product> selectedProducts,
    required Map<String, int> quantities,
    required Map<String, List<Map<String, dynamic>>> productAttributes,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final client = await SessionManager.getActiveClient();
      if (client == null) {
        throw Exception('No active Odoo session found. Please log in again.');
      }

      // Prepare order lines
      final orderLines = <dynamic>[];
      for (var product in selectedProducts) {
        final attributes = productAttributes[product.id];
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
          final quantity = quantities[product.id] ?? 0;
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

      // Check for existing draft
      final existingOrderId = await _findExistingDraftOrder(orderId);
      int saleOrderId;

      if (existingOrderId != null) {
        // Update existing draft
        await client.callKw({
          'model': 'sale.order',
          'method': 'write',
          'args': [
            [existingOrderId],
            {
              'order_line': [
                [5, 0, 0]
              ], // Clear existing lines
            },
          ],
          'kwargs': {},
        });
        await client.callKw({
          'model': 'sale.order',
          'method': 'write',
          'args': [
            [existingOrderId],
            {
              'order_line': orderLines,
            },
          ],
          'kwargs': {},
        });
        saleOrderId = existingOrderId;
        log('Draft sale order updated: $orderId (Odoo ID: $saleOrderId)');
      } else {
        // Create new draft
        saleOrderId = await client.callKw({
          'model': 'sale.order',
          'method': 'create',
          'args': [
            {
              'name': orderId,
              'partner_id': 1, // Default customer ID (replace with actual ID)
              'order_line': orderLines,
              'state': 'draft',
              'date_order':
                  DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
            }
          ],
          'kwargs': {},
        });
        log('Draft sale order created: $orderId (Odoo ID: $saleOrderId)');
      }

      _draftOrderId = orderId;
      _draftSelectedProducts = List.from(selectedProducts);
      _draftQuantities = Map.from(quantities);
      _draftProductAttributes = Map.from(productAttributes);
    } catch (e) {
      log('Error managing draft sale order: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
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
      clearDraft();
      notifyListeners();
    } catch (e) {
      log('Error confirming order: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearDraft() {
    _draftOrderId = null;
    _draftSelectedProducts.clear();
    _draftQuantities.clear();
    _draftProductAttributes.clear();
    notifyListeners();
  }

  void notifyOrderConfirmed() {
    notifyListeners();
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
      if (client == null) {
        throw Exception('No active Odoo session found. Please log in again.');
      }

      final productResult = await client.callKw({
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
            'product_tmpl_id',
          ],
        },
      });

      final templateIds = (productResult as List)
          .map((productData) => productData['product_tmpl_id'][0] as int)
          .toSet()
          .toList();

      final attributeLineResult = await client.callKw({
        'model': 'product.template.attribute.line',
        'method': 'search_read',
        'args': [
          [
            ['product_tmpl_id', 'in', templateIds]
          ]
        ],
        'kwargs': {
          'fields': [
            'product_tmpl_id',
            'attribute_id',
            'value_ids',
          ],
        },
      });

      final attributeIds = (attributeLineResult as List)
          .map((attr) => attr['attribute_id'][0] as int)
          .toSet()
          .toList();
      final attributeNames = await client.callKw({
        'model': 'product.attribute',
        'method': 'search_read',
        'args': [
          [
            ['id', 'in', attributeIds]
          ]
        ],
        'kwargs': {
          'fields': ['id', 'name'],
        },
      });

      final templateAttributeValueResult = await client.callKw({
        'model': 'product.template.attribute.value',
        'method': 'search_read',
        'args': [
          [
            ['product_tmpl_id', 'in', templateIds]
          ]
        ],
        'kwargs': {
          'fields': [
            'product_tmpl_id',
            'attribute_id',
            'product_attribute_value_id',
            'price_extra',
          ],
        },
      });

      final valueIds = (templateAttributeValueResult as List)
          .map((attr) => attr['product_attribute_value_id'][0] as int)
          .toSet()
          .toList();
      final attributeValues = await client.callKw({
        'model': 'product.attribute.value',
        'method': 'search_read',
        'args': [
          [
            ['id', 'in', valueIds]
          ]
        ],
        'kwargs': {
          'fields': ['id', 'name'],
        },
      });

      final attributeNameMap = {
        for (var attr in attributeNames) attr['id']: attr['name'] as String
      };
      final attributeValueMap = {
        for (var val in attributeValues) val['id']: val['name'] as String
      };

      final templateAttributeValueMap =
          <int, Map<int, Map<int, Map<String, dynamic>>>>{};
      for (var attrVal in templateAttributeValueResult) {
        final templateId = attrVal['product_tmpl_id'][0] as int;
        final attributeId = attrVal['attribute_id'][0] as int;
        final valueId = attrVal['product_attribute_value_id'][0] as int;
        final priceExtra = (attrVal['price_extra'] as num?)?.toDouble() ?? 0.0;

        templateAttributeValueMap.putIfAbsent(templateId, () => {});
        templateAttributeValueMap[templateId]!
            .putIfAbsent(attributeId, () => {});
        templateAttributeValueMap[templateId]![attributeId]!
            .putIfAbsent(valueId, () => {});
        templateAttributeValueMap[templateId]![attributeId]![valueId] = {
          'name': attributeValueMap[valueId] ?? 'Unknown',
          'price_extra': priceExtra,
        };
      }

      final templateAttributes = <int, List<ProductAttribute>>{};
      for (var attrLine in attributeLineResult) {
        final templateId = attrLine['product_tmpl_id'][0] as int;
        final attributeId = attrLine['attribute_id'][0] as int;
        final valueIds = attrLine['value_ids'] as List;

        final attributeName = attributeNameMap[attributeId] ?? 'Unknown';
        final values = valueIds
            .map((id) => attributeValueMap[id] ?? 'Unknown')
            .toList()
            .cast<String>();
        final extraCosts = <String, double>{
          for (var id in valueIds)
            attributeValueMap[id as int]!:
                (templateAttributeValueMap[templateId]?[attributeId]?[id as int]
                            ?['price_extra'] as num?)
                        ?.toDouble() ??
                    0.0
        };

        templateAttributes.putIfAbsent(templateId, () => []).add(
              ProductAttribute(
                name: attributeName,
                values: values,
                extraCost: extraCosts,
              ),
            );
      }

      final List<Product> fetchedProducts =
          (productResult as List).map((productData) {
        String? imageUrl;
        final imageData = productData['image_1920'];

        if (imageData != false && imageData is String && imageData.isNotEmpty) {
          try {
            base64Decode(imageData);
            imageUrl = 'data:image/jpeg;base64,$imageData';
          } catch (e) {
            log("Invalid base64 image data for product ${productData['id']}: $e");
            imageUrl = null;
          }
        }

        String? defaultCode = productData['default_code'] is String
            ? productData['default_code']
            : null;

        final templateId = productData['product_tmpl_id'][0] as int;
        final attributes = templateAttributes[templateId] ?? [];

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
          attributes: attributes.isNotEmpty ? attributes : null,
        );
      }).toList();

      fetchedProducts
          .sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
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
        if (firstProduct.attributes != null) {
          log("Attributes: ${firstProduct.attributes!.map((a) => '${a.name}: ${a.values.join(', ')} (Extra Costs: ${a.extraCost})').join('; ')}");
        } else {
          log("Attributes: None");
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
