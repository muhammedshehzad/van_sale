import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../provider_and_models/order_picking_provider.dart';
import 'page_transition.dart';

final ThemeData appTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.light(
    primary: primaryColor,
    onPrimary: Colors.white,
    secondary: primaryColor,
    onSecondary: Colors.white,
    background: backgroundColor,
    surface: Colors.white,
    error: primaryDarkColor,
  ),
  appBarTheme: AppBarTheme(
    backgroundColor: primaryColor,
    foregroundColor: Colors.white,
    centerTitle: false,
    elevation: 0,
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: primaryColor,
      foregroundColor: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
    ),
  ),
  cardTheme: CardTheme(
    color: Colors.white,
    elevation: 2,
    margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
  ),
  textTheme: TextTheme(
    displayLarge: TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.bold,
      color: Colors.black,
    ),
    displayMedium: TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.bold,
      color: Colors.black,
    ),
    titleLarge: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: Colors.black,
    ),
    titleMedium: TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w500,
      color: Colors.black,
    ),
    bodyLarge: TextStyle(
      fontSize: 16,
      color: Colors.black,
    ),
    bodyMedium: TextStyle(
      fontSize: 14,
      color: Colors.black,
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: primaryColor.withOpacity(0.3)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: primaryColor.withOpacity(0.3)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: primaryColor, width: 2),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    labelStyle: TextStyle(color: primaryColor),
    floatingLabelStyle: TextStyle(color: primaryColor),
  ),
);

// Driver Home Page
class DriverHomePage extends StatefulWidget {
  const DriverHomePage({Key? key}) : super(key: key);

  @override
  _DriverHomePageState createState() => _DriverHomePageState();
}

class _DriverHomePageState extends State<DriverHomePage> {
  int assignedDeliveries = 3;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Driver Dashboard"),
        actions: [
          IconButton(
            onPressed: () => Navigator.push(
              context,
              SlidingPageTransitionRL(
                page: MapPage(address: '37.7749, -122.4194'),
              ),
            ),
            icon: const Icon(Icons.map),
            tooltip: 'Map',
          ),
          IconButton(
            onPressed: () => Navigator.push(
              context,
              SlidingPageTransitionRL(page: EarningsPage()),
            ),
            icon: const Icon(Icons.attach_money),
            tooltip: 'Earnings',
          ),
          IconButton(
            onPressed: () => Navigator.push(
              context,
              SlidingPageTransitionRL(page: ProfilePage()),
            ),
            icon: const Icon(Icons.person),
            tooltip: 'Profile',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Welcome, Driver!",
                style: Theme.of(context).textTheme.displayLarge,
              ),
              const SizedBox(height: 8),
              Text(
                "Tuesday, March 18, 2025",
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _buildStatsCard(
                      Icon(Icons.local_shipping, color: primaryColor, size: 32),
                      "$assignedDeliveries",
                      "Assigned Deliveries",
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildStatsCard(
                      Icon(Icons.check_circle, color: primaryColor, size: 32),
                      "0",
                      "Completed Today",
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                "Quick Actions",
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              _buildActionCard(
                Icons.list_alt,
                "View Deliveries",
                "See all your assigned deliveries",
                () => Navigator.push(
                  context,
                  SlidingPageTransitionRL(page: DeliveriesPage()),
                ),
              ),
              _buildActionCard(
                Icons.attach_money,
                "Earnings",
                "Check your earnings and payment history",
                () => Navigator.push(
                  context,
                  SlidingPageTransitionRL(page: EarningsPage()),
                ),
              ),
              _buildActionCard(
                Icons.person,
                "Profile",
                "Update your profile information",
                () => Navigator.push(
                  context,
                  SlidingPageTransitionRL(page: ProfilePage()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsCard(Icon icon, String value, String label) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            icon,
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.displayMedium,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: primaryColor),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: primaryColor),
            ],
          ),
        ),
      ),
    );
  }
}

// Deliveries Page
class DeliveriesPage extends StatefulWidget {
  const DeliveriesPage({Key? key}) : super(key: key);

  @override
  _DeliveriesPageState createState() => _DeliveriesPageState();
}

