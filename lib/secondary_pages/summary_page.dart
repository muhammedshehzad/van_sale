import 'package:flutter/material.dart';

const Color primaryColor = Color(0xFFA12424);
const Color primaryDarkColor = Color(0xFF6D1717);
const double kBorderRadius = 8.0;

class FormSummaryPage extends StatelessWidget {
  final Map<String, dynamic> formData;

  const FormSummaryPage({Key? key, required this.formData}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Order Summary - ${formData['order_id']}',style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
        ),),
        backgroundColor: primaryColor,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order ID: ${formData['order_id']}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: primaryDarkColor,
                      ),
                    ),
                    _buildSection(
                      title: 'Shop Information',
                      icon: Icons.store,
                      children: [
                        _buildInfoRow('Name', formData['shop_info']['name']),
                        _buildInfoRow(
                            'Location', formData['shop_info']['location']),
                        _buildInfoRow('Contact Person',
                            formData['shop_info']['contact_person']),
                        _buildInfoRow('Mobile No',
                            formData['shop_info']['contact_number']),
                      ],
                    ),
                    _buildSection(
                      title: 'Delivery Information',
                      icon: Icons.local_shipping,
                      children: [
                        _buildInfoRow(
                            'Date', formData['delivery_info']['date']),
                        _buildInfoRow(
                            'Priority', formData['delivery_info']['priority']),
                        _buildInfoRow(
                            'Slot', formData['delivery_info']['slot']),
                      ],
                    ),
                    _buildSection(
                      title: 'Products',
                      icon: Icons.inventory,
                      children: formData['products'].map<Widget>((product) {
                        return Card(
                          elevation: 2,
                          margin: const EdgeInsets.only(bottom: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(kBorderRadius),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.check_circle_outline,
                                        size: 20, color: primaryColor),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        product['name'],
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                _buildInfoRow('Quantity',
                                    '${product['quantity']} ${product['unit']}',
                                    dense: true),
                                _buildInfoRow('Category', product['category'],
                                    dense: true),
                                _buildInfoRow('Urgency', product['urgency'],
                                    dense: true),
                                if (product['notes'].isNotEmpty)
                                  _buildInfoRow('Notes', product['notes'],
                                      dense: true),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    if (formData['additional_notes'].isNotEmpty)
                      _buildSection(
                        title: 'Additional Notes',
                        icon: Icons.note,
                        children: [
                          Text(
                            formData['additional_notes'],
                            style: TextStyle(
                              color: Colors.grey[800],
                              fontSize: 14,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            // Confirmation Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 6),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(kBorderRadius),
                  ),
                  minimumSize: const Size(double.infinity, 0),
                  elevation: 4,
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Order confirmed successfully!'),
                      backgroundColor: primaryColor,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(kBorderRadius)),
                      behavior: SnackBarBehavior.floating,
                      margin: const EdgeInsets.all(16),
                    ),
                  );
                  Navigator.of(context).pop();
                },
                child: const Text(
                  'Confirm Order',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: primaryDarkColor, size: 24),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: primaryDarkColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(kBorderRadius),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool dense = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: dense ? 4 : 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: dense ? 14 : 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: dense ? 14 : 16,
                color: Colors.grey[800],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
