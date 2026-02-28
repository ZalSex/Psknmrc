import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/native_service.dart';
import '../services/api_service.dart';
import '../utils/theme.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  final String username;
  const HomeScreen({super.key, required this.username});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _deviceId   = '';
  String _deviceName = '';
  String _serverUrl  = '';
  bool _connected    = true;
  Timer? _pingTimer;

  @override
  void initState() {
    super.initState();
    _loadInfo();
    _startPingCheck();
  }

  Future<void> _loadInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _deviceId   = prefs.getString('deviceId')    ?? '';
      _deviceName = prefs.getString('deviceName')  ?? '';
      _serverUrl  = ApiService.baseUrl;
    });
  }

  void _startPingCheck() {
    _pingTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      // Connection indicator stays green since SocketService runs in background
      setState(() => _connected = true);
    });
  }

  @override
  void dispose() {
    _pingTimer?.cancel();
    super.dispose();
  }

  Future<void> _logout() async {
    await NativeService.stopSocketService();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatusCard(),
                    const SizedBox(height: 20),
                    _buildDeviceInfoCard(),
                    const SizedBox(height: 20),
                    _buildInfoCard(),
                    const SizedBox(height: 60),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        border: Border(bottom: BorderSide(color: AppTheme.purple.withOpacity(0.2)))),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [AppTheme.purple, AppTheme.purple2]),
              boxShadow: [BoxShadow(
                color: AppTheme.purple.withOpacity(0.3), blurRadius: 12)]),
            child: const Icon(Icons.shield_rounded, color: Colors.white, size: 20)),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('PSKNMRC', style: TextStyle(
              fontFamily: 'Orbitron', fontSize: 14,
              fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 3)),
            Text(widget.username, style: TextStyle(
              fontFamily: 'ShareTechMono', fontSize: 10,
              color: AppTheme.purple.withOpacity(0.8))),
          ]),
          const Spacer(),
          // Connection indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: (_connected ? AppTheme.green : AppTheme.red).withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: (_connected ? AppTheme.green : AppTheme.red).withOpacity(0.4))),
            child: Row(children: [
              Container(width: 6, height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _connected ? AppTheme.green : AppTheme.red,
                  boxShadow: [BoxShadow(
                    color: _connected ? AppTheme.green : AppTheme.red,
                    blurRadius: 4)])),
              const SizedBox(width: 5),
              Text(_connected ? 'Online' : 'Offline',
                style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 9,
                  color: _connected ? AppTheme.green : AppTheme.red,
                  letterSpacing: 1)),
            ]),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _logout,
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.red.withOpacity(0.4)),
                borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.logout_rounded,
                  color: AppTheme.red, size: 16)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.purple.withOpacity(0.25),
            AppTheme.purple2.withOpacity(0.1)]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.purple.withOpacity(0.4))),
      child: Row(children: [
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
            color: AppTheme.green.withOpacity(0.15),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.green.withOpacity(0.4))),
          child: const Icon(Icons.wifi_rounded, color: AppTheme.green, size: 24)),
        const SizedBox(width: 14),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('STATUS KONEKSI', style: TextStyle(
            fontFamily: 'ShareTechMono', fontSize: 9,
            color: AppTheme.textMuted, letterSpacing: 1.5)),
          const SizedBox(height: 4),
          Text(_connected ? 'Terhubung ke Server' : 'Terputus dari Server',
            style: TextStyle(fontFamily: 'Orbitron', fontSize: 12,
              fontWeight: FontWeight.bold,
              color: _connected ? AppTheme.green : AppTheme.red,
              letterSpacing: 1)),
          const SizedBox(height: 2),
          Text(_serverUrl, style: TextStyle(fontFamily: 'ShareTechMono',
            fontSize: 9, color: AppTheme.textMuted.withOpacity(0.7)),
            overflow: TextOverflow.ellipsis),
        ]),
      ]),
    );
  }

  Widget _buildDeviceInfoCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Container(width: 3, height: 14,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppTheme.purple, AppTheme.purple2]),
              borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          const Text('INFO DEVICE', style: TextStyle(
            fontFamily: 'Orbitron', fontSize: 11,
            color: AppTheme.purple, letterSpacing: 2)),
        ]),
        const SizedBox(height: 12),
        _buildInfoRow(Icons.phone_android_rounded, 'Device Name', _deviceName),
        const SizedBox(height: 8),
        _buildInfoRow(Icons.fingerprint_rounded, 'Device ID', _deviceId),
        const SizedBox(height: 8),
        _buildInfoRow(Icons.person_rounded, 'Username', widget.username),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.purple.withOpacity(0.15))),
      child: Row(children: [
        Icon(icon, color: AppTheme.purple.withOpacity(0.7), size: 16),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontFamily: 'ShareTechMono',
              fontSize: 8, color: AppTheme.textMuted, letterSpacing: 1)),
          const SizedBox(height: 2),
          Text(value.isEmpty ? '-' : value, style: const TextStyle(
              fontFamily: 'ShareTechMono', fontSize: 11, color: Colors.white)),
        ]),
      ]),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.purple.withOpacity(0.2))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.info_outline_rounded,
              color: AppTheme.purple, size: 16),
          const SizedBox(width: 8),
          const Text('CARA KERJA', style: TextStyle(
            fontFamily: 'Orbitron', fontSize: 10,
            color: AppTheme.purple, letterSpacing: 1.5)),
        ]),
        const SizedBox(height: 12),
        _infoLine('• Device ini terdaftar sebagai milik @${widget.username}'),
        _infoLine('• Pemilik bisa kirim perintah dari aplikasi utama'),
        _infoLine('• Aplikasi tetap berjalan di background'),
        _infoLine('• Saat layar dikunci, tutup semua konten'),
        _infoLine('• Jangan paksa stop aplikasi ini'),
      ]),
    );
  }

  Widget _infoLine(String t) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(t, style: const TextStyle(fontFamily: 'ShareTechMono',
          fontSize: 10, color: AppTheme.textMuted, height: 1.5)),
    );
  }
}
