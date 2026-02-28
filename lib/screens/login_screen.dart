import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../utils/theme.dart';
import 'setup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _usernameCtrl = TextEditingController();
  bool _loading = false;
  String _error = '';

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _usernameCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final username = _usernameCtrl.text.trim();
    if (username.isEmpty) { setState(() => _error = 'Username wajib diisi'); return; }

    setState(() { _loading = true; _error = ''; });
    try {
      await ApiService.init();
      final res = await ApiService.post('/api/psknmrc/login', {'username': username});
      if (res['success'] == true) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('psknmrc_username', username);
        await prefs.setString('psknmrc_role', res['role'] ?? 'premium');
        // Simpan ownerUsername (createdBy) supaya SocketService bisa pakai
        final ownerUsername = res['ownerUsername'] as String? ?? username;
        await prefs.setString('ownerUsername', ownerUsername);
        if (!mounted) return;
        Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (_) => SetupScreen(username: username)));
      } else {
        setState(() => _error = res['message'] as String? ?? 'Login gagal');
      }
    } catch (_) {
      setState(() => _error = 'Gagal terhubung ke server');
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 40),

                // Logo
                Container(
                  width: 96, height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [AppTheme.purple, AppTheme.purple2],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight),
                    boxShadow: [BoxShadow(
                      color: AppTheme.purple.withOpacity(0.45),
                      blurRadius: 28, spreadRadius: 2)]),
                  child: const Icon(Icons.shield_rounded, color: Colors.white, size: 46)),
                const SizedBox(height: 22),

                const Text('PSKNMRC', style: TextStyle(
                  fontFamily: 'Orbitron', fontSize: 28,
                  fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 5)),
                const SizedBox(height: 6),
                Text('Secure Device Control', style: TextStyle(
                  fontFamily: 'ShareTechMono', fontSize: 12,
                  color: AppTheme.purple.withOpacity(0.8), letterSpacing: 2)),
                const SizedBox(height: 10),

                // Server badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.green.withOpacity(0.3))),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(width: 6, height: 6,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle, color: AppTheme.green)),
                    const SizedBox(width: 6),
                    const Text('Server Ready', style: TextStyle(
                      fontFamily: 'ShareTechMono', fontSize: 9,
                      color: AppTheme.green, letterSpacing: 1)),
                  ])),

                const SizedBox(height: 52),

                // Username label
                Row(children: [
                  Container(width: 3, height: 12,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [AppTheme.purple, AppTheme.purple2]),
                      borderRadius: BorderRadius.circular(2))),
                  const SizedBox(width: 8),
                  const Text('USERNAME', style: TextStyle(
                    fontFamily: 'ShareTechMono', fontSize: 10,
                    color: AppTheme.purple, letterSpacing: 2)),
                ]),
                const SizedBox(height: 8),

                // Username input
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.cardBg2,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.purple.withOpacity(0.35))),
                  child: TextField(
                    controller: _usernameCtrl,
                    autofocus: true,
                    style: const TextStyle(
                      fontFamily: 'ShareTechMono', color: Colors.white, fontSize: 15),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                      prefixIcon: Icon(Icons.person_rounded,
                        color: AppTheme.purple.withOpacity(0.6), size: 20),
                      hintText: 'Masukkan username kamu',
                      hintStyle: TextStyle(color: AppTheme.textMuted.withOpacity(0.4),
                        fontSize: 12, fontFamily: 'ShareTechMono')),
                    onSubmitted: (_) => _login()),
                ),
                const SizedBox(height: 6),
                Text('Username dibuat oleh pemilik aplikasi',
                  style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 9,
                    color: AppTheme.textMuted.withOpacity(0.5))),

                const SizedBox(height: 28),

                if (_error.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppTheme.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.red.withOpacity(0.4))),
                    child: Text(_error, style: const TextStyle(
                      fontFamily: 'ShareTechMono', fontSize: 11, color: AppTheme.red))),

                // Login button
                SizedBox(
                  width: double.infinity, height: 54,
                  child: GestureDetector(
                    onTap: _loading ? null : _login,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: _loading
                          ? LinearGradient(colors: [
                              AppTheme.purple.withOpacity(0.4),
                              AppTheme.purple2.withOpacity(0.4)])
                          : const LinearGradient(colors: [AppTheme.purple, AppTheme.purple2]),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [BoxShadow(
                          color: AppTheme.purple.withOpacity(0.35), blurRadius: 20)]),
                      child: Center(child: _loading
                        ? const SizedBox(width: 22, height: 22,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                        : const Text('MASUK', style: TextStyle(
                            fontFamily: 'Orbitron', fontSize: 14,
                            fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 4))),
                    ),
                  ),
                ),

                const SizedBox(height: 40),
                Text('PSKNMRC v1.0.0 • Authorized Only',
                  style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 9,
                    color: AppTheme.textMuted.withOpacity(0.4))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
