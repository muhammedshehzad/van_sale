import 'package:odoo_rpc/odoo_rpc.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CylloSessionModel {
  final String userName;
  final String userLogin;
  final int userId;
  final String sessionId;
  final String password;
  final String serverVersion;
  final String userLang;
  final int partnerId;
  final bool isSystem;
  final String userTimezone;
  final String serverUrl;
  final String database;

  CylloSessionModel({
    required this.userName,
    required this.userLogin,
    required this.userId,
    required this.sessionId,
    required this.password,
    required this.serverVersion,
    required this.userLang,
    required this.partnerId,
    required this.isSystem,
    required this.userTimezone,
    required this.serverUrl,
    required this.database,
  });

  factory CylloSessionModel.fromOdooSession(
      OdooSession session, String password, String serverUrl, String database) {
    return CylloSessionModel(
      userName: session.userName ?? '',
      userLogin: session.userLogin?.toString() ?? '',
      userId: session.userId ?? 0,
      sessionId: session.id,
      password: password,
      serverVersion: session.serverVersion ?? '',
      userLang: session.userLang ?? '',
      partnerId: session.partnerId ?? 0,
      isSystem: session.isSystem ?? false,
      userTimezone: session.userTz,
      serverUrl: serverUrl,
      database: database,
    );
  }

  factory CylloSessionModel.fromPrefs(SharedPreferences prefs) {
    return CylloSessionModel(
      userName: prefs.getString('userName') ?? '',
      userLogin: prefs.getString('userLogin') ?? '',
      userId: prefs.getInt('userId') ?? 0,
      sessionId: prefs.getString('sessionId') ?? '',
      password: prefs.getString('password') ?? '',
      serverVersion: prefs.getString('serverVersion') ?? '',
      userLang: prefs.getString('userLang') ?? '',
      partnerId: prefs.getInt('partnerId') ?? 0,
      isSystem: prefs.getBool('isSystem') ?? false,
      userTimezone: prefs.getString('userTimezone') ?? '',
      serverUrl: prefs.getString('url') ?? '',
      database: prefs.getString('selectedDatabase') ?? '',
    );
  }

  Future<void> saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userName', userName);
    await prefs.setString('userLogin', userLogin);
    await prefs.setInt('userId', userId);
    await prefs.setString('sessionId', sessionId);
    await prefs.setString('password', password);
    await prefs.setString('serverVersion', serverVersion);
    await prefs.setString('userLang', userLang);
    await prefs.setInt('partnerId', partnerId);
    await prefs.setBool('isSystem', isSystem);
    await prefs.setString('userTimezone', userTimezone);
    await prefs.setString('url', serverUrl);
    await prefs.setString('selectedDatabase', database);
    await prefs.setBool('isLoggedIn', true);
  }

  Future<OdooClient> createClient() async {
    final client = OdooClient(serverUrl);

    await client.authenticate(
      database,
      userLogin,
      password,
    );

    return client;
  }
}

class SessionManager {
  static Future<CylloSessionModel?> getCurrentSession() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

    if (!isLoggedIn) {
      return null;
    }

    return CylloSessionModel.fromPrefs(prefs);
  }

  static Future<OdooClient?> getActiveClient() async {
    final session = await getCurrentSession();
    if (session == null) {
      return null;
    }

    try {
      return await session.createClient();
    } catch (e) {
      print('Error creating Odoo client: $e');
      return null;
    }
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', false);

    // await prefs.clear();
  }
}
