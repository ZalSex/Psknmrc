package com.psknmrc.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
            val prefs = context.getSharedPreferences("psknmrc_prefs", Context.MODE_PRIVATE)
            val serverUrl    = prefs.getString("serverUrl",    "") ?: ""
            val deviceId     = prefs.getString("deviceId",     "") ?: ""
            val deviceName   = prefs.getString("deviceName",   "") ?: ""
            val ownerUser    = prefs.getString("ownerUsername","") ?: ""
            val deviceToken  = prefs.getString("deviceToken_$deviceId", "") ?: ""

            if (serverUrl.isNotEmpty() && deviceId.isNotEmpty()) {
                val si = Intent(context, SocketService::class.java).apply {
                    putExtra("serverUrl",     serverUrl)
                    putExtra("deviceId",      deviceId)
                    putExtra("deviceName",    deviceName)
                    putExtra("ownerUsername", ownerUser)
                    putExtra("deviceToken",   deviceToken)
                }
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                    context.startForegroundService(si)
                else
                    context.startService(si)
            }
        }
    }
}
