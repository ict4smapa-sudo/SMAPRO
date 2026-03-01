package id.sman4jember.exambro_sman4jember

import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity

/**
 * MainActivity — Entry point aplikasi Android.
 *
 * FLAG_SECURE diimplementasikan di sini secara native (tidak menggunakan
 * flutter_windowmanager v0.2.0 yang tidak kompatibel dengan v2 Embedding).
 *
 * FLAG_SECURE mencegah:
 *   - Screenshot (tombol hardware maupun gesture)
 *   - Screen recording (MediaProjection)
 *   - Screen casting (Miracast / Chromecast)
 *   - Preview di Recent Apps (layar disamarkan)
 *
 * CATATAN: FLAG_SECURE diaktifkan di onCreate() agar berlaku sejak frame pertama.
 * ExamViewModel.enableAndroidLockdown() akan memanggil SecurityHelper yang
 * mengandalkan flag ini sudah terpasang sejak aplikasi dimulai.
 */
class MainActivity : FlutterActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        // Pasang FLAG_SECURE SEBELUM super.onCreate() agar berlaku sejak frame pertama.
        // Ini lebih aman daripada sesudah — mencegah preview di Recent Apps sejak boot.
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)

        super.onCreate(savedInstanceState)
    }
}