class _DeliveriesPageState extends State<DeliveriesPage> {
  final List<Map<String, String>> deliveries = [
    {
      "id": "SO001",
      "address": "123 Main St, City",
      "time": "10:00-12:00",
      "packages": "2",
      "status": "Pending"
    },
    {
      "id": "SO002",
      "address": "456 Oak Rd, Town",
      "time": "14:00-16:00",
      "packages": "1",
      "status": "In Transit"
    },
    {
      "id": "SO003",
      "address": "789 Pine Ave, Village",
      "time": "16:00-18:00",
      "packages": "3",
      "status": "Pending"
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("My Deliveries"),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: deliveries.length,
        itemBuilder: (context, index) {
          final delivery = deliveries[index];
          return _buildDeliveryCard(delivery, context);
        },
      ),
    );
  }

  Widget _buildDeliveryCard(
      Map<String, String> delivery, BuildContext context) {
    Color statusColor = primaryColor;

    return Card(
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          SlidingPageTransitionRL(
            page: DeliveryDetailsPage(delivery: delivery),
          ),
        ),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Order #${delivery['id']}",
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      delivery['status']!,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.location_on, color: primaryColor, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      delivery['address']!,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.access_time, color: primaryColor, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    delivery['time']!,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.inventory_2, color: primaryColor, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    "${delivery['packages']!} packages",
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      SlidingPageTransitionRL(
                        page: MapPage(address: delivery['address']!),
                      ),
                    ),
                    icon: Icon(Icons.directions, color: primaryColor),
                    label:
                        Text("Navigate", style: TextStyle(color: primaryColor)),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            DeliveryDetailsPage(delivery: delivery),
                      ),
                    ),
                    icon: Icon(Icons.visibility, color: primaryColor),
                    label:
                        Text("Details", style: TextStyle(color: primaryColor)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class DeliveryDetailsPage extends StatefulWidget {
  final Map<String, String> delivery;

  const DeliveryDetailsPage({Key? key, required this.delivery})
      : super(key: key);

  @override
  _DeliveryDetailsPageState createState() => _DeliveryDetailsPageState();
}

class _DeliveryDetailsPageState extends State<DeliveryDetailsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Order #${widget.delivery['id']}"),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDeliveryProgress(widget.delivery['status'] ?? 'Pending'),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Customer Information",
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 16),
                          _buildInfoRow(Icons.person, "Name", "John Doe"),
                          const SizedBox(height: 8),
                          _buildInfoRow(Icons.phone, "Phone", "(555) 123-4567"),
                          const SizedBox(height: 8),
                          _buildInfoRow(
                            Icons.location_on,
                            "Address",
                            widget.delivery['address']!,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Delivery Information",
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 16),
                          _buildInfoRow(
                            Icons.schedule,
                            "Time Window",
                            widget.delivery['time']!,
                          ),
                          const SizedBox(height: 8),
                          _buildInfoRow(
                            Icons.inventory_2,
                            "Packages",
                            "${widget.delivery['packages']} items",
                          ),
                          const SizedBox(height: 8),
                          _buildInfoRow(
                            Icons.message,
                            "Instructions",
                            "Leave at front door",
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            SlidingPageTransitionRL(
                              page:
                                  MapPage(address: widget.delivery['address']!),
                            ),
                          ),
                          icon: const Icon(Icons.directions),
                          label: const Text("Navigate"),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("Marked as Picked Up"),
                                behavior: SnackBarBehavior.floating,
                                backgroundColor: primaryColor,
                              ),
                            );
                          },
                          icon: const Icon(Icons.shopping_bag),
                          label: const Text("Mark as Picked Up"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("Marked as Delivered"),
                                behavior: SnackBarBehavior.floating,
                                backgroundColor: primaryColor,
                              ),
                            );
                          },
                          icon: const Icon(Icons.check_circle),
                          label: const Text("Mark as Delivered"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryProgress(String status) {
    int currentStep;
    switch (status) {
      case 'In Transit':
        currentStep = 1;
        break;
      case 'Delivered':
        currentStep = 2;
        break;
      case 'Pending':
      default:
        currentStep = 0;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      color: backgroundColor,
      child: Stepper(
        currentStep: currentStep,
        controlsBuilder: (context, details) => Container(),
        steps: [
          Step(
            title: Text("Pending", style: TextStyle(color: primaryDarkColor)),
            content: Container(),
            isActive: currentStep >= 0,
            state: currentStep > 0 ? StepState.complete : StepState.indexed,
          ),
          Step(
            title:
                Text("In Transit", style: TextStyle(color: primaryDarkColor)),
            content: Container(),
            isActive: currentStep >= 1,
            state: currentStep > 1 ? StepState.complete : StepState.indexed,
          ),
          Step(
            title: Text("Delivered", style: TextStyle(color: primaryDarkColor)),
            content: Container(),
            isActive: currentStep >= 2,
            state: currentStep > 2 ? StepState.complete : StepState.indexed,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: primaryColor, size: 18),
        const SizedBox(width: 8),
        Text(
          "$label: ",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: primaryDarkColor,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      ],
    );
  }
}

// Map Page
class MapPage extends StatefulWidget {
  final String address;

  const MapPage({Key? key, required this.address}) : super(key: key);

  @override
  _MapPageState createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  late GoogleMapController mapController;
  final LatLng _initialPosition = const LatLng(37.7749, -122.4194);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text("Navigate to ${widget.address}"),
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _initialPosition,
              zoom: 14,
            ),
            onMapCreated: (controller) => mapController = controller,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            mapToolbarEnabled: false,
            zoomControlsEnabled: false,
          ),
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.location_on, color: primaryColor),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.address,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Opening in external maps app"),
                              backgroundColor: primaryColor,
                            ),
                          );
                        },
                        icon: const Icon(Icons.directions),
                        label: const Text("Start Navigation"),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 160,
            right: 20,
            child: FloatingActionButton(
              onPressed: () {
                mapController.animateCamera(
                  CameraUpdate.newCameraPosition(
                    CameraPosition(target: _initialPosition, zoom: 14),
                  ),
                );
              },
              backgroundColor: primaryColor,
              tooltip: 'My Location',
              child: const Icon(Icons.my_location),
            ),
          )
        ],
      ),
    );
  }
}

