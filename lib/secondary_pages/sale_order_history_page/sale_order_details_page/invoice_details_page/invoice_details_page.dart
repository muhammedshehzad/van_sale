import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:van_sale_applicatioin/secondary_pages/sale_order_history_page/sale_order_details_page/sale_order_detail_provider.dart';
import 'package:van_sale_applicatioin/secondary_pages/sale_order_history_page/sale_order_details_page/invoice_details_page/payment_page.dart';
import 'package:van_sale_applicatioin/widgets/page_transition.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';

class InvoiceDetailsPage extends StatelessWidget {
  final Map<String, dynamic> invoiceData;
  final SaleOrderDetailProvider provider;

  const InvoiceDetailsPage({
    Key? key,
    required this.invoiceData,
    required this.provider,
  }) : super(key: key);

  Future<void> _downloadPDF(BuildContext context) async {
    final pdf = pw.Document();

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

    // Extract invoice data
    final invoiceNumber = invoiceData['name'] ?? 'Draft';
    final invoiceDate = invoiceData['invoice_date'] ?? '';
    final dueDate = invoiceData['invoice_date_due'] ?? '';
    final customerName = invoiceData['partner_id']?[1] ?? 'Unknown Customer';
    final customerReference = invoiceData['ref'] ?? '';
    final paymentTerms =
        invoiceData['invoice_payment_term_id']?[1] ?? 'Not specified';
    final currency = invoiceData['currency_id']?[1] ?? 'USD';
    final amountUntaxed = invoiceData['amount_untaxed'] as double? ?? 0.0;
    final amountTax = invoiceData['amount_tax'] as double? ?? 0.0;
    final amountTotal = invoiceData['amount_total'] as double? ?? 0.0;
    final amountResidual =
        invoiceData['amount_residual'] as double? ?? amountTotal;
    final invoiceLines =
        List<Map<String, dynamic>>.from(invoiceData['invoice_line_ids'] ?? []);

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
                    pw.Text('Date: $invoiceDate',
                        style: const pw.TextStyle(fontSize: 12)),
                    pw.Text('Due Date: $dueDate',
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
                final quantity = (line['quantity'] as num?)?.toDouble() ?? 0.0;
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
                        provider.currencyFormat.format(unitPrice),
                        style: const pw.TextStyle(fontSize: 10),
                        textAlign: pw.TextAlign.right,
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        taxName.isNotEmpty
                            ? '$taxName (${provider.currencyFormat.format(taxAmount)})'
                            : '-',
                        style: const pw.TextStyle(fontSize: 10),
                        textAlign: pw.TextAlign.right,
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        discount > 0 ? '${discount.toStringAsFixed(1)}%' : '-',
                        style: const pw.TextStyle(fontSize: 10),
                        textAlign: pw.TextAlign.right,
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        provider.currencyFormat.format(total),
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
                          provider.currencyFormat.format(amountUntaxed),
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
                          provider.currencyFormat.format(amountTax),
                          style: const pw.TextStyle(fontSize: 12),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.blue50),
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
                          provider.currencyFormat.format(amountTotal),
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
                            provider.currencyFormat.format(amountResidual),
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
    final invoiceCode =
        (invoiceData['name'] ?? 'draft').replaceAll(RegExp(r'[^\w\s-]'), '_');
    final safeFilename = '$invoiceCode.pdf';

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: safeFilename,
    );
  }

  void _showPaymentDialog(BuildContext context) {
    final amountController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    DateTime selectedDate = DateTime.now();
    String paymentMethod = 'Cash';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Record Payment'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Payment Amount',
                  prefixText: '\$ ',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an amount';
                  }
                  final amount = double.tryParse(value);
                  if (amount == null || amount <= 0) {
                    return 'Please enter a valid amount';
                  }
                  if (amount >
                      (invoiceData['amount_residual'] ??
                          invoiceData['amount_total'])) {
                    return 'Amount exceeds remaining balance';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: paymentMethod,
                decoration: const InputDecoration(labelText: 'Payment Method'),
                items: ['Cash', 'Credit Card', 'Bank Transfer', 'Check']
                    .map((method) => DropdownMenuItem(
                          value: method,
                          child: Text(method),
                        ))
                    .toList(),
                onChanged: (value) {
                  paymentMethod = value!;
                },
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) {
                    selectedDate = date;
                  }
                },
                child: Text(
                  'Payment Date: ${DateFormat('MMM dd, yyyy').format(selectedDate)}',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                // final paymentAmount = double.parse(amountController.text);
                // provider.recordPayment(
                //   invoiceId: invoiceData['id'],
                //   amount: paymentAmount,
                //   paymentMethod: paymentMethod,
                //   paymentDate: selectedDate,
                // );
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Payment recorded successfully')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFA12424),
              foregroundColor: Colors.white,
            ),
            child: const Text('Record'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Invoice data extraction
    final invoiceNumber =
        invoiceData['name'] != false ? invoiceData['name'] as String : 'Draft';
    final invoiceDate = invoiceData['invoice_date'] != false
        ? DateTime.parse(invoiceData['invoice_date'] as String)
        : null;
    final dueDate = invoiceData['invoice_date_due'] != false
        ? DateTime.parse(invoiceData['invoice_date_due'] as String)
        : null;
    final invoiceState = invoiceData['state'] as String;
    final invoiceAmount = invoiceData['amount_total'] as double;
    final amountResidual =
        invoiceData['amount_residual'] as double? ?? invoiceAmount;
    final isFullyPaid = amountResidual <= 0;
    final invoiceLines =
        List<Map<String, dynamic>>.from(invoiceData['invoice_line_ids'] ?? []);

    // Additional invoice data
    final customerName =
        invoiceData['partner_id']?[1] as String? ?? 'Unknown Customer';
    final customerReference = invoiceData['ref'] as String? ?? '';
    final paymentTerms =
        invoiceData['invoice_payment_term_id']?[1] as String? ??
            'Not specified';
    final salesperson = invoiceData['user_id']?[1] as String? ?? 'Unassigned';
    final currency = invoiceData['currency_id']?[1] as String? ?? 'USD';
    final invoiceOrigin = invoiceData['invoice_origin'] as String? ?? '';

    // Calculate payment status
    final percentagePaid = invoiceAmount > 0
        ? ((invoiceAmount - amountResidual) / invoiceAmount * 100).clamp(0, 100)
        : 0.0;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(
          'Invoice $invoiceNumber',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        backgroundColor: const Color(0xFFA12424),
        actions: [
          IconButton(
            icon: const Icon(Icons.print, color: Colors.white),
            onPressed: () => _downloadPDF(context),
            tooltip: 'Print PDF',
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status banner
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 16),
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      provider.getInvoiceStatusColor(provider
                          .formatInvoiceState(invoiceState, isFullyPaid)),
                      provider
                          .getInvoiceStatusColor(provider.formatInvoiceState(
                              invoiceState, isFullyPaid))
                          .withOpacity(0.7),
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.3),
                      spreadRadius: 1,
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(
                      isFullyPaid ? Icons.check_circle : Icons.pending_actions,
                      color: Colors.white,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            provider.formatInvoiceState(
                                invoiceState, isFullyPaid),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (!isFullyPaid && invoiceAmount > 0)
                            Text(
                              'Amount due: ${provider.currencyFormat.format(amountResidual)} ($currency)',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.white,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Invoice Header
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            invoiceNumber,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          if (invoiceOrigin.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.blue[300]!,
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                'Origin: $invoiceOrigin',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue[700],
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        customerName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      if (customerReference.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Reference: $customerReference',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      const Divider(height: 1),
                      const SizedBox(height: 16),
                      if (invoiceDate != null)
                        _buildInfoRow(
                          Icons.calendar_today,
                          'Invoice Date',
                          DateFormat('MMM dd, yyyy').format(invoiceDate),
                        ),
                      if (dueDate != null)
                        _buildInfoRow(
                          Icons.event,
                          'Due Date',
                          DateFormat('MMM dd, yyyy').format(dueDate),
                          dueDate.isBefore(DateTime.now()) && !isFullyPaid
                              ? Colors.red[700]
                              : null,
                        ),
                      _buildInfoRow(
                        Icons.account_circle,
                        'Salesperson',
                        salesperson,
                      ),
                      _buildInfoRow(
                        Icons.schedule,
                        'Payment Terms',
                        paymentTerms,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Payment Progress
              if (!isFullyPaid && invoiceAmount > 0) ...[
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle('Payment Progress'),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${percentagePaid.toStringAsFixed(1)}% paid',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: LinearProgressIndicator(
                                      value: percentagePaid / 100,
                                      backgroundColor: Colors.grey[200],
                                      color: const Color(0xFFA12424),
                                      minHeight: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${provider.currencyFormat.format(invoiceAmount - amountResidual)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  'of ${provider.currencyFormat.format(invoiceAmount)}',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Invoice Lines
              Text(
                'Invoice Lines',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 8),

              // const SizedBox(height: 20),

              // Pricing Summary
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle('Pricing Summary'),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                                invoiceData['amount_untaxed'] as double),
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[800],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Taxes:',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                            ),
                          ),
                          Text(
                            provider.currencyFormat
                                .format(invoiceData['amount_tax'] as double),
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[800],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFA12424).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Total:',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${provider.currencyFormat.format(invoiceAmount)} $currency',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFA12424),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!isFullyPaid) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.red[200]!,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Amount Due:',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                '${provider.currencyFormat.format(amountResidual)} $currency',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.download_rounded,
                          color: Colors.white),
                      label: const Text('Download PDF'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[800],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () => _downloadPDF(context),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.payment, color: Colors.white),
                      label: const Text('Record Payment'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isFullyPaid ? Colors.grey[400] : const Color(0xFFA12424),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: isFullyPaid
                          ? null
                          : () {
                        debugPrint('Record Payment button pressed');
                        debugPrint('isFullyPaid: $isFullyPaid');
                        debugPrint('invoiceData: $invoiceData');
                        try {
                          Navigator.push(
                            context,SlidingPageTransitionRL(page: PaymentPage(invoiceData: invoiceData),)
                          );
                          debugPrint('Navigated to PaymentPage');
                        } catch (e) {
                          debugPrint('Navigation error: $e');
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: const BoxDecoration(
            color: Color(0xFFA12424),
            borderRadius: BorderRadius.all(Radius.circular(2)),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFFA12424),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value,
      [Color? valueColor]) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
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
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: valueColor,
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
