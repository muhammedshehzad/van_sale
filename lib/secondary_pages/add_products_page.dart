import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:van_sale_applicatioin/secondary_pages/sale_order_history_page.dart';
import 'package:van_sale_applicatioin/secondary_pages/sale_order_page.dart';
import 'dart:convert';
import 'dart:developer';

import '../provider_and_models/order_picking_provider.dart';
import '../provider_and_models/sales_order_provider.dart';
import '../widgets/page_transition.dart';

class ProductSelectionPage extends StatefulWidget {
  final List<Product> availableProducts;
  final Function(Product, int) onAddProduct;

  const ProductSelectionPage({
    Key? key,
    required this.availableProducts,
    required this.onAddProduct,
  }) : super(key: key);

  @override
  _ProductSelectionPageState createState() => _ProductSelectionPageState();
}

class _ProductSelectionPageState extends State<ProductSelectionPage> {
  List<Product> filteredProducts = [];
  TextEditingController searchController = TextEditingController();
  Map<String, bool> selectedProducts = {};
  Map<String, int> quantities = {};

  @override
  void initState() {
    super.initState();
    filteredProducts = List.from(widget.availableProducts);
    for (var product in widget.availableProducts) {
      selectedProducts[product.id] = false;
      quantities[product.id] = 1;
    }
  }

  void _filterProducts(String query) {
    setState(() {
      if (query.isEmpty) {
        filteredProducts = List.from(widget.availableProducts);
      } else {
        filteredProducts = widget.availableProducts
            .where((product) => product.filter(query))
            .toList();
      }
    });
  }

  void clearSelections() {
    setState(() {
      for (var product in widget.availableProducts) {
        selectedProducts[product.id] = false;
        quantities[product.id] = 1;
      }
      searchController.clear();
      filteredProducts = List.from(widget.availableProducts);
    });
  }

