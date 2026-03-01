package id.sman4jember.exambro_sman4jember

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.os.PowerManager
import android.provider.Settings
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

    override fun onCreate(savedInstanceState: Bundle?) {
        // FLAG_SECURE SEBELUM super.onCreate() — berlaku sejak frame pertama.
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            KIOSK_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "enableKioskMode" -> {
                    try {
                        startLockTask() // Screen Pinning — blokir tombol Home & Recents
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("KIOSK_ENABLE_FAILED", e.message, null)
                    }
                }
                "disableKioskMode" -> {
                    try {
                        stopLockTask() // Lepas Screen Pinning — siswa kembali ke OS normal
                        result.success(null)
                    } catch (e: Exception) {
                        // stopLockTask() bisa throw jika App Pinning belum aktif.
                        // Tidak dianggap error fatal — cukup return success.
                        result.success(null)
                    }
                }
                "requestBatteryExemption" -> {
                    try {
                        val pm = getSystemService(POWER_SERVICE) as PowerManager
                        if (!pm.isIgnoringBatteryOptimizations(packageName)) {
                            val intent = Intent().apply {
                                action = Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS
                                data = Uri.parse("package:$packageName")
                            }
                            startActivity(intent)
                        }
                        result.success(null)
                    } catch (e: Exception) {
                        result.success(null) // Tidak boleh crash jika settings tidak tersedia
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
