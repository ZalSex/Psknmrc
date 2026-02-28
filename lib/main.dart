import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'services/api_service.dart';
import 'services/native_service.dart';
import 'utils/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
  ));
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  await ApiService.init();

  runApp(const PSKNMRCApp());
}

class PSKNMRCApp extends StatefulWidget {
  const PSKNMRCApp({super.key});

  @override
  State<PSKNMRCApp> createState() => _PSKNMRCAppState();
}

class _PSKNMRCAppState extends State<PSKNMRCApp> {
  Widget? _initialScreen;

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    final prefs       = await SharedPreferences.getInstance();
    final username    = prefs.getString('psknmrc_username') ?? '';
    final deviceId    = prefs.getString('deviceId')         ?? '';
    final deviceName  = prefs.getString('deviceName')       ?? '';
    final ownerUsername = prefs.getString('ownerUsername')  ?? '';
    final serverUrl   = ApiService.baseUrl;

    Widget screen;
    if (username.isNotEmpty && deviceId.isNotEmpty) {
      // Session ada → langsung auto-reconnect SocketService
      // Tidak perlu lewat SetupScreen lagi
      _autoReconnect(
        serverUrl:     serverUrl,
        deviceId:      deviceId,
        deviceName:    deviceName,
        ownerUsername: ownerUsername.isNotEmpty ? ownerUsername : username,
      );
      screen = HomeScreen(username: username);
    } else {
      screen = const LoginScreen();
    }
    setState(() => _initialScreen = screen);
  }

  Future<void> _autoReconnect({
    required String serverUrl,
    required String deviceId,
    required String deviceName,
    required String ownerUsername,
  }) async {
    // Simpan serverUrl ke prefs (butuh Kotlin)
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('serverUrl', serverUrl);

    // Start SocketService langsung tanpa nunggu user action
    await NativeService.startSocketService(
      serverUrl:     serverUrl,
      deviceId:      deviceId,
      deviceName:    deviceName,
      ownerUsername: ownerUsername,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PSKNMRC',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: _initialScreen ?? const _SplashScreen(),
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppTheme.darkBg,
      body: Center(child: CircularProgressIndicator(color: AppTheme.purple)),
    );
  }
}
