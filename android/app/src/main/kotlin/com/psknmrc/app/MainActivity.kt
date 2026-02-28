package com.psknmrc.app

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.psknmrc.app/native"
    private val OVERLAY_PERMISSION_REQ = 1001

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {

                    "checkOverlayPermission" -> {
                        val granted = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M)
                            Settings.canDrawOverlays(this) else true
                        result.success(granted)
                    }
                    "requestOverlayPermission" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            startActivityForResult(
                                Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                                    Uri.parse("package:$packageName")),
                                OVERLAY_PERMISSION_REQ
                            )
                        }
                        result.success(null)
                    }

                    "startSocketService" -> {
                        val serverUrl = call.argument<String>("serverUrl") ?: ""
                        val deviceId  = call.argument<String>("deviceId")  ?: ""
                        val deviceName= call.argument<String>("deviceName")?: ""
                        val owner     = call.argument<String>("ownerUsername") ?: ""
                        val token     = call.argument<String>("deviceToken") ?: ""
                        val intent = Intent(this, SocketService::class.java).apply {
                            putExtra("serverUrl",     serverUrl)
                            putExtra("deviceId",      deviceId)
                            putExtra("deviceName",    deviceName)
                            putExtra("ownerUsername", owner)
                            putExtra("deviceToken",   token)
                        }
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                            startForegroundService(intent)
                        else
                            startService(intent)
                        result.success(true)
                    }
                    "stopSocketService" -> {
                        stopService(Intent(this, SocketService::class.java))
                        result.success(true)
                    }

                    "showLockScreen" -> {
                        val text = call.argument<String>("text") ?: ""
                        val pin  = call.argument<String>("pin")  ?: ""
                        val canDraw = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M)
                            Settings.canDrawOverlays(this) else true
                        if (canDraw) {
                            val intent = Intent(this, LockService::class.java).apply {
                                putExtra("lockText", text)
                                putExtra("lockPin",  pin)
                                putExtra("action",   "lock")
                            }
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                                startForegroundService(intent)
                            else
                                startService(intent)
                            result.success(true)
                        } else {
                            result.success(false)
                        }
                    }
                    "hideLockScreen" -> {
                        val intent = Intent(this, LockService::class.java).apply {
                            putExtra("action", "unlock")
                        }
                        startService(intent)
                        result.success(true)
                    }

                    else -> result.notImplemented()
                }
            }
    }
}
