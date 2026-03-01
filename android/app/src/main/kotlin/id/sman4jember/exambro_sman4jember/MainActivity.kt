package id.sman4jember.exambro_sman4jember

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.provider.Settings
import android.util.Log
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * MainActivity — Entry point aplikasi Android.
 *
 * FLAG_SECURE — Mencegah screenshot, screen recording, screen casting,
 * dan preview di Recent Apps. Diaktifkan di onCreate() sebelum super
 * agar berlaku sejak frame pertama.
 *
 * MethodChannel 'id.sman4jember.exambro/kiosk' — Jembatan native untuk
 * App Pinning (Screen Pinning) via startLockTask() / stopLockTask().
 * Dipanggil oleh SecurityHelper.dart saat siswa masuk/keluar ExamScreen.
 */
class MainActivity : FlutterActivity() {

    // Nama channel WAJIB identik dengan yang dideklarasikan di SecurityHelper.dart
    private val KIOSK_CHANNEL = "id.sman4jember.exambro/kiosk"

    // Class-level reference ke MethodChannel agar onWindowFocusChanged bisa memanggilnya.
    private var kioskChannel: MethodChannel? = null

    // Flag: true saat Screen Pinning aktif — digunakan untuk filter di onWindowFocusChanged.
    private var isKioskModeActive = false

    override fun onCreate(savedInstanceState: Bundle?) {
        // FLAG_SECURE SEBELUM super.onCreate() — berlaku sejak frame pertama.
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Blokir Overlay Window (Floating Apps) secara native — API 31+ (Android 12+).
        // Ini mencegah semua TYPE_APPLICATION_OVERLAY window tampil di atas Exambro.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            window.setHideOverlayWindows(true)
        }

        // Inisialisasi MethodChannel sebagai class-level field agar bisa diakses
        // dari onWindowFocusChanged (yang hidup di luar configureFlutterEngine).
        kioskChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            KIOSK_CHANNEL
        )

        kioskChannel!!.setMethodCallHandler { call, result ->
            when (call.method) {
                "enableKioskMode" -> {
                    try {
                        startLockTask() // Screen Pinning — blokir tombol Home & Recents
                        isKioskModeActive = true  // tandai kiosk aktif
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("KIOSK_ENABLE_FAILED", e.message, null)
                    }
                }
                "disableKioskMode" -> {
                    try {
                        stopLockTask() // Lepas Screen Pinning
                        isKioskModeActive = false // tandai kiosk tidak aktif
                        result.success(null)
                    } catch (e: Exception) {
                        // stopLockTask() bisa throw jika App Pinning belum aktif.
                        // Tidak dianggap error fatal — cukup return success.
                        isKioskModeActive = false
                        result.success(null)
                    }
                }
                "requestBatteryExemption" -> {
                    try {
                        // isIgnoringBatteryOptimizations baru tersedia di API 23 (Android 6.0).
                        // Guard ini mencegah NoSuchMethodError / LinkageError di Android 5.0-5.1.
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            val pm = getSystemService(POWER_SERVICE) as PowerManager
                            if (!pm.isIgnoringBatteryOptimizations(packageName)) {
                                val intent = Intent().apply {
                                    action = Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS
                                    data = Uri.parse("package:$packageName")
                                }
                                startActivity(intent)
                            }
                        }
                        result.success(null)
                    } catch (e: Exception) {
                        Log.e("EXAMBRO_DEBUG", "Gagal meminta pengecualian baterai: ${e.message}")
                        result.success(null) // Tidak boleh crash — lanjut tanpa exemption
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    /**
     * Dipanggil OS setiap kali jendela Exambro mendapat atau kehilangan fokus.
     * Sumber kehilangan fokus yang terdeteksi:
     *   - Floating Apps / Bubble       → hasFocus = false, tidak trigger paused
     *   - Dialog sistem (izin, telepon) → hasFocus = false
     *   - Notifikasi pop-up overlay     → hasFocus = false
     *
     * CATATAN: Status bar pull biasa sudah tertangkap oleh AppLifecycleState.inactive
     * di Flutter — fungsi ini hanya untuk overlay yang TIDAK mengubah lifecycle.
     */
    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        Log.d("EXAMBRO_DEBUG", "Native onWindowFocusChanged dipanggil! hasFocus: $hasFocus, isKiosk: $isKioskModeActive")
        if (!hasFocus && isKioskModeActive) {
            Log.d("EXAMBRO_DEBUG", "Mencoba mengirim onWindowFocusLost ke Flutter...")
            kioskChannel?.invokeMethod("onWindowFocusLost", null, object : MethodChannel.Result {
                override fun success(result: Any?) {
                    Log.d("EXAMBRO_DEBUG", "MethodChannel Sukses terkirim!")
                }
                override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                    Log.d("EXAMBRO_DEBUG", "MethodChannel Error: $errorMessage")
                }
                override fun notImplemented() {
                    Log.d("EXAMBRO_DEBUG", "MethodChannel Not Implemented!")
                }
            })
        }
    }

    override fun onPause() {
        super.onPause()
        Log.d("EXAMBRO_DEBUG", "Native Activity onPause dipanggil oleh OS Android!")
    }
}