  Future<void> _refreshProducts() async {
    try {
      final saleorderProvider =
          Provider.of<SalesOrderProvider>(context, listen: false);

      await saleorderProvider.loadProducts();

      setState(() {
        widget.availableProducts.clear();
        widget.availableProducts.addAll(saleorderProvider.products);
        filteredProducts = List.from(widget.availableProducts);
        searchController.clear();
        selectedProducts.clear();
        quantities.clear();
        for (var product in widget.availableProducts) {
          selectedProducts[product.id] = false;
          quantities[product.id] = 1;
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Products refreshed successfully'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      log("Error refreshing products: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to refresh products: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SalesOrderProvider()),
        ChangeNotifierProvider(create: (_) => OrderPickingProvider()),
      ],
      child: Consumer<OrderPickingProvider>(
        builder: (context, provider, _) {
          Provider.of<SalesOrderProvider>(context);
          return Scaffold(
            backgroundColor: backgroundColor,
            appBar: AppBar(
              title: const Text(
                'Select Products',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              actions: [
                IconButton(
                  onPressed: () {
                    // Navigator.push(
                    //     context,
                    //     SlidingPageTransitionRL(
                    //       page: const SaleOrderHistoryPage(),
                    //     ));
                  },
                  icon: Icon(
                    Icons.history,
                    color: Colors.white,
                  ),
                ),
                IconButton(
                  onPressed: () {
                    // provider.addNewProduct(context);
                  },
                  icon: Icon(
                    Icons.add_box,
                    color: Colors.white,
                  ),
                )
              ],
              backgroundColor: primaryColor,
              elevation: 0,
            ),
            body: Container(
              width: MediaQuery.of(context).size.width,
              height: MediaQuery.of(context).size.height,
              padding: const EdgeInsets.only(left: 12, right: 12, top: 12),
              child: RefreshIndicator(
                onRefresh: _refreshProducts,
                color: primaryColor,
                child: Column(
                  children: [
                    TextField(
                      controller: searchController,
                      decoration: InputDecoration(
                        hintText: 'Search products...',
                        hintStyle: TextStyle(color: Colors.grey[600]),
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Colors.grey,
                        ),
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
                          borderSide: const BorderSide(color: primaryColor),
                        ),
                        filled: true,
                        fillColor: Colors.grey[100],
                      ),
                      onChanged: _filterProducts,
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: filteredProducts.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.search_off,
                                    size: 48,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    widget.availableProducts.isEmpty
                                        ? 'No products available'
                                        : 'No products match your search',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              itemCount: filteredProducts.length,
                              itemBuilder: (context, index) {
                                final product = filteredProducts[index];
                                return Card(
                                  color: Colors.white,
                                  elevation: 1,
                                  margin: const EdgeInsets.only(
                                    bottom: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      children: [
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Transform.scale(
                                              scale: 1.0,
                                              child: Checkbox(
                                                value: selectedProducts[
                                                        product.id] ??
                                                    false,
                                                activeColor: primaryColor,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                materialTapTargetSize:
                                                    MaterialTapTargetSize
                                                        .shrinkWrap,
                                                visualDensity:
                                                    VisualDensity.compact,
                                                onChanged: (value) {
                                                  setState(() {
                                                    selectedProducts[product
                                                        .id] = value ?? false;
                                                  });
                                                },
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              width: 60,
                                              height: 60,
                                              decoration: BoxDecoration(
                                                color: Colors.grey[100],
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                child: product.imageUrl !=
                                                            null &&
                                                        product.imageUrl!
                                                            .isNotEmpty
                                                    ? Image.memory(
                                                        base64Decode(product
                                                            .imageUrl!
                                                            .split(',')
                                                            .last),
                                                        fit: BoxFit.cover,
                                                        errorBuilder: (context,
                                                            error, stackTrace) {
                                                          log("Failed to load image for product ${product.name}: $error");
                                                          return Icon(
                                                            Icons
                                                                .inventory_2_rounded,
                                                            color: primaryColor,
                                                            size: 24,
                                                          );
                                                        },
                                                      )
                                                    : Icon(
                                                        Icons
                                                            .inventory_2_rounded,
                                                        color: primaryColor,
                                                        size: 24,
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
                                                    product.name,
                                                    style: const TextStyle(
                                                      fontSize: 15,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: Colors.black87,
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Wrap(
                                                    spacing: 6,
                                                    runSpacing: 4,
                                                    children: [
                                                      Container(
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                horizontal: 6,
                                                                vertical: 2),
                                                        decoration:
                                                            BoxDecoration(
                                                          color:
                                                              Colors.grey[100],
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(4),
                                                        ),
                                                        child: Text(
                                                          "SL: ${product.defaultCode ?? 'N/A'}",
                                                          style: TextStyle(
                                                            color: Colors
                                                                .grey[700],
                                                            fontSize: 12,
                                                            fontWeight:
                                                                FontWeight.w500,
                                                          ),
                                                        ),
                                                      ),
                                                      Container(
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                horizontal: 6,
                                                                vertical: 2),
                                                        decoration:
                                                            BoxDecoration(
                                                          color:
                                                              product.vanInventory >
                                                                      0
                                                                  ? Colors
                                                                      .green[50]
                                                                  : Colors
                                                                      .red[50],
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(4),
                                                        ),
                                                        child: Text(
                                                          "${product.vanInventory} in stock",
                                                          style: TextStyle(
                                                            color: product
                                                                        .vanInventory >
                                                                    0
                                                                ? Colors
                                                                    .green[700]
                                                                : Colors
                                                                    .red[700],
                                                            fontSize: 12,
                                                            fontWeight:
                                                                FontWeight.w500,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    "\$${product.price}",
                                                    style: TextStyle(
                                                      color: primaryColor,
                                                      fontSize: 15,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisAlignment:
                                              MainAxisAlignment.end,
                                          children: [
                                            Container(
                                              decoration: BoxDecoration(
                                                border: Border.all(
                                                    color: Colors.grey[200]!),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                color: Colors.grey[200],
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Material(
                                                    color: Colors.transparent,
                                                    child: InkWell(
                                                      borderRadius:
                                                          const BorderRadius
                                                              .only(
                                                        topLeft:
                                                            Radius.circular(7),
                                                        bottomLeft:
                                                            Radius.circular(7),
                                                      ),
                                                      onTap: () {
                                                        setState(() {
                                                          if (quantities[
                                                                  product.id]! >
                                                              1) {
                                                            quantities[product
                                                                .id] = quantities[
                                                                    product
                                                                        .id]! -
                                                                1;
                                                          }
                                                        });
                                                      },
                                                      child: Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .all(6),
                                                        child: Icon(
                                                          Icons.remove_rounded,
                                                          size: 16,
                                                          color: quantities[
                                                                      product
                                                                          .id]! >
                                                                  1
                                                              ? primaryColor
                                                              : Colors
                                                                  .grey[600],
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  Container(
                                                    constraints:
                                                        const BoxConstraints(
                                                            minWidth: 24),
                                                    alignment: Alignment.center,
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 4),
                                                    child: Text(
                                                      '${quantities[product.id]}',
                                                      style: const TextStyle(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                  ),
                                                  Material(
                                                    color: Colors.transparent,
                                                    child: InkWell(
                                                      borderRadius:
                                                          const BorderRadius
                                                              .only(
                                                        topRight:
                                                            Radius.circular(7),
                                                        bottomRight:
                                                            Radius.circular(7),
                                                      ),
                                                      onTap: () {
                                                        setState(() {
                                                          quantities[product
                                                              .id] = quantities[
                                                                  product.id]! +
                                                              1;
                                                        });
                                                      },
                                                      child: Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .all(6),
                                                        child: Icon(
                                                          Icons.add_rounded,
                                                          size: 16,
                                                          color: primaryColor,
                                                        ),
                                                      ),
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
                                );
                              },
                            ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                minimumSize: const Size(0, 40),
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(kBorderRadius),
                                ),
                              ),
                              onPressed: () async {
                                final selected = widget.availableProducts
                                    .where((product) =>
                                        selectedProducts[product.id] == true)
                                    .toList();

                                if (selected.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text(
                                          'Please select at least one product!'),
                                      backgroundColor: Colors.grey,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                            kBorderRadius),
                                      ),
                                      behavior: SnackBarBehavior.floating,
                                      margin: const EdgeInsets.all(16),
                                    ),
                                  );
                                  return;
                                }

                                final orderId =
                                    await provider.generateOrderId();
                                double total = 0;
                                for (var product in selected) {
                                  final quantity = quantities[product.id] ?? 0;
                                  total += product.price * quantity;
                                  widget.onAddProduct(product,
                                      quantity); // Calls addProductFromList with salesProvider
                                }

                                Navigator.push(
                                  context,
                                  SlidingPageTransitionRL(
                                    page: SaleOrderPage(
                                      selectedProducts: selected,
                                      quantities: quantities,
                                      totalAmount: total,
                                      orderId: orderId,
                                      onClearSelections: clearSelections,
                                    ),
                                  ),
                                );
                              },
                              child: const Text(
                                'Create Sale Order',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
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
        },
      ),
    );
  }
}
