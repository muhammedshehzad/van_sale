import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:developer';

import '../provider_and_models/order_picking_provider.dart';
import '../provider_and_models/sales_order_provider.dart';

class MultiProductSelectionPage extends StatefulWidget {
  final List<Product> availableProducts;
  final Function(Product, int) onAddProduct;

  const MultiProductSelectionPage({
    Key? key,
    required this.availableProducts,
    required this.onAddProduct,
  }) : super(key: key);

  @override
  _MultiProductSelectionPageState createState() =>
      _MultiProductSelectionPageState();
}

class _MultiProductSelectionPageState extends State<MultiProductSelectionPage> {
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

  @override
  Widget build(BuildContext context) {
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
        backgroundColor: primaryColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Container(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        padding: const EdgeInsets.only(left: 12,right: 12,top: 12),
        child: Column(
          children: [
            // Search bar
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
            // Product list
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
                              bottom: 12, ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Transform.scale(
                                      scale: 1.0,
                                      child: Checkbox(
                                        value: selectedProducts[product.id] ??
                                            false,
                                        activeColor: primaryColor,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        materialTapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                        visualDensity: VisualDensity.compact,
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
                                        borderRadius: BorderRadius.circular(8),
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
                                                errorBuilder: (context, error,
                                                    stackTrace) {
                                                  log("Failed to load image for product ${product.name}: $error");
                                                  return Icon(
                                                    Icons.inventory_2_rounded,
                                                    color: primaryColor,
                                                    size: 24,
                                                  );
                                                },
                                              )
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
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          Wrap(
                                            spacing: 6,
                                            runSpacing: 4,
                                            children: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.grey[100],
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  "SL: ${product.defaultCode ?? 'N/A'}",
                                                  style: TextStyle(
                                                    color: Colors.grey[700],
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 2),
                                                decoration: BoxDecoration(
                                                  color:
                                                      product.vanInventory > 0
                                                          ? Colors.green[50]
                                                          : Colors.red[50],
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  "${product.vanInventory} in stock",
                                                  style: TextStyle(
                                                    color:
                                                        product.vanInventory > 0
                                                            ? Colors.green[700]
                                                            : Colors.red[700],
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w500,
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
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                            color: Colors.grey[200]!),
                                        borderRadius: BorderRadius.circular(8),
                                        color: Colors.grey[200],
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Material(
                                            color: Colors.transparent,
                                            child: InkWell(
                                              borderRadius:
                                                  const BorderRadius.only(
                                                topLeft: Radius.circular(7),
                                                bottomLeft: Radius.circular(7),
                                              ),
                                              onTap: () {
                                                setState(() {
                                                  if (quantities[product.id]! >
                                                      1) {
                                                    quantities[product.id] =
                                                        quantities[
                                                                product.id]! -
                                                            1;
                                                  }
                                                });
                                              },
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.all(6),
                                                child: Icon(
                                                  Icons.remove_rounded,
                                                  size: 16,
                                                  color:
                                                      quantities[product.id]! >
                                                              1
                                                          ? primaryColor
                                                          : Colors.grey[600],
                                                ),
                                              ),
                                            ),
                                          ),
                                          Container(
                                            constraints: const BoxConstraints(
                                                minWidth: 24),
                                            alignment: Alignment.center,
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 4),
                                            child: Text(
                                              '${quantities[product.id]}',
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          Material(
                                            color: Colors.transparent,
                                            child: InkWell(
                                              borderRadius:
                                                  const BorderRadius.only(
                                                topRight: Radius.circular(7),
                                                bottomRight: Radius.circular(7),
                                              ),
                                              onTap: () {
                                                setState(() {
                                                  quantities[product.id] =
                                                      quantities[product.id]! +
                                                          1;
                                                });
                                              },
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.all(6),
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
            // const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: primaryColor,
                        // Red text to match the ElevatedButton
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        // Match ElevatedButton
                        minimumSize: const Size(0, 40),
                        // Already matches
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(kBorderRadius),
                          side: const BorderSide(
                            color: primaryColor, // Red border
                            width: 1,
                          ),
                        ),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        // Red background (unchanged)
                        foregroundColor: Colors.white,
                        // White text (unchanged)
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        // Same as TextButton
                        minimumSize: const Size(0, 40),
                        // Already matches
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(kBorderRadius),
                        ),
                      ),
                      onPressed: () {
                        bool hasSelection =
                            selectedProducts.values.any((selected) => selected);
                        if (!hasSelection) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text(
                                  'Please select at least one product'),
                              backgroundColor: Colors.red,
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(kBorderRadius),
                              ),
                              behavior: SnackBarBehavior.floating,
                              margin: const EdgeInsets.all(16),
                            ),
                          );
                          return;
                        }
                        selectedProducts.forEach((productId, isSelected) {
                          if (isSelected) {
                            final product = widget.availableProducts
                                .firstWhere((p) => p.id == productId);
                            widget.onAddProduct(
                                product, quantities[productId]!);
                          }
                        });
                        Navigator.of(context).pop();
                      },
                      child: const Text(
                        'Add Selected',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight
                              .w600, // Match the weight for consistency
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
    );
  }
}
