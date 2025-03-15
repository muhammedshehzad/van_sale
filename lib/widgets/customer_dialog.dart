import 'package:flutter/material.dart';
import 'dart:developer';
import '../provider_and_models/odoo_session_model.dart';
import '../provider_and_models/order_picking_provider.dart';
import '../provider_and_models/sales_order_provider.dart';

class CreateCustomerDialog extends StatefulWidget {
  final Function(Customer) onCustomerCreated;

  const CreateCustomerDialog({
    Key? key,
    required this.onCustomerCreated,
  }) : super(key: key);

  @override
  _CreateCustomerDialogState createState() => _CreateCustomerDialogState();
}

class _CreateCustomerDialogState extends State<CreateCustomerDialog> {
  final _formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final emailController = TextEditingController();
  final cityController = TextEditingController();
  bool isCreating = false;

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    cityController.dispose();
    super.dispose();
  }

  Future<void> _createCustomer() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      isCreating = true;
    });

    try {
      final client = await SessionManager.getActiveClient();
      if (client != null) {
        final customerData = {
          'name': nameController.text.trim(),
          'phone': phoneController.text.trim(),
          'email': emailController.text.trim(),
          'city': cityController.text.trim(),
          'customer_rank': 1, // Mark as customer
        };

        final result = await client.callKw({
          'model': 'res.partner',
          'method': 'create',
          'args': [customerData],
          'kwargs': {},
        });

        // Get the created customer details
        if (result != null) {
          final customerId = result.toString();

          final customerDetails = await client.callKw({
            'model': 'res.partner',
            'method': 'read',
            'args': [int.parse(customerId)],
            'kwargs': {
              'fields': ['id', 'name', 'phone', 'email', 'city', 'company_id'],
            },
          });

          if (customerDetails.isNotEmpty) {
            final customerData = customerDetails[0];
            final newCustomer = Customer(
              id: customerId,
              name: customerData['name'],
              phone: customerData['phone'],
              email: customerData['email'],
              city: customerData['city'],
              companyId: customerData['company_id'],
            );

            widget.onCustomerCreated(newCustomer);
            Navigator.of(context).pop();
            return;
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to create customer. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      log("Error creating customer: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        isCreating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kBorderRadius),
      ),
      elevation: 4,
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Create New Customer',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: primaryDarkColor,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Customer Name*',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(kBorderRadius),
                    ),
                    prefixIcon: const Icon(Icons.person, color: primaryColor),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter customer name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: phoneController,
                  decoration: InputDecoration(
                    labelText: 'Phone Number',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(kBorderRadius),
                    ),
                    prefixIcon: const Icon(Icons.phone, color: primaryColor),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: emailController,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(kBorderRadius),
                    ),
                    prefixIcon: const Icon(Icons.email, color: primaryColor),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value != null && value.isNotEmpty) {
                      // Simple email validation regex
                      final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                      if (!emailRegex.hasMatch(value)) {
                        return 'Please enter a valid email';
                      }
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: cityController,
                  decoration: InputDecoration(
                    labelText: 'City',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(kBorderRadius),
                    ),
                    prefixIcon: const Icon(Icons.location_city, color: primaryColor),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.grey[600],
                      ),
                      onPressed: isCreating ? null : () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(kBorderRadius),
                        ),
                      ),
                      onPressed: isCreating ? null : _createCustomer,
                      child: isCreating
                          ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          strokeWidth: 2.0,
                        ),
                      )
                          : const Text('Create Customer'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}