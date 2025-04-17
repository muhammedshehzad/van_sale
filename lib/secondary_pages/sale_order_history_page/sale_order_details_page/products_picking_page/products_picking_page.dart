import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_barcode_scanner/flutter_barcode_scanner.dart';

import '../../../../authentication/cyllo_session_model.dart';
import '../sale_order_detail_provider.dart';

class PickingPage extends StatefulWidget {
  final Map<String, dynamic> picking;
  final List<Map<String, dynamic>> orderLines;
  final int warehouseId;
  final SaleOrderDetailProvider provider;

  const PickingPage({
    Key? key,
    required this.picking,
    required this.orderLines,
    required this.warehouseId,
    required this.provider,
  }) : super(key: key);

  @override
  _PickingPageState createState() => _PickingPageState();
}

class _PickingPageState extends State<PickingPage> {
  Map<int, double> pickedQuantities = {};
  Map<int, double> stockAvailability = {};
  bool validateImmediately = false;
  bool isProcessing = false;
  bool isScanning = false;
  bool continuousScanning = false;
  String? scanMessage;
  int? selectedProductId;
  List<Map<String, dynamic>> moveLines = [];
  Map<String, Map<String, dynamic>> barcodeToProduct = {};
  bool isFullyPicked = true;
  bool isInitialized = false;
  String? errorMessage;
  Map<int, TextEditingController> quantityControllers = {};
  Map<int, String?> quantityErrors = {};

  @override
  void initState() {
    super.initState();
    _initializePickingData();
  }

  @override
  void dispose() {
    // Dispose of all controllers
    quantityControllers.forEach((_, controller) => controller.dispose());
    super.dispose();
  }

