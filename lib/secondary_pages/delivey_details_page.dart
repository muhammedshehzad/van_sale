import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:van_sale_applicatioin/provider_and_models/order_picking_provider.dart';
import 'package:van_sale_applicatioin/provider_and_models/sale_order_detail_provider.dart';
import 'dart:convert';
import '../provider_and_models/cyllo_session_model.dart';

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

  Future<Map<String, dynamic>> _fetchDeliveryDetails(
      BuildContext context) async {
    debugPrint(
        'Starting _fetchDeliveryDetails for pickingId: ${widget.pickingData['id']}');
    try {
      final client = await SessionManager.getActiveClient();
      if (client == null) {
        debugPrint('Error: No active Odoo session found.');
        throw Exception('No active Odoo session found.');
      }

      final pickingId = widget.pickingData['id'] as int;

      debugPrint('Fetching stock.move.line for pickingId: $pickingId');
      final moveLinesResult = await client.callKw({
        'model': 'stock.move.line',
        'method': 'search_read',
        'args': [
          [
            ['picking_id', '=', pickingId]
          ],
          [
            'id',
            'product_id',
            'quantity',
            'move_id',
            'product_uom_id',
            'lot_id',
            'lot_name'
          ],
        ],
        'kwargs': {},
      });
      debugPrint('Move lines result: $moveLinesResult');
      final moveLines = List<Map<String, dynamic>>.from(moveLinesResult);

      final moveIds =
          moveLines.map((line) => (line['move_id'] as List)[0] as int).toList();
      debugPrint('Fetching stock.move for moveIds: $moveIds');
      final moveResult = await client.callKw({
        'model': 'stock.move',
        'method': 'search_read',
        'args': [
          [
            ['id', 'in', moveIds]
          ],
          ['id', 'product_id', 'product_uom_qty', 'price_unit'],
        ],
        'kwargs': {},
      });
      debugPrint('Move result: $moveResult');
      final moveMap = {for (var move in moveResult) move['id'] as int: move};

      for (var line in moveLines) {
        final moveId = (line['move_id'] as List)[0] as int;
        final move = moveMap[moveId];
        line['ordered_qty'] = move?['product_uom_qty'] as double? ?? 0.0;
        line['price_unit'] = move?['price_unit'] as double? ?? 0.0;
      }

      final productIds = moveLines
          .map((line) => (line['product_id'] as List)[0] as int)
          .toSet()
          .toList();
      debugPrint('Fetching product.product for productIds: $productIds');
      final productResult = await client.callKw({
        'model': 'product.product',
        'method': 'search_read',
        'args': [
          [
            ['id', 'in', productIds]
          ],
          ['id', 'name', 'default_code', 'barcode', 'image_128', 'categ_id'],
        ],
        'kwargs': {},
      });
      debugPrint('Product result: $productResult');
      final productMap = {
        for (var product in productResult) product['id'] as int: product
      };

      for (var line in moveLines) {
        final productId = (line['product_id'] as List)[0] as int;
        final product = productMap[productId];
        if (product != null) {
          line['product_code'] = product['default_code'] ?? '';
          line['product_barcode'] = product['barcode'] ?? '';
          line['product_image'] = product['image_128'];
          line['product_category'] = product['categ_id'] != false
              ? (product['categ_id'] as List)[1] as String
              : '';
        }
      }

      final uomIds = moveLines
          .map((line) => (line['product_uom_id'] as List)[0] as int)
          .toSet()
          .toList();
      debugPrint('Fetching uom.uom for uomIds: $uomIds');
      final uomResult = await client.callKw({
        'model': 'uom.uom',
        'method': 'search_read',
        'args': [
          [
            ['id', 'in', uomIds]
          ],
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

      debugPrint('Fetching stock.picking for pickingId: $pickingId');
      final pickingResult = await client.callKw({
        'model': 'stock.picking',
        'method': 'search_read',
        'args': [
          [
            ['id', '=', pickingId]
          ],
          [
            'id',
            'name',
            'state',
            'scheduled_date',
            'date_done',
            'partner_id',
            'location_id',
            'location_dest_id',
            'origin',
            'carrier_id',
            'weight',
            'note',
            'picking_type_id',
            'company_id',
            'user_id'
          ],
        ],
        'kwargs': {},
      });
      debugPrint('Picking result: $pickingResult');
      if (pickingResult.isEmpty) {
        debugPrint('Error: Picking not found');
        throw Exception('Picking not found');
      }
      final pickingDetail = pickingResult[0] as Map<String, dynamic>;

      Map<String, dynamic>? partnerAddress;
      if (pickingDetail['partner_id'] != false) {
        final partnerId = (pickingDetail['partner_id'] as List)[0] as int;
        debugPrint('Fetching res.partner for partnerId: $partnerId');
        final partnerResult = await client.callKw({
          'model': 'res.partner',
          'method': 'search_read',
          'args': [
            [
              ['id', '=', partnerId]
            ],
            [
              'id',
              'name',
              'street',
              'street2',
              'city',
              'state_id',
              'country_id',
              'zip',
              'phone',
              'email'
            ],
          ],
          'kwargs': {},
        });
        debugPrint('Partner result: $partnerResult');
        if (partnerResult.isNotEmpty) {
          partnerAddress = partnerResult[0] as Map<String, dynamic>;
        }
      }

      debugPrint('Fetching mail.message for pickingId: $pickingId');
      final statusHistoryResult = await client.callKw({
        'model': 'mail.message',
        'method': 'search_read',
        'args': [
          [
            ['model', '=', 'stock.picking'],
            ['res_id', '=', pickingId]
          ],
          ['id', 'date', 'body', 'author_id'],
        ],
        'kwargs': {'order': 'date desc', 'limit': 10},
      });
      debugPrint('Status history result: $statusHistoryResult');
      final statusHistory =
          List<Map<String, dynamic>>.from(statusHistoryResult);

      final totalPicked = moveLines.fold(
          0.0, (sum, line) => sum + (line['quantity'] as double? ?? 0.0));
      final totalOrdered = moveLines.fold(
          0.0, (sum, line) => sum + (line['ordered_qty'] as double));
      final totalValue = moveLines.fold(
          0.0,
          (sum, line) =>
              sum +
              ((line['price_unit'] as double) *
                  (line['quantity'] as double? ?? 0.0)));

      debugPrint(
          'Data fetched successfully: moveLines: ${moveLines.length}, totalPicked: $totalPicked');
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
  } // Future<void> _captureSignature() async {
  //   final result = await Navigator.push(
  //     context,
  //     MaterialPageRoute(
  //       builder: (context) => SignaturePad(
  //         title: 'Delivery Signature',
  //       ),
  //     ),
  //   );
  //
  //   if (result != null) {
  //     setState(() {
  //       _signature = result;
  //     });
  //   }
  // }

  // Future<void> _capturePhoto() async {
  //   final imagePath = await ImageHelper.captureImage(context);
  //   if (imagePath != null) {
  //     setState(() {
  //       _deliveryPhotos.add(imagePath);
  //     });
  //   }
  // }

  Future<void> _submitDelivery(BuildContext context, int pickingId) async {
    // Implement submission of delivery confirmation with signature and photos
    try {
      setState(() {
        _isLoading = true;
      });

      final client = await SessionManager.getActiveClient();
      if (client == null) {
        throw Exception('No active Odoo session found.');
      }

      // Upload signature and photos as attachments
      List<int> attachmentIds = [];

      if (_signature != null) {
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
            }
          ],
          'kwargs': {},
        });

        attachmentIds.add(signatureAttachment as int);
      }

      for (var i = 0; i < _deliveryPhotos.length; i++) {
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
            }
          ],
          'kwargs': {},
        });

        attachmentIds.add(photoAttachment as int);
      }

      // Update delivery note if provided
      if (_noteController.text.isNotEmpty) {
        await client.callKw({
          'model': 'stock.picking',
          'method': 'write',
          'args': [
            [pickingId],
            {'note': _noteController.text},
          ],
          'kwargs': {},
        });
      }

      // Update delivery status (example - adjust based on your workflow)
      await client.callKw({
        'model': 'stock.picking',
        'method': 'action_confirm_delivery', // Replace with your actual method
        'args': [
          [pickingId],
          {
            'has_signature': _signature != null,
            'has_photos': _deliveryPhotos.isNotEmpty,
            'attachment_ids': attachmentIds,
          }
        ],
        'kwargs': {},
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Delivery confirmed successfully')),
      );

      Navigator.pop(context, true); // Return with success result
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
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
                        debugPrint('Line $index: $line'); // Log the entire line

                        // Safely handle product_id
                        final productId = line['product_id'];
                        if (productId is! List) {
                          debugPrint(
                              'Error: product_id is not a List, it is ${productId.runtimeType} with value $productId');
                          return const ListTile(
                              title: Text('Invalid product data'));
                        }
                        final productName = (productId as List).length > 1
                            ? productId[1] as String
                            : 'Unknown Product';
                        debugPrint(
                            'productName for line $index: $productName (type: ${productName.runtimeType})');

                        // Safely handle quantity
                        final pickedQty = line['quantity'] as double? ?? 0.0;
                        debugPrint(
                            'pickedQty for line $index: $pickedQty (type: ${pickedQty.runtimeType})');

                        // Safely handle ordered_qty
                        final orderedQty =
                            line['ordered_qty'] as double? ?? 0.0;
                        debugPrint(
                            'orderedQty for line $index: $orderedQty (type: ${orderedQty.runtimeType})');

                        // Safely handle product_code
                        final productCode = line['product_code'] is String
                            ? line['product_code'] as String
                            : '';
                        debugPrint(
                            'productCode for line $index: $productCode (type: ${productCode.runtimeType})');

                        // Safely handle product_barcode
                        final productBarcode = line['product_barcode'] is String
                            ? line['product_barcode'] as String
                            : '';
                        debugPrint(
                            'productBarcode for line $index: $productBarcode (type: ${productBarcode.runtimeType})');

                        // Safely handle uom_name
                        final uomName = line['uom_name'] is String
                            ? line['uom_name'] as String
                            : 'Units';
                        debugPrint(
                            'uomName for line $index: $uomName (type: ${uomName.runtimeType})');

                        // Safely handle price_unit
                        final priceUnit = line['price_unit'] as double? ?? 0.0;
                        debugPrint(
                            'priceUnit for line $index: $priceUnit (type: ${priceUnit.runtimeType})');

                        // Safely handle lot_name
                        final lotName = line['lot_name'] != false &&
                                line['lot_name'] is String
                            ? line['lot_name'] as String
                            : null;
                        debugPrint(
                            'lotName for line $index: $lotName (type: ${lotName?.runtimeType ?? 'null'})');

                        // Safely handle product_image
                        final productImage = line['product_image'];
                        // debugPrint('productImage for line $index: $productImage (type: ${productImage.runtimeType})');
                        Widget imageWidget;
                        if (productImage != null &&
                            productImage != false &&
                            productImage is String) {
                          try {
                            imageWidget = Image.memory(
                              base64Decode(productImage as String),
                              fit: BoxFit.cover,
                            );
                          } catch (e) {
                            debugPrint(
                                'Error decoding productImage for line $index: $e');
                            imageWidget = Icon(Icons.inventory_2,
                                color: Colors.grey[400], size: 30);
                          }
                        } else {
                          imageWidget = Icon(Icons.inventory_2,
                              color: Colors.grey[400], size: 30);
                        }

                        final lineValue = priceUnit * pickedQty;

                        return Card(
                          elevation: 1,
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Product image or placeholder
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
                                    // Product details
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
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
                                              style: TextStyle(
                                                  color: Colors.grey[700],
                                                  fontSize: 13),
                                            ),
                                          if (productBarcode.isNotEmpty)
                                            Text(
                                              'Barcode: $productBarcode',
                                              style: TextStyle(
                                                  color: Colors.grey[700],
                                                  fontSize: 13),
                                            ),
                                          if (lotName != null)
                                            Text(
                                              'Lot: $lotName',
                                              style: TextStyle(
                                                  color: Colors.grey[700],
                                                  fontSize: 13),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(height: 24),
                                // Quantity and pricing information
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Ordered',
                                            style: TextStyle(
                                                color: Colors.grey[600],
                                                fontSize: 12),
                                          ),
                                          Text(
                                            '${orderedQty.toStringAsFixed(2)} $uomName',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Picked',
                                            style: TextStyle(
                                                color: Colors.grey[600],
                                                fontSize: 12),
                                          ),
                                          Text(
                                            '${pickedQty.toStringAsFixed(2)} $uomName',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: pickedQty >= orderedQty
                                                  ? Colors.green
                                                  : Colors.orange,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            'Value',
                                            style: TextStyle(
                                                color: Colors.grey[600],
                                                fontSize: 12),
                                          ),
                                          Text(
                                            '\$${lineValue.toStringAsFixed(2)}',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                // Progress bar for this line
                                LinearProgressIndicator(
                                  value: orderedQty > 0
                                      ? (pickedQty / orderedQty).clamp(0.0, 1.0)
                                      : 0.0,
                                  backgroundColor: Colors.grey[200],
                                  color: pickedQty >= orderedQty
                                      ? Colors.green
                                      : Colors.orange,
                                  minHeight: 5,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${orderedQty > 0 ? ((pickedQty / orderedQty) * 100).toStringAsFixed(0) : 0}% complete',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: pickedQty >= orderedQty
                                        ? Colors.green
                                        : Colors.grey[600],
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
                                      onPressed: () {},
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
                                onPressed: () {},
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

// Import needed at the top of the file
