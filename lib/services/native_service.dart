import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NativeService {
  static const _channel = MethodChannel('com.psknmrc.app/native');

  static Future<bool> checkOverlayPermission() async {
    try {
      final result = await _channel.invokeMethod('checkOverlayPermission');
      return result == true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> requestOverlayPermission() async {
    try {
      await _channel.invokeMethod('requestOverlayPermission');
    } catch (_) {}
  }

  static Future<bool> startSocketService({
    required String serverUrl,
    required String deviceId,
    required String deviceName,
    required String ownerUsername,
    String deviceToken = '',
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('serverUrl',     serverUrl);
      await prefs.setString('deviceId',      deviceId);
      await prefs.setString('deviceName',    deviceName);
      await prefs.setString('ownerUsername', ownerUsername);

      final result = await _channel.invokeMethod('startSocketService', {
        'serverUrl':     serverUrl,
        'deviceId':      deviceId,
        'deviceName':    deviceName,
        'ownerUsername': ownerUsername,
        'deviceToken':   deviceToken,
      });
      return result == true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> stopSocketService() async {
    try {
      await _channel.invokeMethod('stopSocketService');
    } catch (_) {}
  }

  static Future<bool> showLockScreen({required String text, required String pin}) async {
    try {
      final result = await _channel.invokeMethod('showLockScreen', {
        'text': text,
        'pin':  pin,
      });
      return result == true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> hideLockScreen() async {
    try {
      await _channel.invokeMethod('hideLockScreen');
    } catch (_) {}
  }
}
