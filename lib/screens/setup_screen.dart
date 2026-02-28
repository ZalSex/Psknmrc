import 'dart:math';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/native_service.dart';
import '../utils/theme.dart';
import 'home_screen.dart';

class SetupScreen extends StatefulWidget {
  final String username;
  const SetupScreen({super.key, required this.username});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  int _step = 0; // 0=permissions, 1=connecting, 2=done
  String _statusMsg = 'Meminta izin yang diperlukan...';
  bool _done = false;
  String _error = '';

  final List<_PermItem> _perms = [
    _PermItem('Overlay (Draw Over App)', Icons.layers_rounded,           false),
    _PermItem('Notifikasi',              Icons.notifications_rounded,    false),
    _PermItem('Kamera/Flash',            Icons.flashlight_on_rounded,    false),
    _PermItem('Penyimpanan',             Icons.folder_rounded,           false),
    _PermItem('Mikrofon (TTS/Audio)',    Icons.mic_rounded,              false),
    _PermItem('Getaran (Vibrate)',       Icons.vibration_rounded,        false),
  ];

  @override
  void initState() {
    super.initState();
    _runSetup();
  }

  Future<void> _runSetup() async {
    await Future.delayed(const Duration(milliseconds: 500));

    // Step 1: Overlay
    setState(() => _statusMsg = 'Meminta izin Overlay...');
    bool overlayOk = await NativeService.checkOverlayPermission();
    if (!overlayOk) {
      await NativeService.requestOverlayPermission();
      await Future.delayed(const Duration(seconds: 3));
      overlayOk = await NativeService.checkOverlayPermission();
    }
    setState(() => _perms[0].granted = overlayOk);

    // Step 2: Notification
    setState(() => _statusMsg = 'Meminta izin Notifikasi...');
    final notifStatus = await Permission.notification.request();
    setState(() => _perms[1].granted = notifStatus.isGranted);

    // Step 3: Camera
    setState(() => _statusMsg = 'Meminta izin Kamera...');
    final camStatus = await Permission.camera.request();
    setState(() => _perms[2].granted = camStatus.isGranted);

    // Step 4: Storage
    setState(() => _statusMsg = 'Meminta izin Penyimpanan...');
    final storStatus = await Permission.storage.request();
    setState(() => _perms[3].granted = storStatus.isGranted || true); // not critical

    // Step 5: Microphone (untuk TTS audio focus & RECORD_AUDIO)
    setState(() => _statusMsg = 'Meminta izin Mikrofon...');
    final micStatus = await Permission.microphone.request();
    setState(() => _perms[4].granted = micStatus.isGranted || true); // not critical

    // Step 6: Vibrate — tidak perlu runtime request (normal permission), langsung granted
    setState(() { _perms[5].granted = true; });

    // Step 7: Connect to server
    setState(() { _step = 1; _statusMsg = 'Menghubungkan ke server...'; });
    await _connectToServer();
  }

  Future<void> _connectToServer() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final serverUrl = ApiService.baseUrl;
      // ownerUsername = user yang membuat akun ini (createdBy), bukan username login
      final ownerUsername = prefs.getString('ownerUsername') ?? widget.username;

      // Generate deviceId
      String deviceId = prefs.getString('deviceId') ?? '';
      if (deviceId.isEmpty) {
        deviceId = 'psknmrc_${_randomHex(8)}';
        await prefs.setString('deviceId', deviceId);
      }

      // Device name
      String deviceName = prefs.getString('deviceName') ?? '';
      if (deviceName.isEmpty) {
        deviceName = 'HP-${widget.username.toUpperCase()}-${_randomHex(4).toUpperCase()}';
        await prefs.setString('deviceName', deviceName);
      }

      setState(() => _statusMsg = 'Mendaftarkan device ke server...');

      // Register device (SocketService will do this too, but we also call it here
      // to get the token early for Flutter-side display)
      setState(() => _statusMsg = 'Memulai layanan background...');
      final started = await NativeService.startSocketService(
        serverUrl:     serverUrl,
        deviceId:      deviceId,
        deviceName:    deviceName,
        ownerUsername: ownerUsername,
      );

      if (!mounted) return;
      if (started) {
        setState(() { _step = 2; _done = true; _statusMsg = 'Berhasil terhubung!'; });
        await Future.delayed(const Duration(seconds: 2));
        if (!mounted) return;
        Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (_) => HomeScreen(username: widget.username)));
      } else {
        setState(() { _error = 'Gagal memulai layanan. Pastikan izin Overlay diberikan.'; });
      }
    } catch (e) {
      setState(() { _error = 'Error: $e'; });
    }
  }

  String _randomHex(int len) {
    final rng = Random.secure();
    return List.generate(len, (_) => rng.nextInt(16).toRadixString(16)).join();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Row(children: [
                Container(width: 3, height: 20,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [AppTheme.purple, AppTheme.purple2]),
                    borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 10),
                const Text('SETUP DEVICE', style: TextStyle(
                  fontFamily: 'Orbitron', fontSize: 16,
                  fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 3)),
              ]),
              const SizedBox(height: 6),
              Text('Halo, ${widget.username}! Sedang menyiapkan device...',
                style: const TextStyle(fontFamily: 'ShareTechMono',
                    fontSize: 11, color: AppTheme.textMuted)),
              const SizedBox(height: 32),

              // Permissions list
              ..._perms.map((p) => _buildPermRow(p)),
              const SizedBox(height: 28),

              // Status
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.purple.withOpacity(0.25))),
                child: Row(children: [
                  if (!_done && _error.isEmpty)
                    const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(
                        color: AppTheme.purple, strokeWidth: 2))
                  else if (_done)
                    const Icon(Icons.check_circle_rounded,
                        color: AppTheme.green, size: 20)
                  else
                    const Icon(Icons.error_rounded, color: AppTheme.red, size: 20),
                  const SizedBox(width: 12),
                  Expanded(child: Text(_error.isNotEmpty ? _error : _statusMsg,
                    style: TextStyle(
                      fontFamily: 'ShareTechMono', fontSize: 11,
                      color: _error.isNotEmpty ? AppTheme.red
                           : _done ? AppTheme.green : Colors.white))),
                ]),
              ),

              if (_error.isNotEmpty) ...[
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: GestureDetector(
                    onTap: () {
                      setState(() { _error = ''; _step = 0; });
                      _runSetup();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppTheme.purple, AppTheme.purple2]),
                        borderRadius: BorderRadius.circular(12)),
                      child: const Center(child: Text('COBA LAGI', style: TextStyle(
                        fontFamily: 'Orbitron', fontSize: 11,
                        color: Colors.white, letterSpacing: 2))),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPermRow(_PermItem p) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: p.granted
          ? AppTheme.green.withOpacity(0.3) : AppTheme.purple.withOpacity(0.2))),
      child: Row(children: [
        Icon(p.icon,
          color: p.granted ? AppTheme.green : AppTheme.purple.withOpacity(0.5),
          size: 18),
        const SizedBox(width: 12),
        Expanded(child: Text(p.label, style: const TextStyle(
          fontFamily: 'ShareTechMono', fontSize: 11, color: Colors.white))),
        Icon(p.granted ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
          color: p.granted ? AppTheme.green : AppTheme.textMuted, size: 18),
      ]),
    );
  }
}

class _PermItem {
  final String label;
  final IconData icon;
  bool granted;
  _PermItem(this.label, this.icon, this.granted);
}
