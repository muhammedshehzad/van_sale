import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';

class InvoiceDetailsProvider extends ChangeNotifier {
  Map<String, dynamic> _invoiceData = {};
  bool _isLoading = false;
  String _errorMessage = '';
  final NumberFormat currencyFormat =
      NumberFormat.currency(symbol: '\$', decimalDigits: 2);

  // Getters
  Map<String, dynamic> get invoiceData => _invoiceData;

  bool get isLoading => _isLoading;

  String get errorMessage => _errorMessage;

  // Derived properties
  String get invoiceNumber =>
      _invoiceData['name'] != false ? _invoiceData['name'] as String : 'Draft';

  DateTime? get invoiceDate => _invoiceData['invoice_date'] != false
      ? DateTime.parse(_invoiceData['invoice_date'] as String)
      : null;

  DateTime? get dueDate => _invoiceData['invoice_date_due'] != false
      ? DateTime.parse(_invoiceData['invoice_date_due'] as String)
      : null;

  String get invoiceState => _invoiceData['state'] as String? ?? '';

  double get invoiceAmount => _invoiceData['amount_total'] as double? ?? 0.0;

  double get amountResidual =>
      _invoiceData['amount_residual'] as double? ?? invoiceAmount;

  bool get isFullyPaid => amountResidual <= 0;

  List<Map<String, dynamic>> get invoiceLines =>
      List<Map<String, dynamic>>.from(_invoiceData['invoice_line_ids'] ?? []);

  // Customer info
  String get customerName =>
      _invoiceData['partner_id']?[1] as String? ?? 'Unknown Customer';

  String get customerReference => _invoiceData['ref'] as String? ?? '';

  String get paymentTerms =>
      _invoiceData['invoice_payment_term_id']?[1] as String? ?? 'Not specified';

  String get salesperson =>
      _invoiceData['user_id']?[1] as String? ?? 'Unassigned';

  String get currency => _invoiceData['currency_id']?[1] as String? ?? 'USD';

  String get invoiceOrigin => _invoiceData['invoice_origin'] as String? ?? '';

  // Payment status
  double get percentagePaid => invoiceAmount > 0
      ? ((invoiceAmount - amountResidual) / invoiceAmount * 100).clamp(0, 100)
      : 0.0;

  double get amountUntaxed => _invoiceData['amount_untaxed'] as double? ?? 0.0;

  double get amountTax => _invoiceData['amount_tax'] as double? ?? 0.0;

  // Initialize with invoice data
  void setInvoiceData(Map<String, dynamic> data) {
    _invoiceData = data;
    notifyListeners();
  }

  // Helper methods
  String formatInvoiceState(String state, bool isFullyPaid) {
    if (isFullyPaid) return 'Paid';

    switch (state) {
      case 'draft':
        return 'Draft';
      case 'posted':
        return 'Posted';
      case 'cancel':
        return 'Cancelled';
      default:
        return state;
    }
  }

  Color getInvoiceStatusColor(String status) {
    switch (status) {
      case 'Paid':
        return Colors.green[700]!;
      case 'Posted':
        return Colors.orange[700]!;
      case 'Draft':
        return Colors.blue[700]!;
      case 'Cancelled':
        return Colors.red[700]!;
      default:
        return Colors.grey[700]!;
    }
  }

  void updateInvoiceData(Map<String, dynamic> updatedData) {
    _invoiceData = {
      ..._invoiceData,
      ...updatedData,
    };
    notifyListeners();
  }

  // Record a payment

  // Generate and share PDF
  Future<void> generateAndSharePdf(BuildContext context) async {
    final pdf = pw.Document();

    try {
      // Load the custom font from assets
      final fontData = await DefaultAssetBundle.of(context)
          .load('lib/assets/texts/Inter-VariableFont_opsz,wght.ttf');
      final regularFont = pw.Font.ttf(
        fontData,
      );
      final boldFont = pw.Font.ttf(
        fontData,
      );

      // Company details (replace with actual details)
      const companyName = 'Van Sale Application';
      const companyAddress = '123 Business Street, Commerce City, CC 12345';
      const companyEmail = 'contact@vansale.com';
      const companyPhone = '+1 (123) 456-7890';

      pdf.addPage(
        pw.MultiPage(
          pageTheme: pw.PageTheme(
            margin: const pw.EdgeInsets.all(32),
            theme: pw.ThemeData.withFont(
              base: regularFont,
              bold: boldFont,
            ),
          ),
          header: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        companyName,
                        style: pw.TextStyle(
                          fontSize: 20,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue800,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(companyAddress,
                          style: const pw.TextStyle(fontSize: 10)),
                      pw.Text('Email: $companyEmail',
                          style: const pw.TextStyle(fontSize: 10)),
                      pw.Text('Phone: $companyPhone',
                          style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                  pw.Text(
                    'INVOICE',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.red800,
                    ),
                  ),
                ],
              ),
              pw.Divider(),
              pw.SizedBox(height: 16),
            ],
          ),
          build: (context) => [
            // Customer and Invoice Details
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Billed To:',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(customerName,
                          style: const pw.TextStyle(fontSize: 12)),
                      if (customerReference.isNotEmpty)
                        pw.Text('Ref: $customerReference',
                            style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                ),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Invoice Details:',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text('Invoice #: $invoiceNumber',
                          style: const pw.TextStyle(fontSize: 12)),
                      if (invoiceDate != null)
                        pw.Text(
                            'Date: ${DateFormat('yyyy-MM-dd').format(invoiceDate!)}',
                            style: const pw.TextStyle(fontSize: 12)),
                      if (dueDate != null)
                        pw.Text(
                            'Due Date: ${DateFormat('yyyy-MM-dd').format(dueDate!)}',
                            style: const pw.TextStyle(fontSize: 12)),
                      pw.Text('Terms: $paymentTerms',
                          style: const pw.TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 24),

