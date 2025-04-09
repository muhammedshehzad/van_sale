import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:van_sale_applicatioin/provider_and_models/cyllo_session_model.dart';

class SaleOrderDetailProvider extends ChangeNotifier {
  final Map<String, dynamic> orderData;
  Map<String, dynamic>? _orderDetails;
  bool _isLoading = true;
  String? _error;
  bool _showActions = false;
  final currencyFormat = NumberFormat.currency(symbol: '\$');

  SaleOrderDetailProvider({required this.orderData}) {
    fetchOrderDetails();
  }

  Map<String, dynamic>? get orderDetails => _orderDetails;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get showActions => _showActions;

  void toggleActions() {
    _showActions = !_showActions;
    notifyListeners();
  }

  Future<void> fetchOrderDetails() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final client = await SessionManager.getActiveClient();
      if (client == null) {
        throw Exception('No active Odoo session found. Please log in again.');
      }

      // Helper function to filter valid fields
      Future<List<String>> getValidFields(
          String model, List<String> requestedFields) async {
        final availableFields = await client.callKw({
          'model': model,
          'method': 'fields_get',
          'args': [],
          'kwargs': {},
        });
        return requestedFields
            .where((field) => availableFields.containsKey(field))
            .toList();
      }

      // Fetch sale.order
      final saleOrderFields = await getValidFields('sale.order', [
        'name',
        'partner_id',
        'partner_invoice_id',
        'partner_shipping_id',
        'date_order',
        'amount_total',
        'amount_untaxed',
        'amount_tax',
        'state',
        'order_line',
        'note',
        'payment_term_id',
        'user_id',
        'client_order_ref',
        'validity_date',
        'commitment_date',
        'expected_date',
        'invoice_status',
        'delivery_status',
        'origin',
        'opportunity_id',
        'campaign_id',
        'medium_id',
        'source_id',
        'team_id',
        'tag_ids',
        'company_id',
        'create_date',
        'write_date',
        'fiscal_position_id',
        'picking_policy',
        'warehouse_id',
        'payment_term_id',
        'incoterm',
        'invoice_ids',
        'picking_ids'
      ]);

      final result = await client.callKw({
        'model': 'sale.order',
        'method': 'search_read',
        'args': [
          [
            ['id', '=', orderData['id']]
          ],
          saleOrderFields,
        ],
        'kwargs': {},
      });

      if (result.isEmpty) {
        throw Exception('Order not found for ID: ${orderData['id']}');
      }

      final order = result[0];

      // Fetch order lines
      if (order['order_line'] != null &&
          order['order_line'] is List &&
          order['order_line'].isNotEmpty) {
        final orderLineFields = await getValidFields('sale.order.line', [
          'product_id',
          'name',
          'product_uom_qty',
          'qty_delivered',
          'qty_invoiced',
          'qty_to_deliver',
          'product_uom',
          'price_unit',
          'discount',
          'tax_id',
          'price_subtotal',
          'price_tax',
          'price_total',
          'state',
          'invoice_status',
          'customer_lead',
          'display_type',
          'sequence'
        ]);
        final orderLines = await client.callKw({
          'model': 'sale.order.line',
          'method': 'search_read',
          'args': [
            [
              ['id', 'in', order['order_line']]
            ],
            orderLineFields,
          ],
          'kwargs': {},
        });
        order['line_details'] = orderLines;
      } else {
        order['line_details'] = [];
      }

      // Fetch pickings
      if (order['picking_ids'] != null &&
          order['picking_ids'] is List &&
          order['picking_ids'].isNotEmpty) {
        final pickingFields = await getValidFields('stock.picking', [
          'name',
          'partner_id',
          'scheduled_date',
          'date_done',
          'state',
          'origin',
          'priority',
          'backorder_id',
          'move_ids',
          'picking_type_id'
        ]);
        final pickings = await client.callKw({
          'model': 'stock.picking',
          'method': 'search_read',
          'args': [
            [
              ['id', 'in', order['picking_ids']]
            ],
            pickingFields,
          ],
          'kwargs': {},
        });
        order['picking_details'] = pickings;
      } else {
        order['picking_details'] = [];
      }

