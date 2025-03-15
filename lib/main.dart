import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:van_sale_applicatioin/provider_and_models/order_picking_provider.dart';
import 'package:van_sale_applicatioin/provider_and_models/sales_order_provider.dart';

import 'authentication/login.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => SalesOrderProvider()),
        ChangeNotifierProvider(create: (context) => OrderPickingProvider()),
      ],
      child: MaterialApp(
        theme: ThemeData(
        ),
        home: const Login(),
      ),
    ),
  );
}
