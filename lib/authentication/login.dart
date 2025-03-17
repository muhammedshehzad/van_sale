import 'package:flutter/material.dart';
import 'package:odoo_rpc/odoo_rpc.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main_pages/order_picking_page.dart';
import '../provider_and_models/cyllo_session_model.dart';
import '../provider_and_models/order_picking_provider.dart';
import '../provider_and_models/sales_order_provider.dart';
import '../widgets/snackbar.dart';

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final formKey = GlobalKey<FormState>();
  bool urlCheck = false;
  bool disableFields = false;
  String? Database;
  bool? frstLogin;

  String? errorMessage;
  bool isLoading = false;
  List<DropdownMenuItem<String>> dropdownItems = [];
  OdooClient? client;
  TextEditingController urlController =
      TextEditingController(text: "http://10.0.2.2:8018/");
  TextEditingController emailController = TextEditingController();
  TextEditingController passwordController = TextEditingController();

  Future<void> login() async {
    if (formKey.currentState?.validate() ?? false) {
      setState(() {
        isLoading = true;
        errorMessage = null;
        disableFields = true;
      });
      try {
        final prefs = await SharedPreferences.getInstance();
        client = OdooClient(urlController.text.trim());
        final savedDb = prefs.getString('database');
        if (savedDb == null || savedDb.isEmpty) {
          setState(() {
            errorMessage = 'No database selected.';
            disableFields = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text('No database selected. Please choose a database first.'),
            ),
          );
          return;
        }

        var session = await client!.authenticate(
          savedDb,
          emailController.text.trim(),
          passwordController.text.trim(),
        );

        if (session != null) {
          final sessionModel = CylloSessionModel.fromOdooSession(
              session,
              passwordController.text.trim(),
              urlController.text.trim(),
              savedDb);

          await sessionModel.saveToPrefs();

          // final salesProvider =
          //     Provider.of<SalesOrderProvider>(context, listen: false);
          // final shortageProvider =
          //     Provider.of<OrderPickingProvider>(context, listen: false);

          // await salesProvider.loadProducts();

          // await shortageProvider.loadCustomers();

          final provider =
              Provider.of<OrderPickingProvider>(context, listen: false);

          provider.showProductSelectionPage(context);
        } else {
          setState(() {
            errorMessage = 'Authentication failed: No session returned.';
            disableFields = false;
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text('$errorMessage')));
          });
        }
      } on OdooException {
        setState(() {
          errorMessage = 'Invalid username or password.';
          final snackBar = CustomSnackbar()
              .showSnackBar("error", '$errorMessage', "error", () {});
          ScaffoldMessenger.of(context).showSnackBar(snackBar);
        });
      } catch (e) {
        setState(() {
          errorMessage = 'Network Error';
          final snackBar = CustomSnackbar()
              .showSnackBar("error", '$errorMessage', "error", () {});
          ScaffoldMessenger.of(context).showSnackBar(snackBar);
        });
      } finally {
        setState(() {
          isLoading = false;
          disableFields = false;
        });
      }
    }
  }

  Future<void> addShared() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', true);
    final savedDb = prefs.getString('database');
    await prefs.setString('selectedDatabase', savedDb!);
    await prefs.setString('url', urlController.text.trim());
  }

  Future<void> saveSession(OdooSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userName', session.userName ?? '');
    await prefs.setString('userLogin', session.userLogin?.toString() ?? '');
    await prefs.setInt('userId', session.userId ?? 0);
    await prefs.setString('sessionId', session.id);
    await prefs.setString('password', passwordController.text.trim());

    await prefs.setString('serverVersion', session.serverVersion ?? '');
    await prefs.setString('userLang', session.userLang ?? '');
    await prefs.setInt('partnerId', session.partnerId ?? 0);
    await prefs.setBool('isSystem', session.isSystem ?? false);
    await prefs.setString('userTimezone', session.userTz);
  }

  Future<void> saveLogin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('urldata', urlController.text);
    await prefs.setString('emaildata', emailController.text);
    await prefs.setString('passworddata', passwordController.text);

    if (Database != null && Database!.isNotEmpty) {
      await prefs.setString('database', Database!);
    }
  }

  Future<String?> loginCheck() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUrl = prefs.getString('urldata');
    print(savedUrl);
    final savedDb = prefs.getString('database');
    print(savedDb);

    if (savedUrl != null && savedDb != null && savedDb.isNotEmpty) {
      setState(() {
        frstLogin = false;
        Database = savedDb;
      });
    } else {
      setState(() {
        frstLogin = true;
      });
    }
  }

  Future<void> fetchDatabaseList() async {
    setState(() {
      isLoading = true;
      urlCheck = false;
    });

    try {
      final baseUrl = urlController.text.trim();
      print(baseUrl);
      client = OdooClient(baseUrl);
      final response = await client!.callRPC('/web/database/list', 'call', {});
      final dbList = response as List<dynamic>;
      setState(() {
        dropdownItems = dbList
            .map((db) => DropdownMenuItem<String>(
                  value: db,
                  child: Text(db),
                ))
            .toList();
        urlCheck = true;
        errorMessage = null;
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Error fetching database list: $e';
        Database = null;
        urlCheck = false;
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  void initState() {
    loginCheck();
    if (urlController.text.isNotEmpty) {
      fetchDatabaseList();
    }
    // TODO: implement initState
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 120,
                  child: Center(
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: primaryColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.local_shipping_rounded,
                        size: 48,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(24.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: neutralGrey.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Form(
                    key: formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Sign In",
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "Enter your details to continue",
                          style: TextStyle(
                            fontSize: 14,
                            color: neutralGrey,
                          ),
                        ),
                        const SizedBox(height: 24),
                        if (frstLogin == true) ...[
                          _buildClassicTextField(
                            controller: urlController,
                            label: "Server URL",
                            icon: Icons.dns_rounded,
                            color: primaryColor,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Enter a URL';
                              }
                              final RegExp newReg = RegExp(
                                r'^(https?:\/\/)'
                                r'(([a-zA-Z0-9-_]+\.)+[a-zA-Z]{2,}'
                                r'|(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}))'
                                r'(:\d{1,5})?'
                                r'(\/[^\s]*)?$',
                                caseSensitive: false,
                              );
                              if (!newReg.hasMatch(value)) {
                                return 'Enter a valid URL';
                              }
                              return null;
                            },
                            onChanged: (value) {
                              fetchDatabaseList();
                            },
                            enabled: !disableFields,
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            decoration: _buildClassicInputDecoration(
                              label: "Database",
                              icon: Icons.storage_rounded,
                              color: primaryColor,
                            ),
                            dropdownColor: Colors.white,
                            icon: Icon(Icons.arrow_drop_down,
                                color: primaryColor),
                            isExpanded: true,
                            hint: const Text("Select a database"),
                            value: Database,
                            items: urlCheck ? dropdownItems : [],
                            onChanged: disableFields
                                ? null
                                : (value) {
                                    setState(() {
                                      Database = value;
                                    });
                                  },
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return "Database is required";
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                        ],
                        _buildClassicTextField(
                          controller: emailController,
                          label: "Email",
                          icon: Icons.email_outlined,
                          color: primaryColor,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return "Email is required";
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildClassicTextField(
                          controller: passwordController,
                          label: "Password",
                          icon: Icons.lock_outline,
                          color: primaryColor,
                          obscureText: true,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return "Password is required";
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: isLoading
                                ? null
                                : () {
                                    if (Database == null && frstLogin == true) {
                                      errorMessage = 'Choose Database first';
                                      final snackBar =
                                          CustomSnackbar().showSnackBar(
                                        "error",
                                        errorMessage!,
                                        "Select",
                                        () {
                                          print("Select database pressed");
                                        },
                                      );
                                      // ScaffoldMessenger.of(context)
                                      //     .showSnackBar(snackBar);
                                    } else {
                                      saveLogin();
                                      login();
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                              elevation: 1,
                            ),
                            child: isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text(
                                    'Sign In',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Center(
                          child: TextButton(
                            onPressed: () {
                              setState(() {
                                frstLogin = !frstLogin!;
                              });
                            },
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                vertical: 6,
                                horizontal: 12,
                              ),
                            ),
                            child: Text(
                              frstLogin == true
                                  ? 'Hide Database Options'
                                  : 'Manage Database',
                              style: TextStyle(
                                fontSize: 14,
                                color: primaryDarkColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildClassicTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required Color color,
    bool obscureText = false,
    FormFieldValidator<String>? validator,
    ValueChanged<String>? onChanged,
    bool enabled = true,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      enabled: enabled,
      onChanged: onChanged,
      validator: validator,
      decoration: _buildClassicInputDecoration(
        label: label,
        icon: icon,
        color: color,
      ),
      style: TextStyle(
        fontSize: 15,
        color: const Color(0xFF212121),
      ),
    );
  }

  InputDecoration _buildClassicInputDecoration({
    required String label,
    required IconData icon,
    required Color color,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: color, size: 20),
      labelStyle: TextStyle(color: Color(0xFF757575)),
      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: BorderSide(color: Color(0xFFE0E0E0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: BorderSide(color: Color(0xFFE0E0E0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: BorderSide(color: color, width: 1.5),
      ),
      filled: true,
      fillColor: Colors.white,
    );
  }
}