// Earnings Page
class EarningsPage extends StatefulWidget {
  const EarningsPage({Key? key}) : super(key: key);

  @override
  _EarningsPageState createState() => _EarningsPageState();
}

class _EarningsPageState extends State<EarningsPage> {
  final List<Map<String, String>> earnings = [
    {"id": "SO001", "amount": "10.50", "date": "2025-03-16"},
    {"id": "SO002", "amount": "8.75", "date": "2025-03-15"},
    {"id": "SO003", "amount": "12.25", "date": "2025-03-14"},
    {"id": "SO004", "amount": "9.30", "date": "2025-03-13"},
  ];

  @override
  Widget build(BuildContext context) {
    double total =
        earnings.fold(0, (sum, item) => sum + double.parse(item['amount']!));

    return Scaffold(
      appBar: AppBar(
        title: const Text("Earnings"),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            width: double.infinity,
            decoration: BoxDecoration(
              color: primaryColor,
              boxShadow: [
                BoxShadow(
                  color: primaryDarkColor.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  "Total Earnings",
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "\$${total.toStringAsFixed(2)}",
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildEarningsMetric(
                        "This Week", "\$${total.toStringAsFixed(2)}"),
                    _buildEarningsMetric(
                        "This Month", "\$${(total * 2).toStringAsFixed(2)}"),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Text(
                  "Recent Earnings",
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {},
                  child:
                      Text("View All", style: TextStyle(color: primaryColor)),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: earnings.length,
              itemBuilder: (context, index) {
                final earning = earnings[index];
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child:
                              Icon(Icons.local_shipping, color: primaryColor),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Order #${earning['id']}",
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Date: ${earning['date']}",
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                        Text(
                          "\$${earning['amount']}",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEarningsMetric(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.white.withOpacity(0.7),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}

// Profile Page
class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final TextEditingController nameController =
      TextEditingController(text: "John Doe");
  final TextEditingController phoneController =
      TextEditingController(text: "(555) 123-4567");
  final TextEditingController emailController =
      TextEditingController(text: "john.doe@example.com");
  final TextEditingController vehicleController =
      TextEditingController(text: "Toyota Camry");
  final TextEditingController licensePlateController =
      TextEditingController(text: "ABC123");

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Profile"),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              margin: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(width: 4, color: Colors.white70),
                borderRadius: BorderRadius.circular(8),
                color: primaryColor,
              ),
              child: Column(
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                    child: Center(
                      child: Text(
                        "JD",
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    nameController.text,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Driver ID: D-12345",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Personal Information",
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: nameController,
                    label: "Full Name",
                    icon: Icons.person,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: phoneController,
                    label: "Phone Number",
                    icon: Icons.phone,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: emailController,
                    label: "Email Address",
                    icon: Icons.email,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    "Vehicle Information",
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: vehicleController,
                    label: "Vehicle Model",
                    icon: Icons.directions_car,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: licensePlateController,
                    label: "License Plate",
                    icon: Icons.confirmation_number,
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("Profile Updated Successfully"),
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: primaryColor,
                          ),
                        );
                      },
                      icon: const Icon(Icons.save),
                      label: const Text("Save Changes"),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          Navigator.popUntil(context, (route) => route.isFirst),
                      icon: Icon(Icons.logout, color: primaryDarkColor),
                      label: Text("Logout",
                          style: TextStyle(color: primaryDarkColor)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: primaryDarkColor),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: primaryColor),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}
