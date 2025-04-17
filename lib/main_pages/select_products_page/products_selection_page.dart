import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:van_sale_applicatioin/secondary_pages/sale_order_creation/sale_order_page.dart';
import 'dart:convert';
import 'dart:developer';
import '../../authentication/cyllo_session_model.dart';
import '../../secondary_pages/sale_order_history_page/sale_order_history_page.dart';
import 'order_picking_provider.dart';
import '../../secondary_pages/sale_order_creation/sales_order_provider.dart';
import '../../widgets/page_transition.dart';

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
  bool _isLoading = false;

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

  Future<List<Map<String, dynamic>>?> _showAttributeSelectionDialog(
      BuildContext context, Product product) async {
    if (product.attributes == null || product.attributes!.isEmpty) return null;

    List<Map<String, dynamic>> selectedCombinations = [];

    return await showDialog<List<Map<String, dynamic>>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            flex: 9,
                            child: Text(
                              'Variants for ${product.name}',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: primaryDarkColor,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: IconButton(
                              icon: Icon(Icons.close, color: Colors.grey[600]),
                              onPressed: () => Navigator.pop(context, null),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (selectedCombinations.isNotEmpty) ...[
                        Text(
                          'Selected Combinations',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          constraints: BoxConstraints(
                            maxHeight: 150,
                            minWidth: double.infinity,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: SingleChildScrollView(
                            child: Column(
                              children: selectedCombinations.map((combo) {
                                final attrs =
                                    combo['attributes'] as Map<String, String>;
                                final qty = combo['quantity'] as int;
                                double extraCost = 0;
                                for (var attr in product.attributes!) {
                                  final value = attrs[attr.name];
                                  if (value != null && attr.extraCost != null) {
                                    extraCost += attr.extraCost![value] ?? 0;
                                  }
                                }
                                final totalCost =
                                    (product.price + extraCost) * qty;
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 8, horizontal: 12),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              attrs.entries
                                                  .map((e) =>
                                                      '${e.key}: ${e.value}')
                                                  .join(', '),
                                              style:
                                                  const TextStyle(fontSize: 14),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Qty: $qty | Extra: \$${extraCost.toStringAsFixed(2)} | Total: \$${totalCost.toStringAsFixed(2)}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete,
                                            color: Colors.redAccent),
                                        onPressed: () {
                                          setState(() {
                                            selectedCombinations.remove(combo);
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Divider(),
                      ],
                      _AttributeCombinationForm(
                        product: product,
                        onAdd: (attributes, quantity) {
                          setState(() {
                            selectedCombinations.add({
                              'attributes': attributes,
                              'quantity': quantity,
                            });
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.grey[600],
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                            ),
                            onPressed: () => Navigator.pop(context, null),
                            child: const Text('Cancel',
                                style: TextStyle(fontSize: 14)),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: selectedCombinations.isNotEmpty
                                ? () =>
                                    Navigator.pop(context, selectedCombinations)
                                : null,
                            child: const Text('Confirm',
                                style: TextStyle(fontSize: 14)),
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
      },
    );
  }

  void _updateProductList(SalesOrderProvider salesProvider,
      OrderPickingProvider orderPickingProvider) {
    if (orderPickingProvider.needsProductRefresh) {
      setState(() {
        widget.availableProducts.clear();
        widget.availableProducts.addAll(salesProvider.products);
        filteredProducts = List.from(widget.availableProducts);
        searchController.clear();
        selectedProducts.clear();
        quantities.clear();
        for (var product in widget.availableProducts) {
          selectedProducts[product.id] = false;
          quantities[product.id] = 1;
        }
      });
      orderPickingProvider.resetProductRefreshFlag();
    }
  }

  @override
  void didUpdateWidget(ProductSelectionPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final salesProvider =
        Provider.of<SalesOrderProvider>(context, listen: false);
    final orderPickingProvider =
        Provider.of<OrderPickingProvider>(context, listen: false);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (orderPickingProvider.needsProductRefresh) {
        _updateProductList(salesProvider, orderPickingProvider);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final salesProvider =
        Provider.of<SalesOrderProvider>(context, listen: false);
    final orderPickingProvider =
        Provider.of<OrderPickingProvider>(context, listen: false);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (orderPickingProvider.needsProductRefresh) {
        _updateProductList(salesProvider, orderPickingProvider);
      }
    });

    return Scaffold(
      resizeToAvoidBottomInset: false,
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
              Navigator.push(
                  context,
                  SlidingPageTransitionRL(
                    page: const SaleOrderHistoryPage(),
                  ));
            },
            icon: Icon(
              Icons.history,
              color: Colors.white,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 4.0),
            child: LogoutButton(),
          ),
          // IconButton(
          //   onPressed: () {
          //     Navigator.push(
          //         context,
          //         SlidingPageTransitionRL(
          //           page: DriverHomePage(),
          //         ));
          //   },
          //   icon: Icon(
          //     Icons.scale,
          //     color: Colors.white,
          //   ),
          // ),
        ],
        backgroundColor: primaryColor,
        elevation: 0,
      ),
      body: Stack(
        children: [
          Container(
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
                                margin: const EdgeInsets.only(bottom: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                                  selectedProducts[product.id] =
                                                      value ?? false;
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
                                              child: product.imageUrl != null &&
                                                      product
                                                          .imageUrl!.isNotEmpty
                                                  ? (product.imageUrl!
                                                          .startsWith('http')
                                                      ? CachedNetworkImage(
                                                          imageUrl:
                                                              product.imageUrl!,
                                                          httpHeaders: {
                                                            "Cookie":
                                                                "session_id=${Provider.of<CylloSessionModel>(context, listen: false).sessionId}",
                                                          },
                                                          width: 60,
                                                          height: 60,
                                                          fit: BoxFit.cover,
                                                          progressIndicatorBuilder:
                                                              (context, url,
                                                                      downloadProgress) =>
                                                                  SizedBox(
                                                            width: 60,
                                                            height: 60,
                                                            child: Center(
                                                              child:
                                                                  CircularProgressIndicator(
                                                                value:
                                                                    downloadProgress
                                                                        .progress,
                                                                strokeWidth: 2,
                                                                color:
                                                                    primaryColor,
                                                              ),
                                                            ),
                                                          ),
                                                          imageBuilder: (context,
                                                              imageProvider) {
                                                            log("Image loaded successfully for product: ${product.name}");
                                                            return Container(
                                                              decoration:
                                                                  BoxDecoration(
                                                                image:
                                                                    DecorationImage(
                                                                  image:
                                                                      imageProvider,
                                                                  fit: BoxFit
                                                                      .cover,
                                                                ),
                                                              ),
                                                            );
                                                          },
                                                          errorWidget: (context,
                                                              url, error) {
                                                            log("Failed to load image for product ${product.name}: $error");
                                                            return Icon(
                                                              Icons
                                                                  .inventory_2_rounded,
                                                              color:
                                                                  primaryColor,
                                                              size: 24,
                                                            );
                                                          },
                                                        )
                                                      : Image.memory(
                                                          base64Decode(product
                                                              .imageUrl!
                                                              .split(',')
                                                              .last),
                                                          fit: BoxFit.cover,
                                                          errorBuilder:
                                                              (context, error,
                                                                  stackTrace) {
                                                            log("Failed to load image for product ${product.name}: $error");
                                                            return Icon(
                                                              Icons
                                                                  .inventory_2_rounded,
                                                              color:
                                                                  primaryColor,
                                                              size: 24,
                                                            );
                                                          },
                                                        ))
                                                  : Icon(
                                                      Icons.inventory_2_rounded,
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
                                                    fontWeight: FontWeight.w600,
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
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 6,
                                                          vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: Colors.grey[100],
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(4),
                                                      ),
                                                      child: Text(
                                                        "SL: ${product.defaultCode ?? 'N/A'}",
                                                        style: TextStyle(
                                                          color:
                                                              Colors.grey[700],
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                                      ),
                                                    ),
                                                    Container(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 6,
                                                          vertical: 2),
                                                      decoration: BoxDecoration(
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
                                                              : Colors.red[700],
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
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                // Display attributes if they exist
                                                if (product.attributes !=
                                                        null &&
                                                    product.attributes!
                                                        .isNotEmpty) ...[
                                                  const SizedBox(height: 8),
                                                  Wrap(
                                                    spacing: 6,
                                                    runSpacing: 4,
                                                    children: product
                                                        .attributes!
                                                        .map((attribute) {
                                                      return Container(
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                horizontal: 6,
                                                                vertical: 2),
                                                        decoration:
                                                            BoxDecoration(
                                                          color: Colors
                                                              .blueGrey[50],
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(4),
                                                        ),
                                                        child: Text(
                                                          "${attribute.name}: ${attribute.values.join(', ')}",
                                                          style: TextStyle(
                                                            color: Colors
                                                                .blueGrey[700],
                                                            fontSize: 12,
                                                            fontWeight:
                                                                FontWeight.w500,
                                                          ),
                                                        ),
                                                      );
                                                    }).toList(),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          Container(
                                            decoration: BoxDecoration(
                                              border: Border.all(
                                                  color: Colors.grey[300]!),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              color: Colors.grey[100],
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Material(
                                                  color: Colors.transparent,
                                                  child: InkWell(
                                                    borderRadius:
                                                        const BorderRadius.only(
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
                                                                  product.id]! -
                                                              1;
                                                        }
                                                      });
                                                    },
                                                    child: Container(
                                                      padding:
                                                          const EdgeInsets.all(
                                                              8),
                                                      decoration: BoxDecoration(
                                                        color: Colors.grey[200],
                                                        borderRadius:
                                                            const BorderRadius
                                                                .only(
                                                          topLeft:
                                                              Radius.circular(
                                                                  7),
                                                          bottomLeft:
                                                              Radius.circular(
                                                                  7),
                                                        ),
                                                      ),
                                                      child: Icon(
                                                        Icons.remove_rounded,
                                                        size: 16,
                                                        color: quantities[
                                                                    product
                                                                        .id]! >
                                                                1
                                                            ? primaryColor
                                                            : Colors.grey[400],
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                SizedBox(
                                                  width: 40,
                                                  child: TextField(
                                                    controller:
                                                        TextEditingController(
                                                            text: quantities[
                                                                    product.id]
                                                                .toString()),
                                                    textAlign: TextAlign.center,
                                                    keyboardType:
                                                        TextInputType.number,
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: Colors.grey[800],
                                                    ),
                                                    decoration: InputDecoration(
                                                      isDense: true,
                                                      contentPadding:
                                                          const EdgeInsets
                                                              .symmetric(
                                                              vertical: 8,
                                                              horizontal: 4),
                                                      border: InputBorder.none,
                                                      counterText: '',
                                                      fillColor:
                                                          Colors.grey[100],
                                                      filled: true,
                                                    ),
                                                    maxLength: 4,
                                                    onChanged: (value) {
                                                      int? newQuantity =
                                                          int.tryParse(value);
                                                      if (newQuantity != null &&
                                                          newQuantity > 0) {
                                                        setState(() {
                                                          quantities[
                                                                  product.id] =
                                                              newQuantity;
                                                        });
                                                      }
                                                    },
                                                    onSubmitted: (value) {
                                                      int? newQuantity =
                                                          int.tryParse(value);
                                                      if (newQuantity == null ||
                                                          newQuantity <= 0) {
                                                        setState(() {
                                                          quantities[
                                                              product.id] = 1;
                                                        });
                                                      }
                                                    },
                                                  ),
                                                ),
                                                Material(
                                                  color: Colors.transparent,
                                                  child: InkWell(
                                                    borderRadius:
                                                        const BorderRadius.only(
                                                      topRight:
                                                          Radius.circular(7),
                                                      bottomRight:
                                                          Radius.circular(7),
                                                    ),
                                                    onTap: () {
                                                      setState(() {
                                                        quantities[product.id] =
                                                            quantities[product
                                                                    .id]! +
                                                                1;
                                                      });
                                                    },
                                                    child: Container(
                                                      padding:
                                                          const EdgeInsets.all(
                                                              8),
                                                      decoration: BoxDecoration(
                                                        color: Colors.grey[200],
                                                        borderRadius:
                                                            const BorderRadius
                                                                .only(
                                                          topRight:
                                                              Radius.circular(
                                                                  7),
                                                          bottomRight:
                                                              Radius.circular(
                                                                  7),
                                                        ),
                                                      ),
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
                    padding: const EdgeInsets.only(bottom: 20.0),
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
                            onPressed: _isLoading
                                ? null // Disable button while loading
                                : () async {
                                    setState(() {
                                      _isLoading = true; // Start loading
                                    });

                                    try {
                                      final selected = widget.availableProducts
                                          .where((product) =>
                                              selectedProducts[product.id] ==
                                              true)
                                          .toList();

                                      if (selected.isEmpty) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: const Text(
                                                'Please select at least one product!'),
                                            backgroundColor: Colors.grey,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      kBorderRadius),
                                            ),
                                            behavior: SnackBarBehavior.floating,
                                            margin: const EdgeInsets.all(16),
                                          ),
                                        );
                                        return;
                                      }

                                      final orderId = await orderPickingProvider
                                          .generateOrderId();
                                      double total = 0;
                                      List<Product> finalProducts = [];
                                      Map<String, int> updatedQuantities =
                                          Map.from(quantities);
                                      Map<String, List<Map<String, dynamic>>>
                                          productAttributes = {};

                                      for (var product in selected) {
                                        final baseQuantity =
                                            quantities[product.id] ?? 0;
                                        if (product.attributes != null &&
                                            product.attributes!.isNotEmpty) {
                                          final combinations =
                                              await _showAttributeSelectionDialog(
                                                  context, product);
                                          if (combinations != null &&
                                              combinations.isNotEmpty) {
                                            productAttributes[product.id] =
                                                combinations;
                                            final totalAttributeQuantity =
                                                combinations.fold<int>(
                                                    0,
                                                    (sum, comb) =>
                                                        sum +
                                                        (comb['quantity']
                                                            as int));
                                            updatedQuantities[product.id] =
                                                totalAttributeQuantity;

                                            double productTotal = 0;
                                            for (var combo in combinations) {
                                              final qty =
                                                  combo['quantity'] as int;
                                              final attrs = combo['attributes']
                                                  as Map<String, String>;
                                              double extraCost = 0;
                                              for (var attr
                                                  in product.attributes!) {
                                                final value = attrs[attr.name];
                                                if (value != null &&
                                                    attr.extraCost != null) {
                                                  extraCost +=
                                                      attr.extraCost![value] ??
                                                          0;
                                                }
                                              }
                                              productTotal +=
                                                  (product.price + extraCost) *
                                                      qty;
                                            }
                                            total += productTotal;
                                            finalProducts.add(product);
                                            widget.onAddProduct(product,
                                                totalAttributeQuantity);
                                          }
                                        } else if (baseQuantity > 0) {
                                          total += product.price * baseQuantity;
                                          finalProducts.add(product);
                                          widget.onAddProduct(
                                              product, baseQuantity);
                                        }
                                      }

                                      if (finalProducts.isEmpty) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                                'No valid products selected with quantities!'),
                                            backgroundColor: Colors.red,
                                            behavior: SnackBarBehavior.floating,
                                            margin: EdgeInsets.all(16),
                                          ),
                                        );
                                        return;
                                      }

                                      Navigator.push(
                                        context,
                                        SlidingPageTransitionRL(
                                          page: SaleOrderPage(
                                            selectedProducts: finalProducts,
                                            quantities: updatedQuantities,
                                            totalAmount: total,
                                            orderId: orderId,
                                            onClearSelections: clearSelections,
                                            productAttributes:
                                                productAttributes,
                                          ),
                                        ),
                                      );
                                    } finally {
                                      setState(() {
                                        _isLoading = false; // Stop loading
                                      });
                                    }
                                  },
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(
                                  'Create Sale Order',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Visibility(
                                  visible: _isLoading,
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
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 80,
            right: 20,
            child: FloatingActionButton(
              onPressed: () {
                orderPickingProvider.addNewProduct(context);
              },
              backgroundColor: backgroundColor,
              foregroundColor: primaryColor,
              elevation: 6.0,
              hoverElevation: 8.0,
              focusElevation: 8.0,
              mini: false,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.0),
              ),
              tooltip: 'Add New Product',
              enableFeedback: true,
              child: Icon(
                Icons.add_box,
                size: 28.0,
                color: primaryColor,
                semanticLabel: 'Add new product icon',
              ),
            ),
          )
        ],
      ),
    );
  }
}

class _AttributeCombinationForm extends StatefulWidget {
  final Product product;
  final Function(Map<String, String>, int) onAdd;

  const _AttributeCombinationForm({
    required this.product,
    required this.onAdd,
  });

  @override
  __AttributeCombinationFormState createState() =>
      __AttributeCombinationFormState();
}

class __AttributeCombinationFormState extends State<_AttributeCombinationForm> {
  Map<String, String> selectedAttributes = {};
  final TextEditingController quantityController =
      TextEditingController(text: '1');
  final currencyFormat = NumberFormat.currency(symbol: '\$');

  double calculateExtraCost() {
    double extraCost = 0;
    for (var attr in widget.product.attributes!) {
      final value = selectedAttributes[attr.name];
      if (value != null && attr.extraCost != null) {
        extraCost += attr.extraCost![value] ?? 0;
      }
    }
    return extraCost;
  }

  @override
  Widget build(BuildContext context) {
    final extraCost = calculateExtraCost();
    final basePrice = widget.product.price;
    final qty = int.tryParse(quantityController.text) ?? 0;
    final totalCost = (basePrice + extraCost) * qty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Add New Combination',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 12),
        ...widget.product.attributes!.map((attribute) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: DropdownButtonFormField<String>(
              value: selectedAttributes[attribute.name],
              decoration: InputDecoration(
                labelText: attribute.name,
                labelStyle: TextStyle(color: Colors.grey[600]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: primaryColor, width: 2),
                ),
                filled: true,
                fillColor: Colors.grey[50],
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              items: attribute.values.map((value) {
                final extra = attribute.extraCost?[value] ?? 0;
                return DropdownMenuItem<String>(
                  value: value,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(value),
                      if (extra > 0)
                        Text(
                          '+\$${extra.toStringAsFixed(2)}',
                          style: const TextStyle(
                              color: Colors.redAccent, fontSize: 12),
                        ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  if (value != null) {
                    selectedAttributes[attribute.name] = value;
                  }
                });
              },
            ),
          );
        }).toList(),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: quantityController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Quantity',
                  labelStyle: TextStyle(color: Colors.grey[600]),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: primaryColor, width: 2),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                onChanged: (value) => setState(() {}),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Extra: ${currencyFormat.format(extraCost)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: extraCost > 0 ? Colors.redAccent : Colors.grey[600],
                  ),
                ),
                Text(
                  'Total: ${currencyFormat.format(totalCost)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton.icon(
            onPressed: selectedAttributes.length ==
                        widget.product.attributes!.length &&
                    qty > 0
                ? () {
                    widget.onAdd(Map.from(selectedAttributes), qty);
                    setState(() {
                      selectedAttributes.clear();
                      quantityController.text = '1';
                    });
                  }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add', style: TextStyle(fontSize: 14)),
          ),
        ),
      ],
    );
  }
}