      // Fetch invoices
      if (order['invoice_ids'] != null &&
          order['invoice_ids'] is List &&
          order['invoice_ids'].isNotEmpty) {
        final invoiceFields = await getValidFields('account.move', [
          'name',
          'partner_id',
          'invoice_date',
          'invoice_date_due',
          'amount_total',
          'amount_residual',
          'state',
          'invoice_payment_state',
          'type',
          'ref'
        ]);
        final invoices = await client.callKw({
          'model': 'account.move',
          'method': 'search_read',
          'args': [
            [
              ['id', 'in', order['invoice_ids']]
            ],
            invoiceFields,
          ],
          'kwargs': {},
        });
        order['invoice_details'] = invoices;
      } else {
        order['invoice_details'] = [];
      }

      _orderDetails = Map<String, dynamic>.from(order);
      _isLoading = false;
    } catch (e) {
      _error = 'Failed to fetch order details: $e';
      _isLoading = false;
    }
    notifyListeners();
  }

  Future<void> confirmPicking(
      int pickingId,
      Map<int, double> pickedQuantities,
      bool validateImmediately,
      ) async {
    final client = await SessionManager.getActiveClient();
    if (client == null) {
      throw Exception('No active Odoo session found.');
    }

    try {
      const doneField = 'quantity';

      final moveLines = await client.callKw({
        'model': 'stock.move.line',
        'method': 'search_read',
        'args': [
          [
            ['picking_id', '=', pickingId]
          ],
          ['id', 'product_id', doneField, 'move_id'],
        ],
        'kwargs': {},
      });

      if (moveLines.isEmpty) {
        throw Exception('No move lines found for picking $pickingId');
      }

      final moveIds = moveLines
          .map((line) => line['move_id'] is List
          ? (line['move_id'] as List)[0] as int
          : line['move_id'] as int)
          .toList();
      final moveResult = await client.callKw({
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
        for (var move in moveResult)
          move['id'] as int: move['product_uom_qty'] as double
      };

      bool hasChanges = false;
      for (var moveLine in moveLines) {
        int productId = (moveLine['product_id'] as List)[0] as int;
        double pickedQty = pickedQuantities[productId] ?? 0.0;
        final moveId = moveLine['move_id'] is List
            ? (moveLine['move_id'] as List)[0] as int
            : moveLine['move_id'] as int;
        double orderedQty = moveQtyMap[moveId] ?? 0.0;

        if (pickedQty > orderedQty) {
          throw Exception(
              'Picked quantity ($pickedQty) for product $productId exceeds ordered quantity ($orderedQty).');
        }

        final currentQty = moveLine[doneField] as double? ?? 0.0;
        if (pickedQty != currentQty) {
          await client.callKw({
            'model': 'stock.move.line',
            'method': 'write',
            'args': [
              [moveLine['id']],
              {doneField: pickedQty},
            ],
            'kwargs': {},
          });
          hasChanges = true;
        }
      }

      if (validateImmediately || !hasChanges) {
        final validationResult = await client.callKw({
          'model': 'stock.picking',
          'method': 'button_validate',
          'args': [pickingId],
          'kwargs': {},
        });

        if (validationResult is Map &&
            validationResult['type'] == 'ir.actions.act_window') {
          final context = validationResult['context'] as Map<String, dynamic>;
          final wizardId = await client.callKw({
            'model': 'stock.backorder.confirmation',
            'method': 'create',
            'args': [{}],
            'kwargs': {'context': context},
          });

          await client.callKw({
            'model': 'stock.backorder.confirmation',
            'method': 'process',
            'args': [wizardId],
            'kwargs': {},
          });
        } else if (validationResult is Map &&
            validationResult.containsKey('warning')) {
          throw Exception('Validation warning: ${validationResult['warning']}');
        } else if (validationResult is bool && !validationResult) {
          throw Exception('Validation failed for picking $pickingId');
        }
      }

      await fetchOrderDetails();
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<int, double>> fetchStockAvailability(
      List<Map<String, dynamic>> orderLines, int warehouseId) async {
    final client = await SessionManager.getActiveClient();
    if (client == null) {
      throw Exception('No active Odoo session found.');
    }

    List<int> productIds = orderLines
        .where((line) =>
    line['product_id'] is List && line['product_id'].length > 1)
        .map((line) => (line['product_id'] as List)[0] as int)
        .toList();

    final locationResult = await client.callKw({
      'model': 'stock.location',
      'method': 'search_read',
      'args': [
        [
          ['warehouse_id', '=', warehouseId],
          ['usage', '=', 'internal'],
        ],
        ['id'],
      ],
      'kwargs': {},
    });

    if (locationResult.isEmpty) {
      return Map.fromEntries(productIds.map((id) => MapEntry(id, 0.0)));
    }
    final locationId = locationResult[0]['id'] as int;

    final stockResult = await client.callKw({
      'model': 'stock.quant',
      'method': 'search_read',
      'args': [
        [
          ['product_id', 'in', productIds],
          ['location_id', '=', locationId],
        ],
        ['product_id', 'quantity', 'reserved_quantity'],
      ],
      'kwargs': {},
    });

    Map<int, double> stockAvailability = {};
    for (var stock in stockResult) {
      int productId = (stock['product_id'] as List)[0] as int;
      double quantity = (stock['quantity'] as num).toDouble();
      double reserved = (stock['reserved_quantity'] as num).toDouble();
      stockAvailability[productId] = quantity - reserved;
    }

    for (var line in orderLines) {
      int productId = (line['product_id'] as List)[0] as int;
      stockAvailability.putIfAbsent(productId, () => 0.0);
    }

    return stockAvailability;
  }

  String formatStateMessage(String state) {
    switch (state.toLowerCase()) {
      case 'draft':
        return 'Quotation';
      case 'sent':
        return 'Quotation Sent';
      case 'sale':
        return 'Sales Order';
      case 'done':
        return 'Locked';
      case 'cancel':
        return 'Cancelled';
      default:
        return state.toUpperCase();
    }
  }

  Map<String, dynamic> getStatusDetails(
      String state, String invoiceStatus, List<dynamic> pickings) {
    String statusMessage = '';
    String detailedMessage = '';
    bool showWarning = false;

    switch (state.toLowerCase()) {
      case 'draft':
        statusMessage = 'Draft Quotation';
        detailedMessage =
        'This quotation has not been sent to the customer yet.';
        break;
      case 'sent':
        statusMessage = 'Quotation Sent';
        detailedMessage = 'This quotation has been sent to the customer.';
        break;
      case 'sale':
        statusMessage = 'Sales Order Confirmed';
        if (invoiceStatus == 'to invoice') {
          detailedMessage =
          'The sales order is confirmed but waiting to be invoiced.';
          showWarning = true;
        } else if (invoiceStatus == 'invoiced') {
          detailedMessage = 'The sales order is confirmed and fully invoiced.';
        } else if (invoiceStatus == 'no') {
          detailedMessage = 'Nothing to invoice.';
        } else {
          detailedMessage = 'The sales order is confirmed.';
        }

        if (pickings.isNotEmpty) {
          bool allDelivered = true;
          bool anyInProgress = false;

          for (var picking in pickings) {
            if (picking['state'] != 'done') {
              allDelivered = false;
            }
            if (picking['state'] == 'assigned' ||
                picking['state'] == 'partially_available') {
              anyInProgress = true;
            }
          }

          if (!allDelivered) {
            detailedMessage += ' Products not fully delivered.';
            showWarning = true;
          } else {
            detailedMessage += ' All products delivered.';
          }

          if (anyInProgress) {
            detailedMessage += ' Delivery in progress.';
          }
        }
        break;
      case 'done':
        statusMessage = 'Locked';
        detailedMessage = 'This sales order is locked and cannot be modified.';
        break;
      case 'cancel':
        statusMessage = 'Cancelled';
        detailedMessage = 'This sales order has been cancelled.';
        break;
      default:
        statusMessage = state.toUpperCase();
        detailedMessage = 'Unknown status.';
    }

    return {
      'message': statusMessage,
      'details': detailedMessage,
      'showWarning': showWarning,
    };
  }

  String getDeliveryStatus(List<dynamic> pickings) {
    if (pickings.isEmpty) {
      return 'Nothing to Deliver';
    }

    int done = 0;
    int waiting = 0;
    int ready = 0;
    int other = 0;

    for (var picking in pickings) {
      switch (picking['state']) {
        case 'done':
          done++;
          break;
        case 'waiting':
          waiting++;
          break;
        case 'assigned':
          ready++;
          break;
        default:
          other++;
      }
    }

    if (done == pickings.length) {
      return 'Fully Delivered';
    } else if (done > 0) {
      return 'Partially Delivered';
    } else if (ready > 0) {
      return 'Ready for Delivery';
    } else if (waiting > 0) {
      return 'Waiting Availability';
    } else {
      return 'Not Delivered';
    }
  }

  String getInvoiceStatus(String invoiceStatus, List<dynamic> invoices) {
    if (invoiceStatus == 'invoiced') {
      return 'Fully Invoiced';
    } else if (invoiceStatus == 'to invoice') {
      if (invoices.isNotEmpty) {
        return 'Partially Invoiced';
      }
      return 'To Invoice';
    } else if (invoiceStatus == 'no') {
      return 'Nothing to Invoice';
    } else {
      return invoiceStatus.toUpperCase();
    }
  }

  Color getStatusColor(String state) {
    switch (state.toLowerCase()) {
      case 'sale':
        return Colors.green;
      case 'done':
        return Colors.blue;
      case 'cancel':
        return Colors.red;
      case 'draft':
        return Colors.grey;
      case 'sent':
        return Colors.amber;
      default:
        return Colors.orange;
    }
  }

  Color getDeliveryStatusColor(String status) {
    if (status.contains('Fully')) {
      return Colors.green;
    } else if (status.contains('Partially')) {
      return Colors.amber;
    } else if (status.contains('Ready')) {
      return Colors.blue;
    } else if (status.contains('Waiting')) {
      return Colors.orange;
    } else {
      return Colors.grey;
    }
  }

  Color getInvoiceStatusColor(String status) {
    if (status.contains('Paid') || status.contains('Fully Invoiced')) {
      return Colors.green;
    } else if (status.contains('Partially')) {
      return Colors.amber;
    } else if (status.contains('Draft')) {
      return Colors.grey;
    } else if (status.contains('Due') || status.contains('To Invoice')) {
      return Colors.orange;
    } else {
      return Colors.grey[700]!;
    }
  }

  Color getPickingStatusColor(String state) {
    switch (state.toLowerCase()) {
      case 'done':
        return Colors.green;
      case 'assigned':
        return Colors.blue;
      case 'confirmed':
        return Colors.orange;
      case 'waiting':
        return Colors.amber;
      case 'cancel':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String formatPickingState(String state) {
    switch (state.toLowerCase()) {
      case 'done':
        return 'DONE';
      case 'assigned':
        return 'READY';
      case 'confirmed':
        return 'WAITING';
      case 'waiting':
        return 'WAITING ANOTHER';
      case 'draft':
        return 'DRAFT';
      case 'cancel':
        return 'CANCELLED';
      default:
        return state.toUpperCase();
    }
  }

  String formatInvoiceState(String state, bool isPaid) {
    if (isPaid && state != 'draft' && state != 'cancel') {
      return 'PAID';
    }

    switch (state.toLowerCase()) {
      case 'draft':
        return 'DRAFT';
      case 'posted':
        return 'POSTED';
      case 'cancel':
        return 'CANCELLED';
      default:
        return state.toUpperCase();
    }
  }
}