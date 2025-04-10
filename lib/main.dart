import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:van_sale_applicatioin/provider_and_models/order_picking_provider.dart';
import 'package:van_sale_applicatioin/provider_and_models/sales_order_provider.dart';
import 'package:van_sale_applicatioin/provider_and_models/sale_order_detail_provider.dart';
import 'authentication/login.dart';

final appTheme = ThemeData(
  primaryColor: primaryColor,
  colorScheme: ColorScheme.fromSwatch().copyWith(
    primary: primaryColor,
    secondary: primaryColor,
  ),
  scaffoldBackgroundColor: Colors.grey[100],
);

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SalesOrderProvider()),
        ChangeNotifierProvider(create: (_) => OrderPickingProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with SingleTickerProviderStateMixin {
  bool _isLoggedIn = false;
  bool _isLoading = true;
  String _message = 'Checking login status...';
  String? _errorMessage;
  late AnimationController _controller;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
    _fade = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance().timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw TimeoutException('Storage timeout'),
      );
      final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

      if (isLoggedIn) {
        setState(() => _message = 'Loading data...');
        final orderProvider =
            Provider.of<OrderPickingProvider>(context, listen: false);
        final salesProvider =
            Provider.of<SalesOrderProvider>(context, listen: false);
        await Future.wait([
          salesProvider.loadProducts().timeout(
                const Duration(seconds: 15),
                onTimeout: () => throw TimeoutException('Products timeout'),
              ),
          orderProvider.loadCustomers().timeout(
                const Duration(seconds: 15),
                onTimeout: () => throw TimeoutException('Customers timeout'),
              ),
        ]);

        final orderData = {'id': 1}; // Replace with actual order data
        final saleOrderDetailProvider =
            SaleOrderDetailProvider(orderData: orderData);
        await saleOrderDetailProvider.fetchOrderDetails();
        print(orderData);
      }
      setState(() {
        _isLoggedIn = isLoggedIn;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e is TimeoutException ? e.message : 'Error: $e';
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: appTheme,
      debugShowCheckedModeBanner: false,
      initialRoute: '/splash',
      routes: {
        '/splash': (context) => _buildSplashOrRedirect(),
        '/login': (context) => const Login(),
        '/home': (context) => _buildHome(),
      },
    );
  }

  Widget _buildSplashOrRedirect() {
    if (_isLoading) {
      return _buildLoading(_message);
    } else if (_errorMessage != null) {
      return _buildError();
    } else if (_isLoggedIn) {
      return _buildHome();
    } else {
      return const Login();
    }
  }

  Widget _buildHome() {
    return Builder(
      builder: (context) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Provider.of<OrderPickingProvider>(context, listen: false)
              .showProductSelectionPage(context);
        });
        return _buildLoading('Preparing workspace...');
      },
    );
  }

  Widget _buildLoading(String message) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FadeTransition(
              opacity: _fade,
              child: const CircularProgressIndicator(color: primaryColor),
            ),
            const SizedBox(height: 16),
            Text(message, style: const TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 60),
            const SizedBox(height: 16),
            const Text('Something went wrong', style: TextStyle(fontSize: 20)),
            const SizedBox(height: 8),
            Text(_errorMessage!, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _errorMessage = null;
                });
                _checkLoginStatus();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