  Future<void> _initializePickingData() async {
    final pickingState = widget.picking['state'] as String;
    if (pickingState == 'done' || pickingState == 'cancel') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('This picking is $pickingState.'),
          backgroundColor: Colors.grey,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context);
      return;
    }

    final client = await SessionManager.getActiveClient();
    if (client == null) {
      setState(() => errorMessage = 'No active Odoo session found.');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No active Odoo session found.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    try {
      final pickingId = widget.picking['id'] as int;

      // Ensure picking is assigned
      if (pickingState != 'assigned') {
        await client.callKw({
          'model': 'stock.picking',
          'method': 'action_assign',
          'args': [pickingId],
          'kwargs': {},
        });
      }

      // Fetch stock.move.line data
      final moveLinesResult = await client.callKw({
        'model': 'stock.move.line',
        'method': 'search_read',
        'args': [
          [['picking_id', '=', pickingId]],
          ['id', 'product_id', 'quantity', 'move_id'],
        ],
        'kwargs': {},
      });

      if (moveLinesResult.isEmpty) {
        setState(() => errorMessage = 'No products found for this picking.');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No products found for this picking.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      moveLines = List<Map<String, dynamic>>.from(moveLinesResult);
      final moveIds = moveLines
          .map((line) => line['move_id'] is List
          ? (line['move_id'] as List)[0] as int
          : line['move_id'] as int)
          .toList();

      // Fetch stock.move data
      final moveResult = await client.callKw({
        'model': 'stock.move',
        'method': 'search_read',
        'args': [
          [['id', 'in', moveIds]],
          ['id', 'product_id', 'product_uom_qty'],
        ],
        'kwargs': {},
      });

      // Fetch product data
      final productIds = moveLines
          .map((line) => (line['product_id'] as List)[0] as int)
          .toSet()
          .toList();
      final productResult = await client.callKw({
        'model': 'product.product',
        'method': 'search_read',
        'args': [
          [['id', 'in', productIds]],
          ['id', 'barcode', 'name'],
        ],
        'kwargs': {},
      });

      barcodeToProduct = {
        for (var product in productResult)
          if (product['barcode'] != null && product['barcode'] is String)
            product['barcode'] as String: {
              'id': product['id'] as int,
              'name': product['name'] as String,
            }
      };

      final moveQtyMap = {
        for (var move in moveResult)
          move['id'] as int: move['product_uom_qty'] as double
      };

      for (var line in moveLines) {
        final moveId = line['move_id'] is List
            ? (line['move_id'] as List)[0] as int
            : line['move_id'] as int;
        line['ordered_qty'] = moveQtyMap[moveId] ?? 0.0;
        final productId = (line['product_id'] as List)[0] as int;
        pickedQuantities[productId] = line['quantity'] as double? ?? 0.0;
        // Initialize controller for each product
        quantityControllers[productId] = TextEditingController(
          text: pickedQuantities[productId]!.toStringAsFixed(2),
        );
      }

      // Fetch stock availability
      stockAvailability = await widget.provider.fetchStockAvailability(
        moveLines.map((move) => {'product_id': move['product_id']}).toList(),
        widget.warehouseId,
      );

      // Check if fully picked
      isFullyPicked = moveLines.every((line) {
        final productId = (line['product_id'] as List)[0] as int;
        final pickedQty = pickedQuantities[productId] ?? 0.0;
        final orderedQty = line['ordered_qty'] as double;
        return pickedQty >= orderedQty;
      });

      setState(() => isInitialized = true);
    } catch (e) {
      setState(() => errorMessage = 'Error initializing picking: $e');
      debugPrint('$e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error initializing picking: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _processScannedBarcode(String barcode) async {
    final client = await SessionManager.getActiveClient();
    if (client == null) {
      setState(() => scanMessage = 'No active Odoo session.');
      return;
    }

    final product = barcodeToProduct[barcode];
    if (product == null) {
      // Attempt to create new move line
      final productResult = await client.callKw({
        'model': 'product.product',
        'method': 'search_read',
        'args': [
          [['barcode', '=', barcode]],
          ['id', 'name'],
        ],
        'kwargs': {},
      });

      if (productResult.isNotEmpty) {
        final newProduct = productResult[0];
        final productId = newProduct['id'] as int;
        final moveLine = await _createMoveLine(productId, newProduct['name']);
        if (moveLine != null) {
          setState(() {
            moveLines.add(moveLine);
            barcodeToProduct[barcode] = {
              'id': productId,
              'name': newProduct['name'],
            };
            selectedProductId = productId;
            pickedQuantities[productId] = 1.0;
            quantityControllers[productId] = TextEditingController(
              text: '1.00',
            );
            // Update stock availability for new product
            widget.provider
                .fetchStockAvailability(
              [{'product_id': [productId, newProduct['name']]}],
              widget.warehouseId,
            )
                .then((avail) {
              setState(() {
                stockAvailability[productId] = avail[productId] ?? 0.0;
              });
            });
            scanMessage = 'New product added: ${newProduct['name']}';
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('New product added: ${newProduct['name']}'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }
      }

      setState(() {
        scanMessage = 'Product not found for barcode: $barcode';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Product not found for barcode: $barcode'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final productId = product['id'] as int;
    final moveLine = moveLines.firstWhere(
          (line) => (line['product_id'] as List)[0] == productId,
      orElse: () => {},
    );
    if (moveLine.isEmpty) {
      setState(() => scanMessage = 'Product not in picking.');
      return;
    }

    final orderedQty = moveLine['ordered_qty'] as double;
    final availableQty = stockAvailability[productId] ?? 0.0;
    final currentQty = pickedQuantities[productId] ?? 0.0;
    final newQty = currentQty + 1;

    if (newQty > min(orderedQty, availableQty)) {
      setState(() {
        scanMessage =
        'Cannot pick more than available (${availableQty.toStringAsFixed(2)}) or ordered (${orderedQty.toStringAsFixed(2)})';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(scanMessage!),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Update move line in Odoo
    await client.callKw({
      'model': 'stock.move.line',
      'method': 'write',
      'args': [
        [moveLine['id']],
        {'quantity': newQty}
      ],
      'kwargs': {},
    });

    setState(() {
      pickedQuantities[productId] = newQty;
      quantityControllers[productId]?.text = newQty.toStringAsFixed(2);
      quantityErrors[productId] = null;
      selectedProductId = productId;
      isFullyPicked = moveLines.every((line) {
        final pid = (line['product_id'] as List)[0] as int;
        return (pickedQuantities[pid] ?? 0.0) >= (line['ordered_qty'] as double);
      });
      scanMessage = 'Scanned: ${product['name']}';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Scanned: ${product['name']}'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _updatePickedQuantity(
      int productId, String value, Map<String, dynamic> moveLine) async {
    final client = await SessionManager.getActiveClient();
    if (client == null) {
      setState(() => scanMessage = 'No active Odoo session.');
      return;
    }

    final orderedQty = moveLine['ordered_qty'] as double;
    final availableQty = stockAvailability[productId] ?? 0.0;
    double? newQty;

    try {
      newQty = double.tryParse(value);
      if (newQty == null || newQty < 0) {
        setState(() {
          quantityErrors[productId] = 'Invalid quantity';
        });
        return;
      }

      if (newQty > min(orderedQty, availableQty)) {
        setState(() {
          quantityErrors[productId] =
          'Cannot exceed available (${availableQty.toStringAsFixed(2)}) or ordered (${orderedQty.toStringAsFixed(2)})';
        });
        return;
      }

      // Update move line in Odoo
      await client.callKw({
        'model': 'stock.move.line',
        'method': 'write',
        'args': [
          [moveLine['id']],
          {'quantity': newQty}
        ],
        'kwargs': {},
      });

      setState(() {
        pickedQuantities[productId] = newQty!;
        quantityErrors[productId] = null;
        selectedProductId = productId;
        isFullyPicked = moveLines.every((line) {
          final pid = (line['product_id'] as List)[0] as int;
          return (pickedQuantities[pid] ?? 0.0) >= (line['ordered_qty'] as double);
        });
      });
    } catch (e) {
      setState(() {
        quantityErrors[productId] = 'Error updating quantity: $e';
      });
    }
  }

  Future<void> _scanBarcode() async {
    if (isScanning) return;
    setState(() {
      isScanning = true;
      scanMessage = null;
    });

    try {
      while (continuousScanning && isScanning) {
        final barcode = await FlutterBarcodeScanner.scanBarcode(
          '#ff6666',
          'Cancel',
          true,
          ScanMode.BARCODE,
        );

        if (barcode == '-1') {
          setState(() {
            scanMessage = 'Scan cancelled';
            isScanning = false;
          });
          break;
        }

        await _processScannedBarcode(barcode);
      }
    } catch (e) {
      setState(() {
        scanMessage = 'Error scanning barcode: $e';
        isScanning = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error scanning barcode: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      setState(() => isScanning = false);
    }
  }

  Future<Map<String, dynamic>?> _createMoveLine(
      int productId, String productName) async {
    final client = await SessionManager.getActiveClient();
    if (client == null) return null;

    // Create stock.move
    final moveId = await client.callKw({
      'model': 'stock.move',
      'method': 'create',
      'args': [
        {
          'picking_id': widget.picking['id'],
          'product_id': productId,
          'product_uom_qty': 1.0,
          'name': productName,
          'location_id': widget.picking['location_id'][0],
          'location_dest_id': widget.picking['location_dest_id'][0],
        }
      ],
      'kwargs': {},
    });

    // Create stock.move.line
    final moveLineId = await client.callKw({
      'model': 'stock.move.line',
      'method': 'create',
      'args': [
        {
          'picking_id': widget.picking['id'],
          'move_id': moveId,
          'product_id': productId,
          'product_uom_qty': 1.0,
          'quantity': 0.0,
        }
      ],
      'kwargs': {},
    });

    return {
      'id': moveLineId,
      'product_id': [productId, productName],
      'move_id': moveId,
      'ordered_qty': 1.0,
      'quantity': 0.0,
    };
  }

  Future<void> _confirmAndValidate() async {
    bool hasPartialQuantities = moveLines.any((line) {
      final productId = (line['product_id'] as List)[0] as int;
      final pickedQty = pickedQuantities[productId] ?? 0.0;
      final orderedQty = line['ordered_qty'] as double;
      return pickedQty < orderedQty && pickedQty > 0;
    });

    bool? createBackorder;
    if (hasPartialQuantities) {
      createBackorder = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Partial Picking'),
          content: const Text(
              'Some products are partially picked. Create a backorder for remaining quantities?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('No, Validate Partial'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Yes, Create Backorder'),
            ),
          ],
        ),
      );

      if (createBackorder == null) return;
    }

    setState(() => isProcessing = true);
    try {
      await widget.provider.confirmPicking(
        widget.picking['id'] as int,
        pickedQuantities,
        validateImmediately,
        createBackorder: createBackorder ?? false,
      );

      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              validateImmediately
                  ? 'Picking validated successfully'
                  : 'Picking saved successfully',
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      setState(() => isProcessing = false);
    }
  }

  Future<Map<int, double>> _fetchStockQuantAvailability(
      dynamic client, List<int> productIds) async {
    final quantResult = await client.callKw({
      'model': 'stock.quant',
      'method': 'search_read',
      'args': [
        [
          ['product_id', 'in', productIds],
          ['location_id', 'child_of', widget.warehouseId]
        ],
        ['product_id', 'quantity', 'reserved_quantity'],
      ],
      'kwargs': {},
    });

    final availability = <int, double>{};
    for (var quant in quantResult) {
      final productId = (quant['product_id'] as List)[0] as int;
      final availableQty =
          (quant['quantity'] as double) - (quant['reserved_quantity'] as double);
      availability[productId] = (availability[productId] ?? 0.0) + availableQty;
    }
    return availability;
  }

  Widget _buildStatIndicator(
      BuildContext context, String label, String value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label: ', style: TextStyle(color: color, fontSize: 12)),
        Text(
          value,
          style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Pick Products for ${widget.picking['name']}'),
        backgroundColor: const Color(0xFFA12424),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: isProcessing ? null : () => Navigator.pop(context),
        ),
      ),
      body: errorMessage != null
          ? Center(child: Text(errorMessage!))
          : !isInitialized
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (isFullyPicked)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle,
                            color: Colors.green, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'All products fully picked.',
                            style: TextStyle(
                              color: Colors.green[700],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (scanMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Text(
                      scanMessage!,
                      style: TextStyle(
                        color: scanMessage!.contains('Error') ||
                            scanMessage!.contains('not found')
                            ? Colors.red
                            : Colors.green,
                        fontSize: 12,
                      ),
                    ),
                  ),
                Expanded(
                  child: moveLines.isEmpty
                      ? const Center(child: Text('No products to pick'))
                      : ListView.separated(
                    itemCount: moveLines.length,
                    separatorBuilder: (context, index) =>
                    const Divider(height: 24),
                    itemBuilder: (context, index) {
                      final moveLine = moveLines[index];
                      final productId = (moveLine['product_id']
                      as List)[0] as int;
                      final productName =
                      (moveLine['product_id'] as List)[1]
                      as String;
                      final orderedQty =
                      moveLine['ordered_qty'] as double;
                      final availableQty =
                          stockAvailability[productId] ?? 0.0;
                      final pickedQty =
                          pickedQuantities[productId] ?? 0.0;
                      final isFullyPickedItem =
                          pickedQty >= orderedQty;
                      final isLowStock =
                          availableQty < orderedQty;
                      final isSelected =
                          selectedProductId == productId;
                      final quantityError =
                      quantityErrors[productId];

                      return Card(
                        elevation: isSelected ? 4 : 0,
                        color: isSelected
                            ? Colors.blue.withOpacity(0.1)
                            : isFullyPickedItem
                            ? Colors.green.withOpacity(0.1)
                            : Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                          BorderRadius.circular(8),
                          side: BorderSide(
                            color: isSelected
                                ? Colors.blue
                                : isFullyPickedItem
                                ? Colors.green
                                .withOpacity(0.5)
                                : isLowStock
                                ? Colors.red
                                .withOpacity(0.5)
                                : Colors.grey
                                .withOpacity(0.0),
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                MainAxisAlignment
                                    .spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      productName,
                                      style: const TextStyle(
                                          fontWeight:
                                          FontWeight.bold),
                                    ),
                                  ),
                                  if (isFullyPickedItem)
                                    Chip(
                                      label:
                                      const Text('Picked'),
                                      backgroundColor: Colors
                                          .green
                                          .withOpacity(0.2),
                                      labelStyle:
                                      const TextStyle(
                                          color:
                                          Colors.green),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 16,
                                runSpacing: 8,
                                children: [
                                  _buildStatIndicator(
                                    context,
                                    'Available',
                                    availableQty
                                        .toStringAsFixed(2),
                                    isLowStock
                                        ? Colors.red[700]!
                                        : Colors.grey[700]!,
                                  ),
                                  _buildStatIndicator(
                                    context,
                                    'Ordered',
                                    orderedQty
                                        .toStringAsFixed(2),
                                    Colors.grey[700]!,
                                  ),
                                  _buildStatIndicator(
                                    context,
                                    'Picked',
                                    pickedQty
                                        .toStringAsFixed(2),
                                    isFullyPickedItem
                                        ? Colors.green[700]!
                                        : Colors.grey[700]!,
                                  ),
                                ],
                              ),
                              if (isLowStock)
                                Padding(
                                  padding:
                                  const EdgeInsets.only(
                                      top: 8.0),
                                  child: Row(
                                    children: [
                                      Icon(
                                          Icons
                                              .warning_amber_rounded,
                                          color:
                                          Colors.red[700],
                                          size: 16),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Low stock: only ${availableQty.toStringAsFixed(2)} available',
                                        style: TextStyle(
                                            color:
                                            Colors.red[700],
                                            fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller:
                                      quantityControllers[
                                      productId],
                                      keyboardType:
                                      TextInputType.number,
                                      decoration:
                                      InputDecoration(
                                        labelText:
                                        'Picked Quantity',
                                        errorText: quantityError,
                                        border:
                                        OutlineInputBorder(),
                                        contentPadding:
                                        EdgeInsets.symmetric(
                                            vertical: 10,
                                            horizontal: 12),
                                      ),
                                      onChanged: (value) =>
                                          _updatePickedQuantity(
                                              productId,
                                              value,
                                              moveLine),
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.remove,
                                        color: Colors.red),
                                    onPressed: pickedQty > 0
                                        ? () {
                                      final newQty =
                                          pickedQty - 1;
                                      quantityControllers[
                                      productId]
                                          ?.text = newQty
                                          .toStringAsFixed(
                                          2);
                                      _updatePickedQuantity(
                                          productId,
                                          newQty
                                              .toString(),
                                          moveLine);
                                    }
                                        : null,
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.add,
                                        color: Colors.green),
                                    onPressed: pickedQty <
                                        min(orderedQty,
                                            availableQty)
                                        ? () {
                                      final newQty =
                                          pickedQty + 1;
                                      quantityControllers[
                                      productId]
                                          ?.text = newQty
                                          .toStringAsFixed(
                                          2);
                                      _updatePickedQuantity(
                                          productId,
                                          newQty
                                              .toString(),
                                          moveLine);
                                    }
                                        : null,
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
                const Divider(height: 24),
                CheckboxListTile(
                  title: const Text('Validate Immediately'),
                  value: validateImmediately,
                  onChanged: isProcessing || isFullyPicked
                      ? null
                      : (value) => setState(
                          () => validateImmediately = value!),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: isProcessing
                          ? null
                          : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                            color: Color(0xFFA12424)),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: Color(0xFFA12424)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: isProcessing || isFullyPicked
                          ? null
                          : () => _confirmAndValidate(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isFullyPicked
                            ? Colors.grey
                            : const Color(0xFFA12424),
                        foregroundColor: Colors.white,
                      ),
                      icon: Icon(
                        validateImmediately
                            ? Icons.check_circle
                            : Icons.save,
                        color: Colors.white,
                      ),
                      label: Text(
                        isFullyPicked
                            ? 'Already Picked'
                            : validateImmediately
                            ? 'Validate Picking'
                            : 'Save Picking',
                      ),
                    ),
                  ],
                ),
                if (isProcessing)
                  const Padding(
                    padding: EdgeInsets.only(top: 16.0),
                    child: LinearProgressIndicator(
                      color: Color(0xFFA12424),
                    ),
                  ),
              ],
            ),
            Positioned(
              right: 0,
              bottom: 130,
              child: FloatingActionButton(
                onPressed:
                isProcessing || isScanning ? null : _scanBarcode,
                backgroundColor: isScanning
                    ? Colors.grey
                    : const Color(0xFFA12424),
                child: Icon(
                  isScanning
                      ? Icons.hourglass_empty
                      : Icons.qr_code_scanner,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}