            // Invoice Lines Table
            pw.Text(
              'Invoice Lines',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue800,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
              columnWidths: {
                0: const pw.FlexColumnWidth(3),
                1: const pw.FlexColumnWidth(1),
                2: const pw.FlexColumnWidth(1),
                3: const pw.FlexColumnWidth(1),
                4: const pw.FlexColumnWidth(1),
                5: const pw.FlexColumnWidth(1),
              },
              children: [
                // Table Header
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        'Description',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        'Qty',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                        ),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        'Unit Price',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                        ),
                        textAlign: pw.TextAlign.right,
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        'Tax',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                        ),
                        textAlign: pw.TextAlign.right,
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        'Discount',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                        ),
                        textAlign: pw.TextAlign.right,
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        'Total',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                        ),
                        textAlign: pw.TextAlign.right,
                      ),
                    ),
                  ],
                ),
                // Table Rows
                ...invoiceLines.map((line) {
                  final productName = line['name'] ?? 'Unknown';
                  final quantity =
                      (line['quantity'] as num?)?.toDouble() ?? 0.0;
                  final unitPrice = line['price_unit'] as double? ?? 0.0;
                  final subtotal = line['price_subtotal'] as double? ?? 0.0;
                  final total = line['price_total'] as double? ?? 0.0;
                  final taxAmount = total - subtotal;
                  final discount = line['discount'] as double? ?? 0.0;
                  final taxName = line['tax_ids'] is List &&
                          line['tax_ids'].isNotEmpty &&
                          line['tax_ids'][0] is List &&
                          line['tax_ids'][0].length > 1
                      ? line['tax_ids'][0][1] as String? ?? ''
                      : '';

                  return pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(productName,
                            style: const pw.TextStyle(fontSize: 10)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          quantity.toStringAsFixed(
                              quantity.truncateToDouble() == quantity ? 0 : 2),
                          style: const pw.TextStyle(fontSize: 10),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          currencyFormat.format(unitPrice),
                          style: const pw.TextStyle(fontSize: 10),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          taxName.isNotEmpty
                              ? '$taxName (${currencyFormat.format(taxAmount)})'
                              : '-',
                          style: const pw.TextStyle(fontSize: 10),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          discount > 0
                              ? '${discount.toStringAsFixed(1)}%'
                              : '-',
                          style: const pw.TextStyle(fontSize: 10),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          currencyFormat.format(total),
                          style: const pw.TextStyle(fontSize: 10),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                    ],
                  );
                }),
              ],
            ),
            pw.SizedBox(height: 24),

            // Summary Table
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Container(
                width: 300,
                child: pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  children: [
                    pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            'Subtotal',
                            style: pw.TextStyle(
                              fontSize: 12,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            currencyFormat.format(amountUntaxed),
                            style: const pw.TextStyle(fontSize: 12),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            'Taxes',
                            style: pw.TextStyle(
                              fontSize: 12,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            currencyFormat.format(amountTax),
                            style: const pw.TextStyle(fontSize: 12),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                    pw.TableRow(
                      decoration:
                          const pw.BoxDecoration(color: PdfColors.blue50),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            'Total ($currency)',
                            style: pw.TextStyle(
                              fontSize: 12,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.blue800,
                            ),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            currencyFormat.format(invoiceAmount),
                            style: pw.TextStyle(
                              fontSize: 12,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.blue800,
                            ),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                    if (amountResidual > 0)
                      pw.TableRow(
                        decoration:
                            const pw.BoxDecoration(color: PdfColors.red50),
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(
                              'Amount Due ($currency)',
                              style: pw.TextStyle(
                                fontSize: 12,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.red800,
                              ),
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(
                              currencyFormat.format(amountResidual),
                              style: pw.TextStyle(
                                fontSize: 12,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.red800,
                              ),
                              textAlign: pw.TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
          footer: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Divider(),
              pw.SizedBox(height: 8),
              pw.Text(
                'Terms & Conditions',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                'Payment is due by the due date. Late payments may incur additional charges.',
                style: const pw.TextStyle(fontSize: 8),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Thank you for your business!',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue800,
                ),
              ),
            ],
          ),
        ),
      );

      // Sanitize the filename to use the invoice code
      final invoiceCode = (invoiceNumber).replaceAll(RegExp(r'[^\w\s-]'), '_');
      final safeFilename = '$invoiceCode.pdf';

      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename: safeFilename,
      );
    } catch (e) {
      _errorMessage = 'Failed to generate PDF: $e';
      notifyListeners();
    }
  }


}
