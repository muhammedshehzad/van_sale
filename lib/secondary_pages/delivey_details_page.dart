import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:van_sale_applicatioin/provider_and_models/order_picking_provider.dart';
import 'package:van_sale_applicatioin/provider_and_models/sale_order_detail_provider.dart';
import 'dart:convert';
import '../provider_and_models/cyllo_session_model.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';

late List<CameraDescription> cameras;

Future<void> initializeCameras() async {
  cameras = await availableCameras();
}

class DeliveryDetailsPage extends StatefulWidget {
  final Map<String, dynamic> pickingData;
  final SaleOrderDetailProvider provider;

  const DeliveryDetailsPage({
    Key? key,
    required this.pickingData,
    required this.provider,
  }) : super(key: key);

  @override
  State<DeliveryDetailsPage> createState() => _DeliveryDetailsPageState();
}

class _DeliveryDetailsPageState extends State<DeliveryDetailsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _signature;
  List<String> _deliveryPhotos = [];
  final TextEditingController _noteController = TextEditingController();
  bool _isLoading = false;
  late Future<Map<String, dynamic>> _deliveryDetailsFuture; // Cache the Future

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _deliveryDetailsFuture = _fetchDeliveryDetails(context); // Initialize once
  }

  @override
  void dispose() {
    _tabController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _fetchDeliveryDetails(BuildContext context) async {
    debugPrint('Starting _fetchDeliveryDetails for pickingId: ${widget.pickingData['id']}');
    try {
      final client = await SessionManager.getActiveClient();
      if (client == null) {
        debugPrint('Error: No active Odoo session found.');
        throw Exception('No active Odoo session found.');
      }

      final pickingId = widget.pickingData['id'] as int;

      // Fetch stock.move.line
      debugPrint('Fetching stock.move.line for pickingId: $pickingId');
      final moveLinesResult = await client.callKw({
        'model': 'stock.move.line',
        'method': 'search_read',
        'args': [
          [['picking_id', '=', pickingId]],
          ['id', 'product_id', 'quantity', 'move_id', 'product_uom_id', 'lot_id', 'lot_name'],
        ],
        'kwargs': {},
      });
      debugPrint('Move lines result: $moveLinesResult');
      final moveLines = List<Map<String, dynamic>>.from(moveLinesResult);

      // Fetch stock.move
      final moveIds = moveLines.map((line) => (line['move_id'] as List)[0] as int).toList();
      debugPrint('Fetching stock.move for moveIds: $moveIds');
      final moveResult = await client.callKw({
        'model': 'stock.move',
        'method': 'search_read',
        'args': [
          [['id', 'in', moveIds]],
          ['id', 'product_id', 'product_uom_qty', 'price_unit', 'sale_line_id'],
        ],
        'kwargs': {},
      });
      debugPrint('Move result: $moveResult');
      final moveMap = {for (var move in moveResult) move['id'] as int: move};

      // Fetch sale order
      debugPrint('Fetching stock.picking for pickingId: $pickingId');
      final pickingResult = await client.callKw({
        'model': 'stock.picking',
        'method': 'search_read',
        'args': [
          [['id', '=', pickingId]],
          ['origin'],
        ],
        'kwargs': {},
      });
      final picking = pickingResult[0] as Map<String, dynamic>;
      final saleOrderName = picking['origin'] != false ? picking['origin'] as String : null;

      Map<int, double> salePriceMap = {};
      if (saleOrderName != null) {
        debugPrint('Fetching sale.order for name: $saleOrderName');
        final saleOrderResult = await client.callKw({
          'model': 'sale.order',
          'method': 'search_read',
          'args': [
            [['name', '=', saleOrderName]],
            ['id'],
          ],
          'kwargs': {},
        });
        debugPrint('Sale order result: $saleOrderResult');
        if (saleOrderResult.isNotEmpty) {
          final saleOrderId = saleOrderResult[0]['id'] as int;
          debugPrint('Fetching sale.order.line for saleOrderId: $saleOrderId');
          final saleLineResult = await client.callKw({
            'model': 'sale.order.line',
            'method': 'search_read',
            'args': [
              [['order_id', '=', saleOrderId]],
              ['product_id', 'price_unit'],
            ],
            'kwargs': {},
          });
          debugPrint('Sale order line result: $saleLineResult');
          salePriceMap = {
            for (var line in saleLineResult)
              (line['product_id'] as List)[0] as int: line['price_unit'] as double
          };
        }
      }

      // Update moveLines with ordered_qty and price_unit
      for (var line in moveLines) {
        final moveId = (line['move_id'] as List)[0] as int;
        final move = moveMap[moveId];
        line['ordered_qty'] = move?['product_uom_qty'] as double? ?? 0.0;
        final productId = (line['product_id'] as List)[0] as int;
        line['price_unit'] = salePriceMap[productId] ?? move?['price_unit'] as double? ?? 0.0;
      }

      // Fetch product.product
      final productIds = moveLines.map((line) => (line['product_id'] as List)[0] as int).toSet().toList();
      debugPrint('Fetching product.product for productIds: $productIds');
      final productResult = await client.callKw({
        'model': 'product.product',
        'method': 'search_read',
        'args': [
          [['id', 'in', productIds]],
          ['id', 'name', 'default_code', 'barcode', 'image_128', 'categ_id', 'list_price'],
        ],
        'kwargs': {},
      });
      debugPrint('Product result: $productResult');
      final productMap = {for (var product in productResult) product['id'] as int: product};

      for (var line in moveLines) {
        final productId = (line['product_id'] as List)[0] as int;
        final product = productMap[productId];
        if (product != null) {
          line['product_code'] = product['default_code'] ?? '';
          line['product_barcode'] = product['barcode'] ?? '';
          line['product_image'] = product['image_128'];
          line['product_category'] = product['categ_id'] != false ? (product['categ_id'] as List)[1] as String : '';
          if (line['price_unit'] == 0.0) {
            line['price_unit'] = product['list_price'] as double? ?? 0.0;
          }
        }
      }

      // Fetch uom.uom
      final uomIds = moveLines.map((line) => (line['product_uom_id'] as List)[0] as int).toSet().toList();
      debugPrint('Fetching uom.uom for uomIds: $uomIds');
      final uomResult = await client.callKw({
        'model': 'uom.uom',
        'method': 'search_read',
        'args': [
          [['id', 'in', uomIds]],
          ['id', 'name', 'category_id'],
        ],
        'kwargs': {},
      });
      debugPrint('UoM result: $uomResult');
      final uomMap = {for (var uom in uomResult) uom['id'] as int: uom};

      for (var line in moveLines) {
        if (line['product_uom_id'] != false) {
          final uomId = (line['product_uom_id'] as List)[0] as int;
          final uom = uomMap[uomId];
          line['uom_name'] = uom?['name'] as String? ?? 'Units';
        } else {
          line['uom_name'] = 'Units';
        }
      }

      // Fetch stock.picking
      debugPrint('Fetching stock.picking for pickingId: $pickingId');
      final pickingResults = await client.callKw({
        'model': 'stock.picking',
        'method': 'search_read',
        'args': [
          [['id', '=', pickingId]],
          ['id', 'name', 'state', 'scheduled_date', 'date_done', 'partner_id', 'location_id', 'location_dest_id', 'origin', 'carrier_id', 'weight', 'note', 'picking_type_id', 'company_id', 'user_id'],
        ],
        'kwargs': {},
      });
      debugPrint('Picking result: $pickingResults');
      if (pickingResults.isEmpty) {
        debugPrint('Error: Picking not found');
        throw Exception('Picking not found');
      }
      final pickingDetail = pickingResults[0] as Map<String, dynamic>;

      // Fetch partner
      Map<String, dynamic>? partnerAddress;
      if (pickingDetail['partner_id'] != false) {
        final partnerId = (pickingDetail['partner_id'] as List)[0] as int;
        debugPrint('Fetching res.partner for partnerId: $partnerId');
        final partnerResult = await client.callKw({
          'model': 'res.partner',
          'method': 'search_read',
          'args': [
            [['id', '=', partnerId]],
            ['id', 'name', 'street', 'street2', 'city', 'state_id', 'country_id', 'zip', 'phone', 'email'],
          ],
          'kwargs': {},
        });
        debugPrint('Partner result: $partnerResult');
        if (partnerResult.isNotEmpty) {
          partnerAddress = partnerResult[0] as Map<String, dynamic>;
        }
      }

      // Fetch status history
      debugPrint('Fetching mail.message for pickingId: $pickingId');
      final statusHistoryResult = await client.callKw({
        'model': 'mail.message',
        'method': 'search_read',
        'args': [
          [['model', '=', 'stock.picking'], ['res_id', '=', pickingId]],
          ['id', 'date', 'body', 'author_id'],
        ],
        'kwargs': {'order': 'date desc', 'limit': 10},
      });
      debugPrint('Status history result: $statusHistoryResult');
      final statusHistory = List<Map<String, dynamic>>.from(statusHistoryResult);

      // Calculate totals
      final totalPicked = moveLines.fold(0.0, (sum, line) => sum + (line['quantity'] as double? ?? 0.0));
      final totalOrdered = moveLines.fold(0.0, (sum, line) => sum + (line['ordered_qty'] as double));
      final totalValue = moveLines.fold(
          0.0,
              (sum, line) => sum + ((line['price_unit'] as double) * (line['quantity'] as double? ?? 0.0)));

      // Log final data for verification
      debugPrint('Final moveLines after updates: $moveLines');
      debugPrint('Calculated totalValue: $totalValue');

      debugPrint('Data fetched successfully: moveLines: ${moveLines.length}, totalPicked: $totalPicked');
      return {
        'moveLines': moveLines,
        'totalPicked': totalPicked,
        'totalOrdered': totalOrdered,
        'totalValue': totalValue,
        'pickingDetail': pickingDetail,
        'partnerAddress': partnerAddress,
        'statusHistory': statusHistory,
      };
    } catch (e) {
      debugPrint('Error in _fetchDeliveryDetails: $e');
      rethrow;
    } finally {
      debugPrint('_fetchDeliveryDetails completed');
    }
  }
  Future<void> _submitDelivery(BuildContext context, int pickingId) async {
    try {
      setState(() {
        _isLoading = true;
      });

      final client = await SessionManager.getActiveClient();
      if (client == null) {
        throw Exception('No active Odoo session found.');
      }
      print('Odoo client initialized successfully');

      // Upload signature and photos as attachments
      List<int> attachmentIds = [];
      if (_signature != null) {
        print('Uploading signature...');
        final signatureAttachment = await client.callKw({
          'model': 'ir.attachment',
          'method': 'create',
          'args': [
            {
              'name':
                  'Delivery Signature - ${DateTime.now().toIso8601String()}',
              'datas': _signature,
              'res_model': 'stock.picking',
              'res_id': pickingId,
              'mimetype': 'image/png',
            }
          ],
          'kwargs': {},
        });
        attachmentIds.add(signatureAttachment as int);
        print('Signature uploaded, ID: $signatureAttachment');
      }

      for (var i = 0; i < _deliveryPhotos.length; i++) {
        print('Uploading photo ${i + 1}...');
        final photoAttachment = await client.callKw({
          'model': 'ir.attachment',
          'method': 'create',
          'args': [
            {
              'name':
                  'Delivery Photo ${i + 1} - ${DateTime.now().toIso8601String()}',
              'datas': _deliveryPhotos[i],
              'res_model': 'stock.picking',
              'res_id': pickingId,
              'mimetype': 'image/jpeg',
            }
          ],
          'kwargs': {},
        });
        attachmentIds.add(photoAttachment as int);
        print('Photo ${i + 1} uploaded, ID: $photoAttachment');
      }

      // Post a message to the chatter with note and attachments
      if (_noteController.text.isNotEmpty || attachmentIds.isNotEmpty) {
        print('Posting message to picking with note and attachments...');
        final messageBody = _noteController.text.isNotEmpty
            ? _noteController.text
            : 'Delivery confirmed with attachments';
        await client.callKw({
          'model': 'stock.picking',
          'method': 'message_post',
          'args': [
            [pickingId]
          ],
          'kwargs': {
            'body': messageBody,
            'attachment_ids': attachmentIds,
            'message_type': 'comment',
            'subtype_id': 1,
          },
        });
        print('Message posted successfully');
      }

      // Check picking state
      print('Fetching picking state...');
      final pickingStateResult = await client.callKw({
        'model': 'stock.picking',
        'method': 'search_read',
        'args': [
          [
            ['id', '=', pickingId]
          ],
          ['state'],
        ],
        'kwargs': {},
      });
      final currentState = pickingStateResult[0]['state'] as String;
      print('Picking state before validation: $currentState');
      if (currentState != 'assigned') {
        if (currentState == 'confirmed') {
          print('Attempting to assign picking...');
          await client.callKw({
            'model': 'stock.picking',
            'method': 'action_assign',
            'args': [
              [pickingId]
            ],
            'kwargs': {},
          });
          print('Picking assigned');
          final newStateResult = await client.callKw({
            'model': 'stock.picking',
            'method': 'search_read',
            'args': [
              [
                ['id', '=', pickingId]
              ],
              ['state'],
            ],
            'kwargs': {},
          });
          final newState = newStateResult[0]['state'] as String;
          print('New picking state: $newState');
          if (newState != 'assigned') {
            throw Exception(
                'Failed to move picking to "Assigned" state. Current state: $newState');
          }
        } else {
          throw Exception(
              'Picking must be in "Assigned" state to validate. Current state: $currentState');
        }
      }

      // Update quantities in stock.move.line (using standard fields)
      print('Fetching move lines...');
      final moveLines = await client.callKw({
        'model': 'stock.move.line',
        'method': 'search_read',
        'args': [
          [
            ['picking_id', '=', pickingId]
          ],
          ['id', 'qty_done', 'product_id', 'state'], // Minimal standard fields
        ],
        'kwargs': {},
      });
      print('Move lines fetched: $moveLines');

      // Fetch stock.move to get demanded quantities
      final moveIds = moveLines
          .map((line) => line['move_id'] is List ? line['move_id'][0] : null)
          .where((id) => id != null)
          .toList();
      final stockMoves = moveIds.isNotEmpty
          ? await client.callKw({
              'model': 'stock.move',
              'method': 'search_read',
              'args': [
                [
                  ['id', 'in', moveIds]
                ],
                ['id', 'product_uom_qty'],
              ],
              'kwargs': {},
            })
          : [];
      final moveQtyMap = {
        for (var move in stockMoves) move['id']: move['product_uom_qty']
      };

      for (var line in moveLines) {
        final currentQtyDone = (line['qty_done'] as num?)?.toDouble() ?? 0.0;
        final moveId = line['move_id'] is List ? line['move_id'][0] : null;
        final demandedQty = moveId != null
            ? (moveQtyMap[moveId] as num?)?.toDouble() ?? 0.0
            : 0.0;
        final productId =
            line['product_id'] is List ? line['product_id'][1] : 'Unknown';
        print(
            'Line ${line['id']} ($productId): qty_done=$currentQtyDone, demanded=$demandedQty');

        if (currentQtyDone == 0.0 && demandedQty > 0.0) {
          print('Updating qty_done for line ${line['id']} to $demandedQty');
          await client.callKw({
            'model': 'stock.move.line',
            'method': 'write',
            'args': [
              [line['id']],
              {'qty_done': demandedQty},
            ],
            'kwargs': {},
          });
          print('Updated qty_done for line ${line['id']}');
        } else if (currentQtyDone == 0.0 && demandedQty == 0.0) {
          throw Exception(
              'No quantity set for line ${line['id']} ($productId). Cannot validate picking.');
        }
      }

      // Validate the picking
      print('Validating picking $pickingId...');
      await client.callKw({
        'model': 'stock.picking',
        'method': 'button_validate',
        'args': [
          [pickingId]
        ],
        'kwargs': {},
      });
      print('Picking validated successfully');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Delivery confirmed successfully')),
      );

      Navigator.pop(context, true);
    } catch (e) {
      print('Submission error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _captureSignature() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SignaturePad(
          title: 'Delivery Signature',
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _signature = result;
      });
    }
  }

  Future<void> _capturePhoto() async {
    final status = await Permission.camera.request();
    if (status.isGranted) {
      try {
        if (cameras.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No cameras available')),
          );
          return;
        }
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CameraScreen(camera: cameras.first),
          ),
        );
        if (result != null) {
          final base64Image = base64Encode(result);
          setState(() {
            _deliveryPhotos.add(base64Image);
          });
        }
      } catch (e) {
        print('Error capturing photo: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error capturing photo: $e')),
        );
      }
    } else if (status.isDenied || status.isPermanentlyDenied) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Camera permission is required to take photos.'),
          action: SnackBarAction(
            label: 'Settings',
            onPressed: () => openAppSettings(),
          ),
        ),
      );
    }
  }

  Widget _buildDeliveryStatusChip(String state) {
    return Chip(
      label: Text(widget.provider.formatPickingState(state)),
      backgroundColor:
          widget.provider.getPickingStatusColor(state).withOpacity(0.2),
      labelStyle:
          TextStyle(color: widget.provider.getPickingStatusColor(state)),
    );
  }

  String _formatAddress(Map<String, dynamic> address) {
    final parts = [
      address['name'],
      address['street'],
      address['street2'],
      '${address['city']}${address['state_id'] != false ? ', ${(address['state_id'] as List)[1]}' : ''}',
      '${address['zip']}',
      address['country_id'] != false
          ? (address['country_id'] as List)[1] as String
          : '',
    ];

    return parts
        .where((part) =>
            part != null && part != false && part.toString().isNotEmpty)
        .join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final pickingName = widget.pickingData['name'] as String;

    return Scaffold(
      appBar: AppBar(
        title: Text(pickingName, style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFFA12424),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Details', icon: Icon(Icons.info_outline)),
            Tab(text: 'Products', icon: Icon(Icons.inventory_2_outlined)),
            Tab(text: 'Confirmation', icon: Icon(Icons.check_circle_outline)),
          ],
        ),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _deliveryDetailsFuture, // Use the cached Future
        builder: (context, snapshot) {
          debugPrint('FutureBuilder state: ${snapshot.connectionState}, '
              'hasData: ${snapshot.hasData}, '
              'hasError: ${snapshot.hasError}, '
              'data: ${snapshot.data != null ? "present" : "null"}');
          if (snapshot.connectionState == ConnectionState.waiting) {
            debugPrint('FutureBuilder: Waiting for data');
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            debugPrint('FutureBuilder error: ${snapshot.error}');
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Error: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _deliveryDetailsFuture =
                            _fetchDeliveryDetails(context); // Retry
                      });
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }
          if (!snapshot.hasData) {
            debugPrint('FutureBuilder: No data returned');
            return const Center(child: Text('No data available'));
          }

          debugPrint('FutureBuilder: Data loaded successfully');
          final data = snapshot.data!;
          final moveLines = data['moveLines'] as List<Map<String, dynamic>>;
          final totalPicked = data['totalPicked'] as double;
          final totalOrdered = data['totalOrdered'] as double;
          final totalValue = data['totalValue'] as double;
          final pickingDetail = data['pickingDetail'] as Map<String, dynamic>;
          final partnerAddress =
              data['partnerAddress'] as Map<String, dynamic>?;
          final statusHistory =
              data['statusHistory'] as List<Map<String, dynamic>>;

          final pickingState = pickingDetail['state'] as String;
          final scheduledDate = pickingDetail['scheduled_date'] != false
              ? DateTime.parse(pickingDetail['scheduled_date'] as String)
              : null;
          final dateCompleted = pickingDetail['date_done'] != false
              ? DateTime.parse(pickingDetail['date_done'] as String)
              : null;

          return TabBarView(
            controller: _tabController,
            children: [
              // Details Tab
              SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Delivery Status',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[800],
                                  ),
                                ),
                                _buildDeliveryStatusChip(pickingState),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Reference Information',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[700],
                              ),
                            ),
                            const Divider(),
                            _buildInfoRow(Icons.confirmation_number_outlined,
                                'Delivery Reference', pickingName),
                            if (pickingDetail['origin'] != false)
                              _buildInfoRow(
                                  Icons.source_outlined,
                                  'Source Document',
                                  pickingDetail['origin'] as String),
                            if (pickingDetail['user_id'] != false)
                              _buildInfoRow(
                                  Icons.person_outline,
                                  'Responsible',
                                  (pickingDetail['user_id'] as List)[1]
                                      as String),
                            const SizedBox(height: 16),
                            Text(
                              'Delivery Schedule',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[700],
                              ),
                            ),
                            const Divider(),
                            if (scheduledDate != null)
                              _buildInfoRow(
                                  Icons.calendar_today,
                                  'Scheduled Date',
                                  DateFormat('yyyy-MM-dd HH:mm')
                                      .format(scheduledDate)),
                            if (dateCompleted != null)
                              _buildInfoRow(
                                  Icons.check_circle_outline,
                                  'Completed Date',
                                  DateFormat('yyyy-MM-dd HH:mm')
                                      .format(dateCompleted)),
                            const SizedBox(height: 16),
                            Text(
                              'Location Information',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[700],
                              ),
                            ),
                            const Divider(),
                            if (pickingDetail['location_id'] != false)
                              _buildInfoRow(
                                  Icons.location_on_outlined,
                                  'Source Location',
                                  (pickingDetail['location_id'] as List)[1]
                                      as String),
                            if (pickingDetail['location_dest_id'] != false)
                              _buildInfoRow(
                                  Icons.pin_drop_outlined,
                                  'Destination Location',
                                  (pickingDetail['location_dest_id'] as List)[1]
                                      as String),
                            if (partnerAddress != null) ...[
                              const SizedBox(height: 16),
                              Text(
                                'Customer Information',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[700],
                                ),
                              ),
                              const Divider(),
                              _buildInfoRow(
                                  Icons.business_outlined,
                                  'Customer',
                                  (pickingDetail['partner_id'] as List)[1]
                                      as String),
                              _buildInfoRow(Icons.location_city_outlined,
                                  'Address', _formatAddress(partnerAddress)),
                              if (partnerAddress['phone'] != false)
                                _buildInfoRow(Icons.phone_outlined, 'Phone',
                                    partnerAddress['phone'] as String),
                              if (partnerAddress['email'] != false)
                                _buildInfoRow(Icons.email_outlined, 'Email',
                                    partnerAddress['email'] as String),
                            ],
                            if (pickingDetail['carrier_id'] != false ||
                                pickingDetail['weight'] != false) ...[
                              const SizedBox(height: 16),
                              Text(
                                'Shipping Information',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[700],
                                ),
                              ),
                              const Divider(),
                              if (pickingDetail['carrier_id'] != false)
                                _buildInfoRow(
                                    Icons.local_shipping_outlined,
                                    'Carrier',
                                    (pickingDetail['carrier_id'] as List)[1]
                                        as String),
                              if (pickingDetail['weight'] != false)
                                _buildInfoRow(Icons.scale_outlined, 'Weight',
                                    '${pickingDetail['weight']} kg'),
                            ],
                            const SizedBox(height: 16),
                            Text(
                              'Progress',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[700],
                              ),
                            ),
                            const Divider(),
                            const SizedBox(height: 8),
                            LinearProgressIndicator(
                              value: totalOrdered > 0
                                  ? (totalPicked / totalOrdered).clamp(0.0, 1.0)
                                  : 0.0,
                              backgroundColor: Colors.grey[300],
                              color: Colors.green,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Picked: ${totalPicked.toStringAsFixed(2)} / ${totalOrdered.toStringAsFixed(2)}',
                                  style: TextStyle(color: Colors.grey[700]),
                                ),
                                Text(
                                  'Completion: ${totalOrdered > 0 ? ((totalPicked / totalOrdered) * 100).toStringAsFixed(0) : "0"}%',
                                  style: const TextStyle(
                                      color: Colors.green,
                                      fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            if (pickingDetail['note'] != false) ...[
                              const SizedBox(height: 16),
                              Text(
                                'Notes',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[700],
                                ),
                              ),
                              const Divider(),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(pickingDetail['note'] as String),
                              ),
                            ],
                            if (statusHistory.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              Text(
                                'Activity History',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[700],
                                ),
                              ),
                              const Divider(),
                              TimelineWidget(
                                events: statusHistory.map((event) {
                                  final date =
                                      DateTime.parse(event['date'] as String);
                                  final authorName = event['author_id'] != false
                                      ? (event['author_id'] as List)[1]
                                          as String
                                      : 'System';
                                  return {
                                    'date': date,
                                    'title': authorName,
                                    'description': event['body'] as String,
                                  };
                                }).toList(),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Products Tab
              SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Products Summary',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[800],
                                  ),
                                ),
                                Text(
                                  '${moveLines.length} items',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Divider(),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Total Ordered',
                                    style: TextStyle(color: Colors.grey[700])),
                                Text(
                                  totalOrdered.toStringAsFixed(2),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Total Picked',
                                    style: TextStyle(color: Colors.grey[700])),
                                Text(
                                  totalPicked.toStringAsFixed(2),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: totalPicked >= totalOrdered
                                        ? Colors.green
                                        : Colors.red,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Total Value',
                                    style: TextStyle(color: Colors.grey[700])),
                                Text(
                                  '\$${totalValue.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Product Details',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800]),
                    ),
                    const SizedBox(height: 8),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: moveLines.length,
                      itemBuilder: (context, index) {
                        final line = moveLines[index];
                        debugPrint('Line $index: $line');

                        // Safely handle product_id
                        final productId = line['product_id'];
                        if (productId is! List) {
                          debugPrint('Error: product_id is not a List, it is ${productId.runtimeType} with value $productId');
                          return const ListTile(title: Text('Invalid product data'));
                        }
                        final productName = (productId as List).length > 1 ? productId[1] as String : 'Unknown Product';
                        debugPrint('productName for line $index: $productName (type: ${productName.runtimeType})');

                        // Safely handle quantity
                        final pickedQty = line['quantity'] as double? ?? 0.0;
                        debugPrint('pickedQty for line $index: $pickedQty (type: ${pickedQty.runtimeType})');

                        // Safely handle ordered_qty
                        final orderedQty = line['ordered_qty'] as double? ?? 0.0;
                        debugPrint('orderedQty for line $index: $orderedQty (type: ${orderedQty.runtimeType})');

                        // Safely handle product_code
                        final productCode = line['product_code'] is String ? line['product_code'] as String : '';
                        debugPrint('productCode for line $index: $productCode (type: ${productCode.runtimeType})');

                        // Safely handle product_barcode
                        final productBarcode = line['product_barcode'] is String ? line['product_barcode'] as String : '';
                        debugPrint('productBarcode for line $index: $productBarcode (type: ${productBarcode.runtimeType})');

                        // Safely handle uom_name
                        final uomName = line['uom_name'] is String ? line['uom_name'] as String : 'Units';
                        debugPrint('uomName for line $index: $uomName (type: ${uomName.runtimeType})');

                        // Safely handle price_unit
                        final priceUnit = line['price_unit'] as double? ?? 0.0;
                        debugPrint('priceUnit for line $index: $priceUnit (type: ${priceUnit.runtimeType})');

                        // Safely handle lot_name
                        final lotName = line['lot_name'] != false && line['lot_name'] is String ? line['lot_name'] as String : null;
                        debugPrint('lotName for line $index: $lotName (type: ${lotName?.runtimeType ?? 'null'})');

                        // Safely handle product_image
                        final productImage = line['product_image'];
                        Widget imageWidget;
                        if (productImage != null && productImage != false && productImage is String) {
                          try {
                            imageWidget = Image.memory(
                              base64Decode(productImage as String),
                              fit: BoxFit.cover,
                            );
                          } catch (e) {
                            debugPrint('Error decoding productImage for line $index: $e');
                            imageWidget = Icon(Icons.inventory_2, color: Colors.grey[400], size: 30);
                          }
                        } else {
                          imageWidget = Icon(Icons.inventory_2, color: Colors.grey[400], size: 30);
                        }

                        final lineValue = priceUnit * pickedQty;
                        debugPrint('lineValue for line $index: $lineValue');

                        return Card(
                          elevation: 1,
                          margin: const EdgeInsets.only(bottom: 12), // Fix typo: should be 'bottom'
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 60,
                                      height: 60,
                                      decoration: BoxDecoration(
                                        color: Colors.grey[200],
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: imageWidget,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            productName,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          if (productCode.isNotEmpty)
                                            Text(
                                              'SKU: $productCode',
                                              style: TextStyle(color: Colors.grey[700], fontSize: 13),
                                            ),
                                          if (productBarcode.isNotEmpty)
                                            Text(
                                              'Barcode: $productBarcode',
                                              style: TextStyle(color: Colors.grey[700], fontSize: 13),
                                            ),
                                          if (lotName != null)
                                            Text(
                                              'Lot: $lotName',
                                              style: TextStyle(color: Colors.grey[700], fontSize: 13),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(height: 24),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Ordered',
                                            style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                          ),
                                          Text(
                                            '${orderedQty.toStringAsFixed(2)} $uomName',
                                            style: const TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Picked',
                                            style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                          ),
                                          Text(
                                            '${pickedQty.toStringAsFixed(2)} $uomName',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: pickedQty >= orderedQty ? Colors.green : Colors.orange,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            'Value',
                                            style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                          ),
                                          Text(
                                            '\$${lineValue.toStringAsFixed(2)}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                LinearProgressIndicator(
                                  value: orderedQty > 0 ? (pickedQty / orderedQty).clamp(0.0, 1.0) : 0.0,
                                  backgroundColor: Colors.grey[200],
                                  color: pickedQty >= orderedQty ? Colors.green : Colors.orange,
                                  minHeight: 5,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${orderedQty > 0 ? ((pickedQty / orderedQty) * 100).toStringAsFixed(0) : 0}% complete',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: pickedQty >= orderedQty ? Colors.green : Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              // Confirmation Tab
              SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Delivery Confirmation',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[800],
                              ),
                            ),
                            const SizedBox(height: 16),
                            if (pickingState == 'done') ...[
                              const Icon(
                                Icons.check_circle,
                                color: Colors.green,
                                size: 48,
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'This delivery has been completed and confirmed.',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.green,
                                ),
                              ),
                              if (dateCompleted != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'Completed on: ${DateFormat('yyyy-MM-dd HH:mm').format(dateCompleted)}',
                                  style: TextStyle(color: Colors.grey[700]),
                                ),
                              ],
                            ] else ...[
                              const Text(
                                'Please capture the following information to confirm delivery:',
                                style: TextStyle(fontSize: 14),
                              ),
                              const SizedBox(height: 16),

                              // Signature Section
                              Text(
                                'Customer Signature',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[800],
                                ),
                              ),
                              const SizedBox(height: 8),

                              _signature == null
                                  ? ElevatedButton.icon(
                                      onPressed: _captureSignature,
                                      icon: const Icon(
                                        Icons.draw,
                                        color: Colors.white,
                                      ),
                                      label: const Text('Capture Signature'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            const Color(0xFFA12424),
                                        foregroundColor: Colors.white,
                                        minimumSize:
                                            const Size(double.infinity, 48),
                                      ),
                                    )
                                  : Stack(
                                      alignment: Alignment.topRight,
                                      children: [
                                        Container(
                                          height: 150,
                                          width: double.infinity,
                                          decoration: BoxDecoration(
                                            border:
                                                Border.all(color: Colors.grey),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Image.memory(
                                            base64Decode(_signature!),
                                            fit: BoxFit.contain,
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.refresh,
                                              color: Colors.grey),
                                          onPressed: () {},
                                        ),
                                      ],
                                    ),

                              const SizedBox(height: 24),

                              // Delivery Photos Section
                              Text(
                                'Delivery Photos',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[800],
                                ),
                              ),
                              const SizedBox(height: 8),

                              ElevatedButton.icon(
                                onPressed: _capturePhoto,
                                icon: const Icon(Icons.camera_alt,
                                    color: Colors.white),
                                label: const Text('Take Photo'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFA12424),
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(double.infinity, 48),
                                ),
                              ),

                              if (_deliveryPhotos.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                SizedBox(
                                  height: 100,
                                  child: ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: _deliveryPhotos.length,
                                    itemBuilder: (context, index) {
                                      return Container(
                                        margin: const EdgeInsets.only(right: 8),
                                        width: 100,
                                        decoration: BoxDecoration(
                                          border:
                                              Border.all(color: Colors.grey),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Stack(
                                          fit: StackFit.expand,
                                          children: [
                                            Image.memory(
                                              base64Decode(
                                                  _deliveryPhotos[index]),
                                              fit: BoxFit.cover,
                                            ),
                                            Positioned(
                                              top: 0,
                                              right: 0,
                                              child: GestureDetector(
                                                onTap: () {
                                                  setState(() {
                                                    _deliveryPhotos
                                                        .removeAt(index);
                                                  });
                                                },
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.all(2),
                                                  decoration:
                                                      const BoxDecoration(
                                                    color: Colors.red,
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: const Icon(
                                                    Icons.close,
                                                    size: 16,
                                                    color: Colors.white,
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

                              const SizedBox(height: 24),

                              // Delivery Notes Section
                              Text(
                                'Delivery Notes',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[800],
                                ),
                              ),
                              const SizedBox(height: 8),

                              TextField(
                                controller: _noteController,
                                maxLines: 4,
                                decoration: InputDecoration(
                                  hintText:
                                      'Add any special notes about this delivery...',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 24),

                              // Confirm Delivery Button
                              ElevatedButton.icon(
                                onPressed: () => _submitDelivery(
                                    context, pickingDetail['id'] as int),
                                icon: const Icon(Icons.check_circle,
                                    color: Colors.white),
                                label: const Text('Confirm Delivery'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(double.infinity, 48),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton.icon(
              onPressed: () {
                // Implement functionality to print delivery slip
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Printing delivery slip...')),
                );
              },
              icon: Icon(
                Icons.print,
                color: Colors.white,
              ),
              label: const Text('Print'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[800],
                foregroundColor: Colors.white,
              ),
            ),
            ElevatedButton.icon(
              onPressed: () {
                // Implement functionality to email delivery slip
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Emailing delivery slip...')),
                );
              },
              icon: const Icon(
                Icons.email,
                color: Colors.white,
              ),
              label: const Text('Email'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
              ),
            ),
            ElevatedButton.icon(
              onPressed: () {
                // Implement functionality to mark as delivered
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Marking as delivered...')),
                );
              },
              icon: const Icon(
                Icons.done_all,
                color: Colors.white,
              ),
              label: const Text('Deliver'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFA12424),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                      color: Colors.grey[700], fontWeight: FontWeight.w500),
                ),
                Text(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.w400),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Simple timeline widget to display status history
class TimelineWidget extends StatelessWidget {
  final List<Map<String, dynamic>> events;

  const TimelineWidget({Key? key, required this.events}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: events.length,
      itemBuilder: (context, index) {
        final event = events[index];
        final date = event['date'] as DateTime;
        final title = event['title'] as String;
        final description = event['description'] as String;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: index == 0 ? Colors.green : Colors.grey[400],
                  ),
                ),
                if (index < events.length - 1)
                  Container(
                    width: 2,
                    height: 50,
                    color: Colors.grey[300],
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat('MMM dd, yyyy - HH:mm').format(date),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description.replaceAll(RegExp(r'<[^>]*>'), ''),
                    // Strip HTML tags
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class SignaturePad extends StatefulWidget {
  final String title;

  const SignaturePad({Key? key, required this.title}) : super(key: key);

  @override
  _SignaturePadState createState() => _SignaturePadState();
}

class _SignaturePadState extends State<SignaturePad> {
  final List<List<Offset>> _strokes = <List<Offset>>[];
  List<Offset> _currentStroke = <Offset>[];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: const Color(0xFFA12424),
        actions: [
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: _clear,
          ),
        ],
      ),
      body: Container(
        color: Colors.white,
        child: GestureDetector(
          onPanStart: (details) {
            setState(() {
              _currentStroke = <Offset>[];
              _currentStroke.add(details.localPosition);
              _strokes.add(_currentStroke);
            });
          },
          onPanUpdate: (details) {
            setState(() {
              _currentStroke.add(details.localPosition);
            });
          },
          child: CustomPaint(
            painter: SignaturePainter(strokes: _strokes),
            size: Size.infinite,
          ),
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.red),
                ),
              ),
              ElevatedButton(
                onPressed: _saveSignature,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFA12424),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Save Signature'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _clear() {
    setState(() {
      _strokes.clear();
    });
  }

  Future<void> _saveSignature() async {
    if (_strokes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign before saving')),
      );
      return;
    }

    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final size = MediaQuery.of(context).size;

      canvas.drawColor(Colors.white, BlendMode.src);

      final paint = Paint()
        ..color = Colors.black
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 5.0;

      for (final stroke in _strokes) {
        for (int i = 0; i < stroke.length - 1; i++) {
          canvas.drawLine(stroke[i], stroke[i + 1], paint);
        }
      }

      final picture = recorder.endRecording();
      final img =
          await picture.toImage(size.width.toInt(), size.height.toInt());
      final pngBytes = await img.toByteData(format: ui.ImageByteFormat.png);

      if (pngBytes != null) {
        final base64Image = base64Encode(Uint8List.view(pngBytes.buffer));
        Navigator.pop(context, base64Image);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving signature: $e')),
      );
    }
  }
}

class SignaturePainter extends CustomPainter {
  final List<List<Offset>> strokes;

  SignaturePainter({required this.strokes});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 5.0;

    for (final stroke in strokes) {
      for (int i = 0; i < stroke.length - 1; i++) {
        if (stroke[i] != Offset.infinite && stroke[i + 1] != Offset.infinite) {
          canvas.drawLine(stroke[i], stroke[i + 1], paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(SignaturePainter oldDelegate) => true;
}

class CameraScreen extends StatefulWidget {
  final CameraDescription camera;

  const CameraScreen({Key? key, required this.camera}) : super(key: key);

  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;

  @override
  void initState() {
    super.initState();
    _controller = CameraController(
      widget.camera,
      ResolutionPreset.medium,
    );
    _initializeControllerFuture = _controller.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Take Photo')),
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return CameraPreview(_controller);
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          try {
            await _initializeControllerFuture;
            final XFile image = await _controller.takePicture();
            final bytes = await image.readAsBytes();
            Navigator.pop(context, bytes);
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: $e')),
            );
          }
        },
        child: const Icon(Icons.camera_alt),
      ),
    );
  }
}
