import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:van_sale_applicatioin/authentication/cyllo_session_model.dart';
import 'package:van_sale_applicatioin/secondary_pages/sale_order_history_page/sale_order_details_page/products_picking_page/products_picking_page.dart';
import 'package:van_sale_applicatioin/secondary_pages/sale_order_history_page/sale_order_details_page/sale_order_detail_provider.dart';
import 'package:van_sale_applicatioin/widgets/page_transition.dart';
import '../../../main_pages/select_products_page/order_picking_provider.dart';
import '../../../widgets/order_tracking.dart';
import 'delivery_details_page/delivey_details_page.dart';
import 'invoice_details_page/invoice_details_page.dart';

class SaleOrderDetailPage extends StatefulWidget {
  final Map<String, dynamic> orderData;

  const SaleOrderDetailPage({Key? key, required this.orderData})
      : super(key: key);

  @override
  _SaleOrderDetailPageState createState() => _SaleOrderDetailPageState();
}

class _SaleOrderDetailPageState extends State<SaleOrderDetailPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  int? selectedProductId;
  String? scanMessage;
  bool isScanning = false;

  Widget _buildStatIndicator(
      BuildContext context, String label, String value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label: ',
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
        Text(
          value,
          style: TextStyle(
              color: color, fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => SaleOrderDetailProvider(orderData: widget.orderData),
      child: Consumer<SaleOrderDetailProvider>(
        builder: (context, provider, child) {
          return Scaffold(
            backgroundColor: Colors.grey[100],
            appBar: AppBar(
              title: Text(
                'Order ${widget.orderData['name']}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              elevation: 0,
              actions: [
                IconButton(
                  icon: const Icon(Icons.more_vert),
                  onPressed: provider.toggleActions,
                ),
              ],
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
              backgroundColor: primaryColor,
            ),
            body: SafeArea(
              child: provider.isLoading
                  ? const Center(
                      child:
                          CircularProgressIndicator(color: Color(0xFFA12424)),
                    )
                  : provider.error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.error_outline,
                                      size: 48, color: Colors.red[300]),
                                  const SizedBox(height: 16),
                                  Text(
                                    provider.error!,
                                    style: const TextStyle(color: Colors.red),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 24),
                                  ElevatedButton(
                                    onPressed: provider.fetchOrderDetails,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF1976D2),
                                    ),
                                    child: const Text('Retry'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      : provider.orderDetails == null
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.info_outline,
                                      size: 48, color: Colors.grey[400]),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No order details found',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : _buildOrderDetails(context, provider),
            ),
          );
        },
      ),
    );
  }

  Widget _buildOrderDetails(
      BuildContext context, SaleOrderDetailProvider provider) {
    final orderData = provider.orderDetails!;
    final customer = orderData['partner_id'] is List
        ? (orderData['partner_id'] as List)[1] as String
        : 'Unknown';
    final invoiceAddress = orderData['partner_invoice_id'] is List
        ? (orderData['partner_invoice_id'] as List)[1] as String
        : customer;
    final shippingAddress = orderData['partner_shipping_id'] is List
        ? (orderData['partner_shipping_id'] as List)[1] as String
        : customer;
    final salesperson =
        orderData['user_id'] is List && orderData['user_id'].length > 1
            ? (orderData['user_id'] as List)[1] as String
            : 'Not assigned';
    final dateOrder = DateTime.parse(orderData['date_order'] as String);
    final validityDate = orderData['validity_date'] != false
        ? DateTime.parse(orderData['validity_date'] as String)
        : null;
    final commitmentDate = orderData['commitment_date'] != false
        ? DateTime.parse(orderData['commitment_date'] as String)
        : null;
    final expectedDate = orderData['expected_date'] != false
        ? DateTime.parse(orderData['expected_date'] as String)
        : null;
    final paymentTerm = orderData['payment_term_id'] is List &&
            orderData['payment_term_id'].length > 1
        ? (orderData['payment_term_id'] as List)[1] as String
        : 'Standard';
    final warehouse = orderData['warehouse_id'] is List &&
            orderData['warehouse_id'].length > 1
        ? (orderData['warehouse_id'] as List)[1] as String
        : 'Default';
    final team = orderData['team_id'] is List && orderData['team_id'].length > 1
        ? (orderData['team_id'] as List)[1] as String
        : 'No Sales Team';
    final company =
        orderData['company_id'] is List && orderData['company_id'].length > 1
            ? (orderData['company_id'] as List)[1] as String
            : 'Default Company';
    final orderLines =
        List<Map<String, dynamic>>.from(orderData['line_details'] ?? []);
    final pickings =
        List<Map<String, dynamic>>.from(orderData['picking_details'] ?? []);
    final invoices =
        List<Map<String, dynamic>>.from(orderData['invoice_details'] ?? []);
    final invoiceStatus = orderData['invoice_status'] as String? ?? 'unknown';
    final warehouseId = orderData['warehouse_id'] is List &&
            orderData['warehouse_id'].length > 1
        ? (orderData['warehouse_id'] as List)[0] as int
        : 0;

    final statusDetails = provider.getStatusDetails(
        orderData['state'] as String, invoiceStatus, pickings);
    final deliveryStatus = provider.getDeliveryStatus(pickings);
    final displayInvoiceStatus =
        provider.getInvoiceStatus(invoiceStatus, invoices);

    return Stack(
      children: [
        Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: const BoxDecoration(
                color: Color(0xFFA12424),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(16.0),
                  bottomRight: Radius.circular(16.0),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        orderData['name'] as String,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          provider
                              .formatStateMessage(orderData['state'] as String),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    customer,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('MMMM dd, yyyy').format(dateOrder),
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
            TabBar(
              controller: _tabController,
              labelColor: const Color(0xFFA12424),
              unselectedLabelColor: Colors.grey[600],
              indicatorColor: const Color(0xFFA12424),
              tabs: const [
                Tab(
                  icon: Icon(Icons.receipt),
                  text: 'Order Info',
                ),
                Tab(
                  icon: Icon(Icons.local_shipping),
                  text: 'Deliveries',
                ),
                Tab(
                  icon: Icon(Icons.payment),
                  text: 'Invoices',
                ),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Order Info Tab
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Status Card
                        // Card(
                        //   elevation: 2,
                        //   shape: RoundedRectangleBorder(
                        //     borderRadius: BorderRadius.circular(12),
                        //   ),
                        //   color: statusDetails['showWarning'] == true
                        //       ? Colors.amber[50]
                        //       : Colors.white,
                        //   child: Padding(
                        //     padding: const EdgeInsets.all(16.0),
                        //     child: Column(
                        //       crossAxisAlignment: CrossAxisAlignment.start,
                        //       children: [
                        //         Row(
                        //           children: [
                        //             Icon(
                        //               statusDetails['showWarning'] == true
                        //                   ? Icons.warning_amber_rounded
                        //                   : Icons.check_circle_outline,
                        //               color:
                        //                   statusDetails['showWarning'] == true
                        //                       ? Colors.orange[700]
                        //                       : Colors.green[700],
                        //               size: 24,
                        //             ),
                        //             const SizedBox(width: 8),
                        //             Text(
                        //               statusDetails['message'] as String,
                        //               style: TextStyle(
                        //                 fontSize: 16,
                        //                 fontWeight: FontWeight.bold,
                        //                 color:
                        //                     statusDetails['showWarning'] == true
                        //                         ? Colors.orange[800]
                        //                         : Colors.grey[800],
                        //               ),
                        //             ),
                        //           ],
                        //         ),
                        //         const SizedBox(height: 8),
                        //         Text(
                        //           statusDetails['details'] as String,
                        //           style: TextStyle(
                        //             fontSize: 14,
                        //             color: Colors.grey[700],
                        //           ),
                        //         ),
                        //         const SizedBox(height: 12),
                        //         const Divider(),
                        //         const SizedBox(height: 12),
                        //         Row(
                        //           mainAxisAlignment:
                        //               MainAxisAlignment.spaceBetween,
                        //           children: [
                        //             Flexible(
                        //               flex: 1,
                        //               child: _buildStatusTag(
                        //                 'Delivery: $deliveryStatus',
                        //                 provider.getDeliveryStatusColor(
                        //                     deliveryStatus),
                        //               ),
                        //             ),
                        //             SizedBox(
                        //               width: 2,
                        //             ),
                        //             Flexible(
                        //               flex: 1,
                        //               child: _buildStatusTag(
                        //                 'Invoice: $displayInvoiceStatus',
                        //                 provider.getInvoiceStatusColor(
                        //                     displayInvoiceStatus),
                        //               ),
                        //             ),
                        //           ],
                        //         ),
                        //       ],
                        //     ),
                        //   ),
                        // ),
                        Card(
                          elevation: 2,
                          margin: const EdgeInsets.only(bottom: 12.0),
                          // Standardized margin
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildSectionTitle('Order Information'),
                                const SizedBox(height: 12),
                                _buildInfoRow(
                                    Icons.person, 'Customer', customer),
                                _buildInfoRow(Icons.home, 'Invoice Address',
                                    invoiceAddress),
                                _buildInfoRow(Icons.local_shipping,
                                    'Shipping Address', shippingAddress),
                                _buildInfoRow(
                                    Icons.calendar_today,
                                    'Order Date',
                                    DateFormat('yyyy-MM-dd HH:mm')
                                        .format(dateOrder)),
                                if (validityDate != null)
                                  _buildInfoRow(
                                      Icons.event_available,
                                      'Validity Date',
                                      DateFormat('yyyy-MM-dd')
                                          .format(validityDate)),
                                if (commitmentDate != null)
                                  _buildInfoRow(
                                      Icons.schedule,
                                      'Commitment Date',
                                      DateFormat('yyyy-MM-dd')
                                          .format(commitmentDate)),
                                if (expectedDate != null)
                                  _buildInfoRow(
                                      Icons.access_time,
                                      'Expected Date',
                                      DateFormat('yyyy-MM-dd')
                                          .format(expectedDate)),
                                _buildInfoRow(Icons.person_outline,
                                    'Salesperson', salesperson),
                                _buildInfoRow(Icons.group, 'Sales Team', team),
                                _buildInfoRow(Icons.payment, 'Payment Terms',
                                    paymentTerm),
                                _buildInfoRow(
                                    Icons.warehouse, 'Warehouse', warehouse),
                                _buildInfoRow(
                                    Icons.business, 'Company', company),
                                if (orderData['client_order_ref'] != false)
                                  _buildInfoRow(
                                      Icons.receipt,
                                      'Customer Reference',
                                      orderData['client_order_ref'] as String),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        OrderTrackingWidget(
                          orderData: orderData,
                          onTrackDelivery: (int pickingId) {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Track Delivery'),
                                content: Text(
                                    'Tracking delivery for picking ID: $pickingId'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Close'),
                                  ),
                                ],
                              ),
                            );
                          },
                          onRefresh: () async {
                            await provider.fetchOrderDetails();
                          },
                        ),
                        // Order Info Card

                        const SizedBox(height: 20),

                        // Order Lines
                        Text(
                          'Order Lines',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                        const SizedBox(height: 8),

                        if (orderLines.isEmpty)
                          Card(
                            elevation: 1,
                            margin: const EdgeInsets.only(bottom: 12.0),
                            // Standardized margin
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Center(
                                child: Text(
                                  'No order lines found',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            ),
                          )
                        else
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: orderLines.length,
                            itemBuilder: (context, index) {
                              final line = orderLines[index];

                              if (line['display_type'] == 'line_section' ||
                                  line['display_type'] == 'line_note') {
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12.0),
                                  // Standardized margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.all(16.0),
                                  // Standardized padding
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    line['name'] as String,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: Colors.grey[800],
                                    ),
                                  ),
                                );
                              }

                              final productName = line['product_id'] is List &&
                                      line['product_id'].length > 1
                                  ? (line['product_id'] as List)[1] as String
                                  : line['name'] as String;
                              final quantity =
                                  line['product_uom_qty'] as double;
                              final unitPrice = line['price_unit'] as double;
                              final subtotal = line['price_subtotal'] as double;
                              final qtyDelivered =
                                  line['qty_delivered'] as double? ?? 0.0;
                              final qtyInvoiced =
                                  line['qty_invoiced'] as double? ?? 0.0;
                              final discount =
                                  line['discount'] as double? ?? 0.0;

                              return Card(
                                margin: const EdgeInsets.only(bottom: 12.0),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                                elevation: 0.5,
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        productName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 15,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Qty: ${quantity.toStringAsFixed(quantity.truncateToDouble() == quantity ? 0 : 2)}',
                                            style: TextStyle(
                                                color: Colors.grey[700],
                                                fontSize: 13),
                                          ),
                                          Text(
                                            'Price: ${provider.currencyFormat.format(unitPrice)}',
                                            style: TextStyle(
                                                color: Colors.grey[700],
                                                fontSize: 13),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Delivered: ${qtyDelivered.toStringAsFixed(qtyDelivered.truncateToDouble() == qtyDelivered ? 0 : 2)}',
                                            style: TextStyle(
                                              color: qtyDelivered < quantity
                                                  ? Colors.orange[600]
                                                  : Colors.green[700],
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          Text(
                                            'Invoiced: ${qtyInvoiced.toStringAsFixed(qtyInvoiced.truncateToDouble() == qtyInvoiced ? 0 : 2)}',
                                            style: TextStyle(
                                              color: qtyInvoiced < quantity
                                                  ? Colors.orange[600]
                                                  : Colors.green[700],
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (discount > 0)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(top: 4),
                                          child: Text(
                                            'Discount: ${discount.toStringAsFixed(1)}%',
                                            style: TextStyle(
                                                color: Colors.red[700],
                                                fontSize: 13),
                                          ),
                                        ),
                                      const SizedBox(height: 10),
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: Text(
                                          'Subtotal: ${provider.currencyFormat.format(subtotal)}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),

                        const SizedBox(height: 20),

                        // Pricing Summary Card
                        Card(
                          elevation: 2,
                          margin: const EdgeInsets.only(bottom: 12.0),
                          // Standardized margin
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildSectionTitle('Pricing Summary'),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Untaxed Amount:',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                    Text(
                                      provider.currencyFormat.format(
                                          orderData['amount_untaxed']
                                              as double),
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[800],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Taxes:',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                    Text(
                                      provider.currencyFormat.format(
                                          orderData['amount_tax'] as double),
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[800],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(height: 24),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Total:',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      provider.currencyFormat.format(
                                          orderData['amount_total'] as double),
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFFA12424),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Notes section
                        if (orderData['note'] != false &&
                            orderData['note'] != null)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Notes',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[800],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Card(
                                elevation: 1,
                                margin: const EdgeInsets.only(bottom: 12.0),
                                // Standardized margin
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Text(
                                    orderData['note'] as String,
                                    style: TextStyle(
                                      color: Colors.grey[800],
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),

                        const SizedBox(height: 24),
                      ],
                    ),
                  ),

                  // Deliveries Tab
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Delivery Orders',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (pickings.isEmpty)
                          Card(
                            elevation: 1,
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Center(
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.local_shipping_outlined,
                                      size: 48,
                                      color: Colors.grey[400],
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No delivery orders found',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )
                        else
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: pickings.length,
                            itemBuilder: (context, index) {
                              final picking = pickings[index];
                              final pickingName = picking['name'] as String;
                              final pickingState = picking['state'] as String;
                              final scheduledDate =
                                  picking['scheduled_date'] != false
                                      ? DateTime.parse(
                                          picking['scheduled_date'] as String)
                                      : null;
                              final pickingType =
                                  picking['picking_type_id'] is List &&
                                          picking['picking_type_id'].length > 1
                                      ? (picking['picking_type_id'] as List)[1]
                                          as String
                                      : 'Delivery Order';
                              final dateCompleted =
                                  picking['date_done'] != false
                                      ? DateTime.parse(
                                          picking['date_done'] as String)
                                      : null;
                              final backorderId =
                                  picking['backorder_id'] != false;

                              Future<Map<String, double>>
                                  getPickingProgress() async {
                                final client =
                                    await SessionManager.getActiveClient();
                                final moveLines = await client!.callKw({
                                  'model': 'stock.move.line',
                                  'method': 'search_read',
                                  'args': [
                                    [
                                      ['picking_id', '=', picking['id']]
                                    ],
                                    ['product_id', 'quantity', 'move_id'],
                                  ],
                                  'kwargs': {},
                                });
                                final moveIds = moveLines
                                    .map((line) =>
                                        (line['move_id'] as List)[0] as int)
                                    .toList();
                                final moves = await client.callKw({
                                  'model': 'stock.move',
                                  'method': 'search_read',
                                  'args': [
                                    [
                                      ['id', 'in', moveIds]
                                    ],
                                    ['id', 'product_uom_qty'],
                                  ],
                                  'kwargs': {},
                                });
                                final moveQtyMap = {
                                  for (var move in moves)
                                    move['id'] as int:
                                        move['product_uom_qty'] as double
                                };
                                double totalPicked = 0;
                                double totalOrdered = 0;
                                for (var line in moveLines) {
                                  final moveId =
                                      (line['move_id'] as List)[0] as int;
                                  totalPicked +=
                                      (line['quantity'] as double? ?? 0.0);
                                  totalOrdered += moveQtyMap[moveId] ?? 0.0;
                                }
                                return {
                                  'picked': totalPicked,
                                  'ordered': totalOrdered
                                };
                              }

                              return Card(
                                elevation: 2,
                                margin: const EdgeInsets.only(bottom: 12),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            pickingName,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16),
                                          ),
                                          FutureBuilder<Map<String, double>>(
                                            future: getPickingProgress(),
                                            builder: (context, snapshot) {
                                              if (snapshot.connectionState ==
                                                  ConnectionState.waiting) {
                                                return const SizedBox.shrink();
                                              }
                                              final picked =
                                                  snapshot.data?['picked'] ??
                                                      0.0;
                                              final ordered =
                                                  snapshot.data?['ordered'] ??
                                                      1.0;
                                              final isFullyPicked =
                                                  picked >= ordered &&
                                                      ordered > 0;
                                              return Row(
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 8,
                                                        vertical: 4),
                                                    decoration: BoxDecoration(
                                                      color: provider
                                                          .getPickingStatusColor(
                                                              pickingState)
                                                          .withOpacity(0.1),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8),
                                                      border: Border.all(
                                                        color: provider
                                                            .getPickingStatusColor(
                                                                pickingState),
                                                        width: 1,
                                                      ),
                                                    ),
                                                    child: Text(
                                                      provider
                                                          .formatPickingState(
                                                              pickingState),
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: provider
                                                            .getPickingStatusColor(
                                                                pickingState),
                                                      ),
                                                    ),
                                                  ),
                                                  if (isFullyPicked &&
                                                      pickingState != 'done')
                                                    const SizedBox(width: 8),
                                                  if (isFullyPicked &&
                                                      pickingState != 'done')
                                                    Chip(
                                                      label: const Text(
                                                          'Fully Picked'),
                                                      backgroundColor: Colors
                                                          .green
                                                          .withOpacity(0.2),
                                                      labelStyle:
                                                          const TextStyle(
                                                              color:
                                                                  Colors.green,
                                                              fontSize: 12),
                                                    ),
                                                ],
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        pickingType,
                                        style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey[700]),
                                      ),
                                      const SizedBox(height: 8),
                                      if (backorderId)
                                        Row(
                                          children: [
                                            const Icon(Icons.info_outline,
                                                size: 16, color: Colors.amber),
                                            const SizedBox(width: 4),
                                            Text(
                                              'This is a backorder',
                                              style: TextStyle(
                                                  fontSize: 14,
                                                  fontStyle: FontStyle.italic,
                                                  color: Colors.amber[800]),
                                            ),
                                          ],
                                        ),
                                      const SizedBox(height: 8),
                                      if (scheduledDate != null)
                                        _buildInfoRow(
                                          Icons.calendar_today,
                                          'Scheduled Date',
                                          DateFormat('yyyy-MM-dd HH:mm')
                                              .format(scheduledDate),
                                        ),
                                      if (dateCompleted != null)
                                        _buildInfoRow(
                                          Icons.check_circle_outline,
                                          'Completed Date',
                                          DateFormat('yyyy-MM-dd HH:mm')
                                              .format(dateCompleted),
                                        ),
                                      const SizedBox(height: 8),
                                      pickingState == 'cancel'
                                          ? const SizedBox.shrink()
                                          : FutureBuilder<Map<String, double>>(
                                              future: getPickingProgress(),
                                              builder: (context, snapshot) {
                                                if (snapshot.connectionState ==
                                                    ConnectionState.waiting) {
                                                  return const Center(
                                                    child: Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .center,
                                                      children: [
                                                        Text(
                                                          'Loading progress...',
                                                          style: TextStyle(
                                                            fontSize: 14,
                                                            color: Colors.grey,
                                                            fontStyle: FontStyle
                                                                .italic,
                                                          ),
                                                        ),
                                                        SizedBox(width: 12),
                                                        SizedBox(
                                                          width: 30,
                                                          height: 30,
                                                          child:
                                                              CircularProgressIndicator(
                                                            strokeWidth: 3,
                                                            color: primaryColor,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                }

                                                final picked =
                                                    snapshot.data?['picked'] ??
                                                        0.0;
                                                final ordered =
                                                    snapshot.data?['ordered'] ??
                                                        1.0;
                                                final progress =
                                                    (picked / ordered)
                                                        .clamp(0.0, 1.0);
                                                final isFullyPicked =
                                                    picked >= ordered &&
                                                        ordered > 0;

                                                return Padding(
                                                  padding:
                                                      const EdgeInsets.all(6.0),
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        'Picking Progress',
                                                        style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          fontSize: 14,
                                                          color:
                                                              Colors.grey[800],
                                                        ),
                                                      ),
                                                      const SizedBox(height: 8),
                                                      ClipRRect(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(10),
                                                        child:
                                                            LinearProgressIndicator(
                                                          value: progress,
                                                          minHeight: 10,
                                                          backgroundColor:
                                                              Colors.grey[300],
                                                          valueColor:
                                                              const AlwaysStoppedAnimation<
                                                                      Color>(
                                                                  Colors.green),
                                                        ),
                                                      ),
                                                      const SizedBox(height: 6),
                                                      Text(
                                                        'Picked: ${picked.toStringAsFixed(0)} / ${ordered.toStringAsFixed(0)}',
                                                        style: TextStyle(
                                                          fontSize: 13,
                                                          color:
                                                              Colors.grey[700],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              },
                                            ),
                                      const SizedBox(height: 12),
                                      pickingState == 'cancel'
                                          ? const SizedBox.shrink()
                                          : FutureBuilder<Map<String, double>>(
                                              future: getPickingProgress(),
                                              builder: (context, snapshot) {
                                                if (snapshot.connectionState ==
                                                    ConnectionState.waiting) {
                                                  return const SizedBox
                                                      .shrink();
                                                }

                                                final picked =
                                                    snapshot.data?['picked'] ??
                                                        0.0;
                                                final ordered =
                                                    snapshot.data?['ordered'] ??
                                                        1.0;
                                                final isFullyPicked =
                                                    picked >= ordered &&
                                                        ordered > 0;

                                                return Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceEvenly,
                                                  children: [
                                                    Expanded(
                                                      child:
                                                          ElevatedButton.icon(
                                                        icon: const Icon(
                                                            Icons.visibility,
                                                            color:
                                                                Colors.white),
                                                        label: const Text(
                                                          'View Details',
                                                          style: TextStyle(
                                                              color:
                                                                  Colors.white),
                                                        ),
                                                        onPressed: () {
                                                          Navigator.push(
                                                            context,
                                                            SlidingPageTransitionRL(
                                                              page:
                                                                  DeliveryDetailsPage(
                                                                pickingData:
                                                                    picking,
                                                                provider:
                                                                    provider,
                                                              ),
                                                            ),
                                                          );
                                                        },
                                                        style: ElevatedButton
                                                            .styleFrom(
                                                          backgroundColor:
                                                              const Color(
                                                                  0xFFA12424),
                                                          shape:
                                                              RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        8),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 10),
                                                    Expanded(
                                                      child:
                                                          ElevatedButton.icon(
                                                        icon: const Icon(
                                                            Icons.check_circle,
                                                            color:
                                                                Colors.white),
                                                        label: Text(
                                                          isFullyPicked
                                                              ? 'Edit Picking'
                                                              : 'Pick Products',
                                                          style:
                                                              const TextStyle(
                                                                  color: Colors
                                                                      .white),
                                                        ),
                                                        onPressed: () {
                                                          Navigator.push(
                                                            context,
                                                            SlidingPageTransitionRL(
                                                              page: PickingPage(
                                                                picking:
                                                                    picking,
                                                                orderLines:
                                                                    orderLines,
                                                                warehouseId:
                                                                    warehouseId,
                                                                provider:
                                                                    provider,
                                                              ),
                                                            ),
                                                          );
                                                        },
                                                        style: ElevatedButton
                                                            .styleFrom(
                                                          backgroundColor:
                                                              Colors.green,
                                                          shape:
                                                              RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        8),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                );
                                              },
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

                  // Invoices Tab
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Invoices',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (invoices.isEmpty)
                          Card(
                            elevation: 1,
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Center(
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.receipt_long,
                                      size: 48,
                                      color: Colors.grey[400],
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No invoices found',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )
                        else
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: invoices.length,
                            itemBuilder: (context, index) {
                              final invoice = invoices[index];
                              final invoiceNumber = invoice['name'] != false
                                  ? invoice['name'] as String
                                  : 'Draft';
                              final invoiceDate =
                                  invoice['invoice_date'] != false
                                      ? DateTime.parse(
                                          invoice['invoice_date'] as String)
                                      : null;
                              final dueDate =
                                  invoice['invoice_date_due'] != false
                                      ? DateTime.parse(
                                          invoice['invoice_date_due'] as String)
                                      : null;
                              final invoiceState = invoice['state'] as String;
                              final invoiceAmount =
                                  invoice['amount_total'] as double;
                              final amountResidual =
                                  invoice['amount_residual'] as double? ??
                                      invoiceAmount;
                              final isFullyPaid = amountResidual <= 0;

                              return Card(
                                elevation: 2,
                                margin: const EdgeInsets.only(bottom: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            invoiceNumber,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: provider
                                                  .getInvoiceStatusColor(
                                                      provider
                                                          .formatInvoiceState(
                                                              invoiceState,
                                                              isFullyPaid))
                                                  .withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                color: provider
                                                    .getInvoiceStatusColor(
                                                        provider
                                                            .formatInvoiceState(
                                                                invoiceState,
                                                                isFullyPaid)),
                                                width: 1,
                                              ),
                                            ),
                                            child: Text(
                                              provider.formatInvoiceState(
                                                  invoiceState, isFullyPaid),
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: provider
                                                    .getInvoiceStatusColor(
                                                        provider
                                                            .formatInvoiceState(
                                                                invoiceState,
                                                                isFullyPaid)),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      if (invoiceDate != null)
                                        _buildInfoRow(
                                          Icons.calendar_today,
                                          'Invoice Date',
                                          DateFormat('yyyy-MM-dd')
                                              .format(invoiceDate),
                                        ),
                                      if (dueDate != null)
                                        _buildInfoRow(
                                          Icons.event,
                                          'Due Date',
                                          DateFormat('yyyy-MM-dd')
                                              .format(dueDate),
                                        ),
                                      const SizedBox(height: 8),
                                      const Divider(),
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text(
                                            'Total Amount:',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          Text(
                                            provider.currencyFormat
                                                .format(invoiceAmount),
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (!isFullyPaid) ...[
                                        const SizedBox(height: 8),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            const Text(
                                              'Amount Due:',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            Text(
                                              provider.currencyFormat
                                                  .format(amountResidual),
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.red[700],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                      const SizedBox(height: 12),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          ElevatedButton.icon(
                                            icon: const Icon(
                                              Icons.visibility,
                                              color: Colors.white,
                                            ),
                                            label: const Text(
                                              'View Invoice',
                                              style: TextStyle(
                                                  color: Colors.white),
                                            ),
                                            onPressed: () {
                                              Navigator.push(
                                                context,
                                                SlidingPageTransitionRL(
                                                  page: InvoiceDetailsPage(
                                                    invoiceData: invoice,
                                                  ),
                                                ),
                                              );
                                            },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: primaryColor,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
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
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        // Action Menu
        if (provider.showActions)
          Positioned(
            top: 0,
            right: 0,
            child: Card(
              elevation: 4,
              margin: const EdgeInsets.only(top: 56, right: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              child: Container(
                width: 200,
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildActionMenuItem(
                      Icons.print,
                      'Print Order',
                      () {
                        provider.toggleActions();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Print not implemented')),
                        );
                      },
                    ),
                    _buildActionMenuItem(
                      Icons.email,
                      'Send by Email',
                      () {
                        provider.toggleActions();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Email not implemented')),
                        );
                      },
                    ),
                    _buildActionMenuItem(
                      Icons.edit,
                      'Edit Order',
                      () {
                        provider.toggleActions();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Edit not implemented')),
                        );
                      },
                    ),
                    _buildActionMenuItem(
                      Icons.delete,
                      'Cancel Order',
                      () {
                        provider.toggleActions();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Cancel not implemented')),
                        );
                      },
                      textColor: Colors.red,
                      iconColor: Colors.red,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildActionMenuItem(
    IconData icon,
    String text,
    VoidCallback onTap, {
    Color? textColor,
    Color? iconColor,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: iconColor ?? Colors.grey[700],
            ),
            const SizedBox(width: 12),
            Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: textColor ?? Colors.grey[800],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: primaryColor,
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
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }
}
