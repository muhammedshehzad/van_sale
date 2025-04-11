import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:van_sale_applicatioin/secondary_pages/sale_order_details_page.dart';
import 'package:van_sale_applicatioin/widgets/page_transition.dart';
import '../provider_and_models/cyllo_session_model.dart';
import '../provider_and_models/order_picking_provider.dart';
import '../provider_and_models/sales_order_provider.dart';

class SaleOrderHistoryPage extends StatefulWidget {
  const SaleOrderHistoryPage({Key? key}) : super(key: key);

  @override
  _SaleOrderHistoryPageState createState() => _SaleOrderHistoryPageState();
}

class _SaleOrderHistoryPageState extends State<SaleOrderHistoryPage> {
  late Future<List<Map<String, dynamic>>> _orderHistoryFuture;
  List<Map<String, dynamic>> _allOrders = [];
  List<Map<String, dynamic>> _filteredOrders = [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _orderHistoryFuture = _fetchSaleOrderHistory(context);
    _searchController.addListener(_filterOrders);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _fetchSaleOrderHistory(
      BuildContext context) async {
    Provider.of<SalesOrderProvider>(context, listen: false);
    try {
      final client = await SessionManager.getActiveClient();
      if (client == null) {
        throw Exception('No active Odoo session found. Please log in again.');
      }

      final result = await client.callKw({
        'model': 'sale.order',
        'method': 'search_read',
        'args': [
          [],
          ['id', 'name', 'partner_id', 'date_order', 'amount_total', 'state']
          // Added 'id' to the fields
        ],
        'kwargs': {},
      });

      return List<Map<String, dynamic>>.from(result);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to fetch order history: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
      return [];
    }
  }

  void _filterOrders() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredOrders = List.from(_allOrders);
      } else {
        _filteredOrders = _allOrders.where((order) {
          final orderId = (order['name'] as String).toLowerCase();
          final customer = order['partner_id'] is List
              ? (order['partner_id'] as List)[1].toString().toLowerCase()
              : 'unknown';
          final state = (order['state'] as String).toLowerCase();
          return orderId.contains(query) ||
              customer.contains(query) ||
              state.contains(query);
        }).toList();
      }
    });
  }

  void _navigateToOrderDetail(
      BuildContext context, Map<String, dynamic> order) {
    Navigator.push(
      context,
      SlidingPageTransitionRL(page: SaleOrderDetailPage(orderData: order)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: '\$');

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        leading: IconButton(
            onPressed: () {
              Navigator.pop(context);
            },
            icon: Icon(
              Icons.arrow_back,
              color: Colors.white,
            )),
        title: Text(
          'Sale Order History',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: primaryColor,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search by order ID, customer, or status...',
                  hintStyle: TextStyle(color: Colors.grey[600]),
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
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
                    borderSide: const BorderSide(color: Color(0xFF1976D2)),
                  ),
                  filled: true,
                  fillColor: Colors.grey[100],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _orderHistoryFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child:
                            CircularProgressIndicator(color: Color(0xFF1976D2)),
                      );
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Error loading history: ${snapshot.error}',
                          style: const TextStyle(color: Colors.red),
                        ),
                      );
                    }
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.history,
                              size: 48,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'No sale order history found',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    _allOrders = snapshot.data!;
                    _filteredOrders = _filteredOrders.isEmpty &&
                            _searchController.text.isEmpty
                        ? List.from(_allOrders)
                        : _filteredOrders;

                    if (_filteredOrders.isEmpty &&
                        _searchController.text.isNotEmpty) {
                      return Center(
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
                              'No results found',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.separated(
                      itemCount: _filteredOrders.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final order = _filteredOrders[index];
                        final orderId = order['name'] as String;
                        final customer = order['partner_id'] is List
                            ? (order['partner_id'] as List)[1] as String
                            : 'Unknown';
                        final dateOrder =
                            DateTime.parse(order['date_order'] as String);
                        final totalAmount = order['amount_total'] as double;
                        final state = order['state'] as String;

                        return InkWell(
                          // Wrap with InkWell to make it clickable
                          onTap: () => _navigateToOrderDetail(context, order),
                          borderRadius: BorderRadius.circular(kBorderRadius),
                          child: Card(
                            color: Colors.white,
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(kBorderRadius),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Order: $orderId',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _getStatusColor(state)
                                              .withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          state.toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: _getStatusColor(state),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(Icons.person,
                                          size: 16, color: Colors.grey[600]),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          'Customer: $customer',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey[600],
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(Icons.calendar_today,
                                          size: 16, color: Colors.grey[600]),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Date: ${DateFormat('yyyy-MM-dd HH:mm').format(dateOrder)}',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[600],
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
                                        'Total Amount:',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w500,
                                          color: textColor,
                                        ),
                                      ),
                                      Text(
                                        currencyFormat.format(totalAmount),
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: primaryColor,
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
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String state) {
    switch (state.toLowerCase()) {
      case 'sale':
        return Colors.green;
      case 'done':
        return Colors.blue;
      case 'cancel':
        return Colors.red;
      case 'draft':
        return Colors.grey;
      default:
        return Colors.orange;
    }
  }
}
