import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:van_sale_applicatioin/main_pages/select_products_page/order_picking_provider.dart';
import 'package:van_sale_applicatioin/secondary_pages/sale_order_creation/sales_order_provider.dart';
import 'package:van_sale_applicatioin/secondary_pages/sale_order_history_page/sale_order_details_page/sale_order_detail_provider.dart';
import 'package:van_sale_applicatioin/secondary_pages/sale_order_history_page/sale_order_details_page/delivery_details_page/delivey_details_page.dart';
import 'authentication/login_page.dart';

final appTheme = ThemeData(
  primaryColor: primaryColor,
  colorScheme: ColorScheme.fromSwatch().copyWith(
    primary: primaryColor,
    secondary: primaryColor,
  ),
  scaffoldBackgroundColor: Colors.grey[100],
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeCameras();
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

class _MyAppState extends State<MyApp> {
  bool _isLoading = true;
  bool _isLoggedIn = false;
  String? _errorMessage;
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    final progressTracker = ProgressTracker(
      tasks: [
        ProgressTask(name: 'Checking login', weight: 0.2),
        ProgressTask(name: 'Loading products', weight: 0.3),
        ProgressTask(name: 'Loading customers', weight: 0.3),
        ProgressTask(name: 'Fetching order details', weight: 0.2),
      ],
      onProgressUpdate: (progress) {
        setState(() {
          _progress = progress;
        });
      },
    );

    try {
      // Task 1: Check login status
      final prefs = await SharedPreferences.getInstance();
      final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
      progressTracker.completeTask('Checking login');

      if (isLoggedIn) {
        final orderProvider = Provider.of<OrderPickingProvider>(context, listen: false);
        final salesProvider = Provider.of<SalesOrderProvider>(context, listen: false);

        // Task 2: Load products
        await salesProvider.loadProducts();
        progressTracker.completeTask('Loading products');

        // Task 3: Load customers
        await orderProvider.loadCustomers(); // Changed to await for sequential progress
        progressTracker.completeTask('Loading customers');

        // Task 4: Fetch order details
        final orderData = {'id': 1}; // Replace with actual order data
        final saleOrderDetailProvider = SaleOrderDetailProvider(orderData: orderData);
        await saleOrderDetailProvider.fetchOrderDetails();
        progressTracker.completeTask('Fetching order details');
      }

      setState(() {
        _isLoggedIn = isLoggedIn;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: appTheme,
      debugShowCheckedModeBanner: false,
      home: _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return LoadingScreen(
        message: 'Loading...',
        progress: _progress,
      );
    }
    if (_errorMessage != null) {
      return ErrorScreen(
        errorMessage: _errorMessage!,
        onRetry: () {
          setState(() {
            _isLoading = true;
            _errorMessage = null;
            _progress = 0.0;
          });
          _checkLoginStatus();
        },
      );
    }
    if (_isLoggedIn) {
      return const HomeScreen();
    }
    return const Login();
  }
}

class ProgressTask {
  final String name;
  final double weight;

  ProgressTask({required this.name, required this.weight});
}

class ProgressTracker {
  final List<ProgressTask> tasks;
  final Function(double) onProgressUpdate;
  final Map<String, bool> _completedTasks = {};

  ProgressTracker({required this.tasks, required this.onProgressUpdate}) {
    for (var task in tasks) {
      _completedTasks[task.name] = false;
    }
  }

  void completeTask(String taskName) {
    _completedTasks[taskName] = true;
    _updateProgress();
  }

  void _updateProgress() {
    double totalWeight = tasks.fold(0.0, (sum, task) => sum + task.weight);
    double completedWeight = tasks.fold(0.0, (sum, task) {
      return sum + (_completedTasks[task.name]! ? task.weight : 0.0);
    });
    double progress = totalWeight > 0 ? completedWeight / totalWeight : 0.0;
    onProgressUpdate(progress);
  }
}

class LoadingScreen extends StatefulWidget {
  final String message;
  final double progress;

  const LoadingScreen({super.key, required this.message, required this.progress});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _progressAnimation = Tween<double>(begin: 0.0, end: widget.progress).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant LoadingScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progress != widget.progress) {
      _progressAnimation = Tween<double>(
        begin: _progressAnimation.value,
        end: widget.progress,
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
      _controller
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 100,
              height: 100,
              child: AnimatedBuilder(
                animation: _progressAnimation,
                builder: (context, child) {
                  return CustomPaint(
                    painter: RadialProgressPainter(
                      progress: _progressAnimation.value,
                      progressColor: primaryColor,
                      backgroundColor: Colors.grey[300]!,
                    ),
                    child: Center(
                      child: Text(
                        '${(_progressAnimation.value * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Text(widget.message, style: const TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }
}

class RadialProgressPainter extends CustomPainter {
  final double progress;
  final Color progressColor;
  final Color backgroundColor;

  RadialProgressPainter({
    required this.progress,
    required this.progressColor,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;


    final backgroundPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8;
    canvas.drawCircle(center, radius, backgroundPaint);

    // Progress arc
    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -90 * (3.14159 / 180), // Start at top
      2 * 3.14159 * progress, // Sweep angle based on progress
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant RadialProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.progressColor != progressColor ||
        oldDelegate.backgroundColor != backgroundColor;
  }
}
class ErrorScreen extends StatelessWidget {
  final String errorMessage;
  final VoidCallback onRetry;
  const ErrorScreen({super.key, required this.errorMessage, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 60),
            const SizedBox(height: 16),
            const Text('Something went wrong', style: TextStyle(fontSize: 20)),
            const SizedBox(height: 8),
            Text(errorMessage, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<OrderPickingProvider>(context, listen: false)
          .showProductSelectionPage(context);
    });
    return const LoadingScreen(message: 'Preparing workspace...', progress: 1.0);
  }
}