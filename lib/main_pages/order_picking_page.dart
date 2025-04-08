import 'package:animated_custom_dropdown/custom_dropdown.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:developer';
import 'package:provider/provider.dart';
import '../provider_and_models/order_picking_provider.dart';
import '../provider_and_models/sales_order_provider.dart';


class OrderTakingPage extends StatefulWidget {
  const OrderTakingPage({Key? key}) : super(key: key);

  @override
  _OrderTakingPageState createState() => _OrderTakingPageState();
}

class _OrderTakingPageState extends State<OrderTakingPage> {
  Customer? _selectedCustomer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider =
          Provider.of<OrderPickingProvider>(context, listen: false);
      provider.initialize(context);
    });
  }

  @override
  void dispose() {
    Provider.of<OrderPickingProvider>(context, listen: false)
        .disposeControllers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SalesOrderProvider()),
        ChangeNotifierProvider(create: (_) => OrderPickingProvider()),
      ],
      child: Consumer<OrderPickingProvider>(
        builder: (context, provider, _) {
          Provider.of<SalesOrderProvider>(context);
          return Scaffold(
            backgroundColor: backgroundColor,
            appBar: AppBar(
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Order Picking Page',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  if (provider.currentOrderId != null)
                    Text(
                      provider.currentOrderId!,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                ],
              ),
              backgroundColor: primaryColor,
              elevation: 0,
            ),
            body: Form(
              key: provider.formKey,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Card(
                        color: Colors.white,
                        margin: const EdgeInsets.only(top: 16),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Shop Information',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: primaryDarkColor,
                                    ),
                                  ),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      TextButton.icon(
                                        onPressed: () => provider
                                            .showCreateCustomerDialog(context),
                                        icon: const Icon(
                                            Icons.add_circle_outline,
                                            color: primaryColor,
                                            size: 16),
                                        label: const Text(
                                          'Create Customer',
                                          style: TextStyle(color: primaryColor),
                                        ),
                                      ),
                                      TextButton.icon(
                                        onPressed: () {
                                          provider
                                              .loadCustomers(); // Keep this for manual refresh
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
                                ],
                              ),
                              const SizedBox(height: 16),
                              provider.isLoadingCustomers
                                  ? const Center(
                                      child: SizedBox(
                                          height: 40,
                                          child: CircularProgressIndicator()))
                                  : CustomDropdown<Customer>.search(
                                      items: provider.customers,
                                      hintText: 'Select Customer',
                                      searchHintText: 'Search customers...',
                                      noResultFoundText: provider
                                              .customers.isEmpty
                                          ? 'No customers found. Create a new customer?'
                                          : 'No matching customers found',
                                      noResultFoundBuilder: provider
                                              .customers.isEmpty
                                          ? (context, searchText) {
                                              return GestureDetector(
                                                onTap: () => provider
                                                    .showCreateCustomerDialog(
                                                        context),
                                                child: Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      vertical: 12,
                                                      horizontal: 16),
                                                  child: Row(
                                                    children: [
                                                      const Icon(
                                                          Icons.add_circle,
                                                          color: primaryColor),
                                                      const SizedBox(width: 8),
                                                      const Text(
                                                        'Create New Customer',
                                                        style: TextStyle(
                                                          color: primaryColor,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              );
                                            }
                                          : null,
                                      decoration: CustomDropdownDecoration(
                                        closedBorder:
                                            Border.all(color: Colors.grey),
                                        closedBorderRadius:
                                            BorderRadius.circular(5),
                                        expandedBorderRadius:
                                            BorderRadius.circular(5),
                                        listItemDecoration:
                                            const ListItemDecoration(
                                          selectedColor: primaryColor,
                                        ),
                                        headerStyle: const TextStyle(
                                          color: Colors.black87,
                                          fontSize: 16,
                                        ),
                                        searchFieldDecoration:
                                            const SearchFieldDecoration(
                                          hintStyle:
                                              TextStyle(color: Colors.grey),
                                          fillColor: Colors.white,
                                          border: OutlineInputBorder(
                                            borderSide:
                                                BorderSide(color: Colors.grey),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderSide: BorderSide(
                                              color: primaryColor,
                                            ),
                                          ),
                                        ),
                                      ),
                                      initialItem: _selectedCustomer,
                                      headerBuilder:
                                          (context, customer, isSelected) {
                                        return Text(customer.name);
                                      },
                                      listItemBuilder: (context, customer,
                                          isSelected, onItemSelect) {
                                        return GestureDetector(
                                          onTap: onItemSelect,
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 3),
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
                                        if (newCustomer != null) {
                                          setState(() {
                                            _selectedCustomer = newCustomer;
                                          });
                                          provider.shopNameController.text =
                                              newCustomer.name;
                                          provider.shopLocationController.text =
                                              newCustomer.city ?? '';
                                          provider.contactPersonController
                                              .text = newCustomer.name;
                                          provider.contactNumberController
                                              .text = newCustomer.phone ?? '';
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
                      ),
                      Card(
                        color: Colors.white,
                        margin: const EdgeInsets.only(top: 16),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Delivery Information',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: primaryDarkColor,
                                ),
                              ),
                              const SizedBox(height: 16),
                              GestureDetector(
                                onTap: () => provider.selectDate(context),
                                child: AbsorbPointer(
                                  child: TextFormField(
                                    decoration: const InputDecoration(
                                      labelText: 'Delivery Date',
                                      border: OutlineInputBorder(),
                                      prefixIcon: Icon(Icons.calendar_today,
                                          color: primaryColor),
                                      focusedBorder: OutlineInputBorder(
                                        borderSide:
                                            BorderSide(color: primaryColor),
                                      ),
                                    ),
                                    controller: TextEditingController(
                                      text: DateFormat('MMM dd, yyyy')
                                          .format(provider.deliveryDate),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              DropdownButtonFormField<String>(
                                decoration: const InputDecoration(
                                  labelText: 'Delivery Priority',
                                  border: OutlineInputBorder(),
                                  prefixIcon:
                                      Icon(Icons.flag, color: primaryColor),
                                  focusedBorder: OutlineInputBorder(
                                    borderSide: BorderSide(color: primaryColor),
                                  ),
                                ),
                                value: provider.priority,
                                items:
                                    provider.priorityLevels.map((String value) {
                                  return DropdownMenuItem<String>(
                                    value: value,
                                    child: Text(value),
                                  );
                                }).toList(),
                                onChanged: (newValue) =>
                                    provider.setPriority(newValue!),
                              ),
                              const SizedBox(height: 16),
                              DropdownButtonFormField<String>(
                                decoration: const InputDecoration(
                                  labelText: 'Delivery Time Slot',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.access_time,
                                      color: primaryColor),
                                  focusedBorder: OutlineInputBorder(
                                    borderSide: BorderSide(color: primaryColor),
                                  ),
                                ),
                                value: provider.deliverySlot,
                                items:
                                    provider.deliverySlots.map((String value) {
                                  return DropdownMenuItem<String>(
                                    value: value,
                                    child: Text(value),
                                  );
                                }).toList(),
                                onChanged: (newValue) =>
                                    provider.setDeliverySlot(newValue!),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Card(
                        color: Colors.white,
                        margin: const EdgeInsets.only(top: 16),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Products',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: primaryDarkColor,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.white,
                                          foregroundColor: primaryColor,
                                          elevation: 0,
                                          side: const BorderSide(
                                              color: primaryColor),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 12,
                                          ),
                                          minimumSize: const Size(0, 40),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                                kBorderRadius),
                                          ),
                                        ),
                                        onPressed: () =>
                                            provider.addNewProduct(context),
                                        child: const Text('Add Product'),
                                      ),
                                      const SizedBox(width: 8),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: primaryColor,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 12,
                                          ),
                                          minimumSize: const Size(0, 40),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                                kBorderRadius),
                                          ),
                                        ),
                                        onPressed: () => provider
                                            .showProductSelectionPage(context),
                                        child: const Text('Select Products'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              if (provider.products.isNotEmpty)
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Added Products:',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    ListView.builder(
                                      shrinkWrap: true,
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      itemCount: provider.products.length,
                                      itemBuilder: (context, index) {
                                        final product =
                                            provider.products[index];
                                        return Card(
                                          color: Colors.white,
                                          elevation: 1,
                                          margin: const EdgeInsets.symmetric(
                                              vertical: 4),
                                          child: ListTile(
                                            leading: Container(
                                              width: 50,
                                              height: 50,
                                              decoration: BoxDecoration(
                                                color: Colors.grey[200],
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: product.imageUrl != null &&
                                                      product
                                                          .imageUrl!.isNotEmpty
                                                  ? Image.memory(
                                                      base64Decode(product
                                                          .imageUrl!
                                                          .split(',')
                                                          .last),
                                                      fit: BoxFit.cover,
                                                      errorBuilder: (context,
                                                          error, stackTrace) {
                                                        log("Failed to load image for product ${product.nameController.text}: $error");
                                                        return const Icon(
                                                          Icons.inventory,
                                                          color: primaryColor,
                                                          size: 30,
                                                        );
                                                      },
                                                    )
                                                  : const Icon(
                                                      Icons.inventory,
                                                      color: primaryColor,
                                                      size: 30,
                                                    ),
                                            ),
                                            title: Text(
                                                product.nameController.text),
                                            subtitle: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Quantity needed: ${product.quantityController.text}',
                                                  style: TextStyle(
                                                      color: Colors.grey[600]),
                                                ),
                                              ],
                                            ),
                                            trailing: IconButton(
                                              icon: const Icon(
                                                Icons.close,
                                                color: primaryColor,
                                              ),
                                              onPressed: () =>
                                                  provider.removeProduct(index),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              if (provider.products.isEmpty)
                                Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.inventory_2_outlined,
                                          size: 48,
                                          color: Colors.grey[400],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'No products added yet.\nTap the buttons above to begin.',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontStyle: FontStyle.italic,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      Card(
                        color: Colors.white,
                        margin: const EdgeInsets.only(top: 16),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Additional Notes',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: primaryDarkColor,
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: provider.notesController,
                                decoration: const InputDecoration(
                                  labelText: 'Notes',
                                  border: OutlineInputBorder(),
                                  hintText:
                                      'Enter any additional information here...',
                                  focusedBorder: OutlineInputBorder(
                                    borderSide: BorderSide(color: primaryColor),
                                  ),
                                ),
                                maxLines: 3,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        // child: ElevatedButton(
                        //   onPressed: () => provider.submitForm(context),
                        //   style: ElevatedButton.styleFrom(
                        //     backgroundColor: primaryColor,
                        //     foregroundColor: Colors.white,
                        //     shape: RoundedRectangleBorder(
                        //       borderRadius: BorderRadius.circular(8),
                        //     ),
                        //   ),
                        //   child: const Text(
                        //     'Take Order',
                        //     style: TextStyle(
                        //       fontSize: 16,
                        //       fontWeight: FontWeight.bold,
                        //       letterSpacing: 0.5,
                        //     ),
                        //   ),
                        // ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}


class ProductItem {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController quantityController = TextEditingController();
  final TextEditingController notesController = TextEditingController();
  final TextEditingController salePriceController = TextEditingController();
  final TextEditingController costController = TextEditingController();
  final TextEditingController barcodeController = TextEditingController();
  String? imageUrl;
  String selectedProductType = 'product';
  String selectedUnit = 'Pieces';
  String selectedCategory = 'General';
  String selectedUrgency = 'Normal';
  int stockQuantity = 0;

  int? odooId;
  final List<String> units = ['Pieces', 'Kg', 'Liters', 'Boxes', 'Packets'];
  final List<String> categories = [
    'General',
    'Food',
    'Beverages',
    'Cleaning',
    'Personal Care',
    'Stationery',
    'Electronics'
  ];
  final List<String> urgencyLevels = ['Low', 'Normal', 'High', 'Critical'];
}

class ProductCard extends StatefulWidget {
  final Product product;
  final Function(int) onAddToOrder;

  const ProductCard({
    Key? key,
    required this.product,
    required this.onAddToOrder,
  }) : super(key: key);

  @override
  _ProductCardState createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  late int currentInventory;

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<SalesOrderProvider>(context, listen: false);
    currentInventory = provider.getAvailableQuantity(widget.product.id);
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<SalesOrderProvider>(context);
    final quantityController = TextEditingController();
    final categoryName =
        widget.product.categId is List && widget.product.categId.length == 2
            ? widget.product.categId[1].toString()
            : 'No Category';

    return Card(
      color: Colors.white,
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(4),
            ),
            child: widget.product.imageUrl != null
                ? Image.memory(
                    base64Decode(widget.product.imageUrl!.split(',').last),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      log("Failed to load image for product ${widget.product.id}: $error");
                      return const Icon(Icons.inventory);
                    },
                  )
                : const Icon(Icons.inventory, size: 30),
          ),
          title: Text(
            widget.product.name,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          subtitle: Text(
              '\$${widget.product.price} • In stock: ${provider.getAvailableQuantity(widget.product.id)}'),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Enter a quantity';
                        }
                        final quantity = int.tryParse(value);
                        if (quantity == null || quantity <= 0) {
                          return 'Invalid quantity';
                        }
                        final available =
                            provider.getAvailableQuantity(widget.product.id);
                        if (available == 0) {
                          return 'No products available';
                        }
                        if (quantity > available) {
                          return 'Only $available in stock';
                        }
                        return null;
                      },
                      controller: quantityController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Quantity',
                        isDense: true,
                        contentPadding:
                            EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () {
                      final quantity =
                          int.tryParse(quantityController.text) ?? 0;
                      final available =
                          provider.getAvailableQuantity(widget.product.id);
                      if (quantity > 0 && quantity <= available) {
                        widget.onAddToOrder(quantity);
                        setState(() {
                          currentInventory = available - quantity;
                        });
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            padding: const EdgeInsets.all(16),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            margin: const EdgeInsets.all(10),
                            duration: const Duration(seconds: 2),
                            content: Text(
                              quantity > available
                                  ? 'Only $available in stock'
                                  : 'No products available or invalid quantity',
                            ),
                            backgroundColor: primaryColor,
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                    ),
                    child: const Text('Add'),
                  ),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Product ID: ${widget.product.id}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                      Text(
                          'Sellers: ${widget.product.sellerIds?.join(", ") ?? "N/A"}'),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('Internal Ref: ${widget.product.defaultCode ?? "N/A"}'),
                  const SizedBox(height: 4),
                  Text('Category: $categoryName'),
                  const SizedBox(height: 4),
                  Text(
                      "Production Location: ${widget.product.propertyStockProduction}"),
                  const SizedBox(height: 4),
                  Text(
                      "Inventory Location: ${widget.product.propertyStockInventory}"),
                  const SizedBox(height: 4),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
