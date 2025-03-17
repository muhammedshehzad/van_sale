import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:animated_custom_dropdown/custom_dropdown.dart';

import '../provider_and_models/cyllo_session_model.dart';
import '../provider_and_models/sales_order_provider.dart';
import '../widgets/customer_dialog.dart';

const Color primaryColor = Color(0xFFA12424);
const Color primaryDarkColor = Color(0xFF6D1717);
const double kBorderRadius = 8.0;

// Add Customer class if not already imported

class FormSummaryPage extends StatefulWidget {
  final Map<String, dynamic> formData;

  const FormSummaryPage({Key? key, required this.formData}) : super(key: key);

  @override
  _FormSummaryPageState createState() => _FormSummaryPageState();
}
class _FormSummaryPageState extends State<FormSummaryPage> {
  Customer? _selectedCustomer;
  List<Customer> customers = [];
  bool isLoadingCustomers = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      loadCustomers();
    });
  }

  Future<void> loadCustomers() async {
    setState(() {
      isLoadingCustomers = true;
    });

    try {
      final client = await SessionManager.getActiveClient();
      if (client != null) {
        final result = await client.callKw({
          'model': 'res.partner',
          'method': 'search_read',
          'args': [],
          'kwargs': {
            'fields': [
              'id',
              'name',
              'phone',
              'email',
              'city',
              'company_id',
            ],
          },
        });

        final List<Customer> fetchedCustomers =
        (result as List).map((customerData) {
          return Customer(
            id: customerData['id'].toString(),
            name: customerData['name'] ?? 'Unnamed Customer',
            phone:
            customerData['phone'] is String ? customerData['phone'] : null,
            email:
            customerData['email'] is String ? customerData['email'] : null,
            city: customerData['city'] is String ? customerData['city'] : null,
            companyId: customerData['company_id'] ?? false,
          );
        }).toList();

        fetchedCustomers.sort((a, b) => a.name.compareTo(b.name));
        setState(() {
          customers = fetchedCustomers;
        });
      }
    } catch (e) {
      log("Error fetching customers: $e");
    } finally {
      setState(() {
        isLoadingCustomers = false;
      });
    }
  }

  void showCreateCustomerDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => CreateCustomerDialog(
        onCustomerCreated: (Customer newCustomer) {
          setState(() {
            customers.add(newCustomer);
            customers.sort((a, b) => a.name.compareTo(b.name));
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Customer created successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        },
      ),
    );
  }

  void showCustomerSelectionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('Select Customer'),
            content: Container(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton.icon(
                        onPressed: () => showCreateCustomerDialog(context),
                        icon: const Icon(Icons.add_circle_outline,
                            color: primaryColor, size: 16),
                        label: const Text(
                          'Create Customer',
                          style: TextStyle(color: primaryColor),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          loadCustomers();
                          setState(() {
                            _selectedCustomer = null;
                          });
                        },
                        icon: const Icon(Icons.refresh,
                            color: primaryColor, size: 16),
                        label: const Text(
                          'Refresh',
                          style: TextStyle(color: primaryColor),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  isLoadingCustomers
                      ? const Center(
                      child: SizedBox(
                          height: 40,
                          child: CircularProgressIndicator()))
                      : CustomDropdown<Customer>.search(
                    items: customers,
                    hintText: 'Select Customer',
                    searchHintText: 'Search customers...',
                    noResultFoundText: customers.isEmpty
                        ? 'No customers found. Create a new customer?'
                        : 'No matching customers found',
                    noResultFoundBuilder: customers.isEmpty
                        ? (context, searchText) {
                      return GestureDetector(
                        onTap: () =>
                            showCreateCustomerDialog(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 12, horizontal: 16),
                          child: Row(
                            children: [
                              const Icon(Icons.add_circle,
                                  color: primaryColor),
                              const SizedBox(width: 8),
                              const Text(
                                'Create New Customer',
                                style: TextStyle(
                                  color: primaryColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                        : null,
                    decoration: CustomDropdownDecoration(
                      closedBorder: Border.all(color: Colors.grey),
                      closedBorderRadius: BorderRadius.circular(5),
                      expandedBorderRadius: BorderRadius.circular(5),
                      listItemDecoration: const ListItemDecoration(
                        selectedColor: primaryColor,
                      ),
                      headerStyle: const TextStyle(
                        color: Colors.black87,
                        fontSize: 16,
                      ),
                      searchFieldDecoration: const SearchFieldDecoration(
                        hintStyle: TextStyle(color: Colors.grey),
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: primaryColor),
                        ),
                      ),
                    ),
                    initialItem: _selectedCustomer,
                    headerBuilder: (context, customer, isSelected) {
                      return Text(customer.name);
                    },
                    listItemBuilder:
                        (context, customer, isSelected, onItemSelect) {
                      return GestureDetector(
                        onTap: onItemSelect,
                        child: Padding(
                          padding:
                          const EdgeInsets.symmetric(vertical: 3),
                          child: SizedBox(
                            height: 25,
                            child: Row(
                              children: [
                                Text(
                                  customer.name,
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.black,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                                const Spacer(),
                                if (isSelected)
                                  const Icon(Icons.check,
                                      color: Colors.white),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                    onChanged: (Customer? newCustomer) {
                      setState(() {
                        _selectedCustomer = newCustomer;
                      });
                      if (newCustomer != null) {
                        widget.formData['shop_info']['name'] =
                            newCustomer.name;
                        widget.formData['shop_info']['contact_person'] =
                            newCustomer.name;
                        widget.formData['shop_info']['contact_number'] =
                            newCustomer.phone ?? '';
                        widget.formData['shop_info']['location'] =
                            newCustomer.city ?? '';
                      }
                    },
                    validator: (value) {
                      if (value == null) {
                        return 'Please select a customer';
                      }
                      return null;
                    },
                    excludeSelected: false,
                    canCloseOutsideBounds: true,
                    closeDropDownOnClearFilterSearch: true,
                  ),
                  if (_selectedCustomer != null) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Customer Details:',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: primaryDarkColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Phone: ${_selectedCustomer!.phone ?? 'N/A'}',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    Text(
                      'Email: ${_selectedCustomer!.email ?? 'N/A'}',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    Text(
                      'City: ${_selectedCustomer!.city ?? 'N/A'}',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                ),
                onPressed: _selectedCustomer == null
                    ? null
                    : () {
                  Navigator.pop(dialogContext);
                  confirmOrder();
                },
                child: const Text('Confirm'),
              ),
            ],
          ),
        );
      },
    );
  }

  void confirmOrder() {
    if (_selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select a customer first'),
          backgroundColor: Colors.red,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(kBorderRadius)),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
        ),
      );
      return;
    }

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
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Order Summary - ${widget.formData['order_id']}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            )),
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
                      'Order ID: ${widget.formData['order_id']}',
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
                        _buildInfoRow(
                            'Name', widget.formData['shop_info']['name']),
                        _buildInfoRow('Location',
                            widget.formData['shop_info']['location']),
                        _buildInfoRow('Contact Person',
                            widget.formData['shop_info']['contact_person']),
                        _buildInfoRow('Mobile No',
                            widget.formData['shop_info']['contact_number']),
                      ],
                    ),
                    _buildSection(
                      title: 'Delivery Information',
                      icon: Icons.local_shipping,
                      children: [
                        _buildInfoRow(
                            'Date', widget.formData['delivery_info']['date']),
                        _buildInfoRow('Priority',
                            widget.formData['delivery_info']['priority']),
                        _buildInfoRow(
                            'Slot', widget.formData['delivery_info']['slot']),
                      ],
                    ),
                    _buildSection(
                      title: 'Products',
                      icon: Icons.inventory,
                      children: widget.formData['products']
                          .map<Widget>((product) {
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
                    if (widget.formData['additional_notes'].isNotEmpty)
                      _buildSection(
                        title: 'Additional Notes',
                        icon: Icons.note,
                        children: [
                          Text(
                            widget.formData['additional_notes'],
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
              padding:
              const EdgeInsets.symmetric(horizontal: 4.0, vertical: 6),
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
                  showCustomerSelectionDialog(context);
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