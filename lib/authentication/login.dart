import 'package:flutter/material.dart';
import 'package:odoo_rpc/odoo_rpc.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../provider_and_models/cyllo_session_model.dart';
import '../provider_and_models/order_picking_provider.dart';
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
  bool isLoadingDatabases = false;
  List<DropdownMenuItem<String>> dropdownItems = [];
  OdooClient? client;
  TextEditingController urlController =
      TextEditingController();
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
            isLoading = false;
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
            isLoading = false;
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text('$errorMessage')));
          });
        }
      } on OdooException {
        setState(() {
          errorMessage = 'Invalid username or password.';
          isLoading = false;
          disableFields = false;
          final snackBar = CustomSnackbar()
              .showSnackBar("error", '$errorMessage', "error", () {});
          ScaffoldMessenger.of(context).showSnackBar(snackBar);
        });
      } catch (e) {
        setState(() {
          errorMessage = 'Network Error';
          isLoading = false;
          disableFields = false;
          final snackBar = CustomSnackbar()
              .showSnackBar("error", '$errorMessage', "error", () {});
          ScaffoldMessenger.of(context).showSnackBar(snackBar);
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
    setState(() {
      isLoading = true; // Show loading indicator during initial setup
    });

    final prefs = await SharedPreferences.getInstance();
    final savedUrl = prefs.getString('urldata');
    final savedDb = prefs.getString('database');

    if (savedUrl != null && savedDb != null && savedDb.isNotEmpty) {
      setState(() {
        urlController.text = savedUrl;
        frstLogin = false;
        Database = savedDb;
      });
    } else {
      setState(() {
        frstLogin = true;
        Database = null; // Ensure Database is null if no valid saved value
      });
    }

    setState(() {
      isLoading = false;
    });
  }

  Future<void> fetchDatabaseList() async {
    setState(() {
      isLoadingDatabases = true;
      urlCheck = false;
    });

    try {
      final baseUrl = urlController.text.trim();
      client = OdooClient(baseUrl);
      final response = await client!.callRPC('/web/database/list', 'call', {});
      final dbList = response as List<dynamic>;

      final uniqueDbList = dbList.toSet().toList();
      setState(() {
        dropdownItems = uniqueDbList
            .map((db) => DropdownMenuItem<String>(
                  value: db.toString(),
                  child: Text(db.toString()),
                ))
            .toList();
        urlCheck = true;
        errorMessage = null;

        if (Database != null && !uniqueDbList.contains(Database)) {
          Database = null;
        }
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Error fetching database list: $e';
        Database = null;
        urlCheck = false;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Could not connect to server. Please verify the URL.'),
            backgroundColor: Colors.red[700],
          ),
        );
      });
    } finally {
      setState(() {
        isLoadingDatabases = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    loginCheck().then((_) {
      if (urlController.text.isNotEmpty) {
        fetchDatabaseList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage('lib/assets/mainlogo.jpeg'),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  Colors.black.withOpacity(0.3),
                  BlendMode.darken,
                ),
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: MediaQuery.of(context).size.width * 0.05,
                        vertical: 16.0,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            margin: EdgeInsets.only(
                              top: MediaQuery.of(context).size.height * 0.05,
                            ),
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
                          // Form Container
                          Container(
                            constraints: BoxConstraints(
                              maxWidth: 500,
                            ),
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
                            child: isLoading && frstLogin == null
                                ? Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        CircularProgressIndicator(
                                            color: primaryColor),
                                        SizedBox(height: 16),
                                        Text(
                                          "Loading user settings...",
                                          style: TextStyle(
                                            color: textColor,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : Form(
                                    key: formKey,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
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
                                              if (value == null ||
                                                  value.isEmpty) {
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
                                              // Don't immediately trigger fetch to avoid multiple API calls
                                              // We'll use a button instead
                                            },
                                            enabled: !disableFields &&
                                                !isLoadingDatabases,
                                            suffix: IconButton(
                                              icon: Icon(
                                                Icons.refresh,
                                                color: primaryColor,
                                                size: 20,
                                              ),
                                              onPressed: isLoadingDatabases
                                                  ? null
                                                  : fetchDatabaseList,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          // Database loading indicator
                                          if (isLoadingDatabases)
                                            Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 8.0),
                                              child: Row(
                                                children: [
                                                  SizedBox(
                                                    height: 16,
                                                    width: 16,
                                                    child:
                                                        CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: primaryColor,
                                                    ),
                                                  ),
                                                  SizedBox(width: 12),
                                                  Text(
                                                    "Fetching databases...",
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      color: primaryColor,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          const SizedBox(height: 8),
                                          DropdownButtonFormField<String>(
                                            decoration:
                                                _buildClassicInputDecoration(
                                              label: "Database",
                                              icon: Icons.storage_rounded,
                                              color: primaryColor,
                                            ),
                                            dropdownColor: Colors.white,
                                            icon: Icon(Icons.arrow_drop_down,
                                                color: primaryColor),
                                            isExpanded: true,
                                            hint: Text(isLoadingDatabases
                                                ? "Loading databases..."
                                                : "Select a database"),
                                            value: Database,
                                            items: urlCheck &&
                                                    dropdownItems.isNotEmpty
                                                ? dropdownItems
                                                : [],
                                            onChanged: (disableFields ||
                                                    isLoadingDatabases)
                                                ? null
                                                : (value) {
                                                    setState(() {
                                                      Database = value;
                                                    });
                                                  },
                                            validator: (value) {
                                              if (value == null ||
                                                  value.isEmpty) {
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
                                            if (value == null ||
                                                value.isEmpty) {
                                              return "Email is required";
                                            }
                                            return null;
                                          },
                                          enabled: !disableFields,
                                        ),
                                        const SizedBox(height: 16),
                                        _buildClassicTextField(
                                          controller: passwordController,
                                          label: "Password",
                                          icon: Icons.lock_outline,
                                          color: primaryColor,
                                          obscureText: true,
                                          validator: (value) {
                                            if (value == null ||
                                                value.isEmpty) {
                                              return "Password is required";
                                            }
                                            return null;
                                          },
                                          enabled: !disableFields,
                                        ),
                                        const SizedBox(height: 24),
                                        SizedBox(
                                          height: 48,
                                          child: ElevatedButton(
                                            onPressed:
                                                isLoading || isLoadingDatabases
                                                    ? null
                                                    : _handleSignIn,
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: primaryColor,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              elevation: 1,
                                            ),
                                            child: isLoading
                                                ? Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      SizedBox(
                                                        height: 20,
                                                        width: 20,
                                                        child:
                                                            CircularProgressIndicator(
                                                          color: Colors.white,
                                                          strokeWidth: 2,
                                                        ),
                                                      ),
                                                      SizedBox(width: 12),
                                                      Text(
                                                        'Signing In...',
                                                        style: TextStyle(
                                                          fontSize: 16,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                    ],
                                                  )
                                                : const Text(
                                                    'Sign In',
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        Center(
                                          child: TextButton(
                                            onPressed: (isLoading ||
                                                    isLoadingDatabases)
                                                ? null
                                                : () {
                                                    setState(() {
                                                      frstLogin = !frstLogin!;
                                                      // If showing database options, attempt to fetch databases
                                                      if (frstLogin == true) {
                                                        fetchDatabaseList();
                                                      }
                                                    });
                                                  },
                                            style: TextButton.styleFrom(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                vertical: 10,
                                                horizontal: 16,
                                              ),
                                              backgroundColor: primaryColor
                                                  .withOpacity(0.05),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                            ),
                                            child: Text(
                                              frstLogin == true
                                                  ? 'Hide Database Options'
                                                  : 'Manage Database',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: primaryDarkColor,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                          ),
                          // Version Text
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24.0),
                            child: Text(
                              "Van Sale App: version 1.0.3",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                                color: Colors.white,
                                shadows: [
                                  Shadow(
                                    offset: Offset(0, 1),
                                    blurRadius: 2.0,
                                    color: Colors.black.withOpacity(0.5),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          // Full-screen loading overlay
          if (disableFields && isLoading)
            Container(
              color: Colors.black45,
              child: Center(
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: primaryColor),
                        SizedBox(height: 16),
                        Text(
                          "Connecting to server...",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          "Please wait while we log you in",
                          style: TextStyle(
                            color: neutralGrey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _handleSignIn() {
    if (Database == null && frstLogin == true) {
      errorMessage = 'Choose Database first';
      final snackBar = CustomSnackbar().showSnackBar(
        "error",
        errorMessage!,
        "Select",
        () {
          print("Select database pressed");
        },
      );
      ScaffoldMessenger.of(context).showSnackBar(snackBar);
    } else {
      saveLogin();
      login();
    }
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
    Widget? suffix,
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
        suffix: suffix,
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
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: color, size: 20),
      suffixIcon: suffix,
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
