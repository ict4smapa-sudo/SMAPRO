// =============================================================================
// File        : exam_viewmodel.dart
// Fungsi Utama: ViewModel untuk ExamScreen.
//               Logic: inisialisasi WebViewController, ekstrak domain Moodle,
//               NavigationDelegate (blokir domain luar), PIN exit,
//               Android Lockdown (FLAG_SECURE + Kiosk Mode).
// Tanggal     : 27 Februari 2026
// PRD Section : Section 4.4, Section 6.1, Section 6.2
// MVVM RULE   : ViewModel HANYA boleh berisi logika bisnis.
//               DILARANG ada kode UI (Widget) di dalam ViewModel.
// BATASAN P9  : iOS Guided Access Detection → Prioritas 9.
// =============================================================================

import 'package:flutter/material.dart' show Color;
import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../services/local_storage_service.dart';
import '../services/logger_service.dart';
import '../services/security_helper.dart';
import '../services/webview_helper.dart';

// =============================================================================
// ENUM: State inisialisasi WebView
// =============================================================================

/// Enum yang digunakan ExamScreen untuk mengetahui kondisi WebView.
enum ExamViewState {
  /// WebViewController belum diinisialisasi.
  initial,

  /// Sedang loading URL pertama kali.
  loading,

  /// WebView siap dan halaman sudah mulai dimuat.
  ready,

  /// URL Moodle tidak ditemukan di SharedPreferences — konfigurasi belum ada.
  configMissing,

  /// Navigasi terakhir ke domain luar diblokir oleh NavigationDelegate.
  navigationBlocked,

  /// iOS saja: Guided Access belum diaktifkan.
  /// WebView DILARANG dimuat hingga Guided Access aktif.
  guidedAccessRequired,
}

// =============================================================================
// VIEWMODEL
// =============================================================================

/// ViewModel untuk ExamScreen — mengelola WebViewController dan keamanan navigasi.
class ExamViewModel extends ChangeNotifier {
  // ---------------------------------------------------------------------------
  // DEPENDENCIES
  // ---------------------------------------------------------------------------

  final LocalStorageService _storage = LocalStorageService();

  // ---------------------------------------------------------------------------
  // STATE
  // ---------------------------------------------------------------------------

  /// State saat ini dari WebView exam.
  ExamViewState _state = ExamViewState.initial;
  ExamViewState get state => _state;

  /// Controller WebView — diinisialisasi di [initWebView()], digunakan oleh WebViewWidget.
  WebViewController? _webViewController;
  WebViewController? get webViewController => _webViewController;

  /// Host yang diizinkan (diekstrak dari URL Moodle di SharedPreferences).
  /// Hanya request ke host ini yang diizinkan oleh NavigationDelegate.
  String? _allowedHost;
  String? get allowedHost => _allowedHost;

  /// Pesan blokir terakhir — ditampilkan di SnackBar oleh ExamScreen.
  String? _blockedMessage;
  String? get blockedMessage => _blockedMessage;

  // ---------------------------------------------------------------------------
  // PUBLIC METHODS — Init
  // ---------------------------------------------------------------------------

  /// Inisialisasi WebViewController dan muat URL Moodle.
  ///
  /// Alur sesuai PRD Section 4.4:
  ///   1. Ambil URL Moodle dari LocalStorageService
  ///   2. Ekstrak host dari URL tersebut (untuk NavigationDelegate)
  ///   3. Buat WebViewController dengan JavaScript unrestricted + DOM Storage
  ///   4. Daftarkan NavigationDelegate — blokir domain selain _allowedHost
  ///   5. Muat URL Moodle
  Future<void> initWebView() async {
    if (_state != ExamViewState.initial) return;

    // Log: awal sesi ujian (PRD Section 12.1)
    LoggerService().log('Memulai sesi ujian (Lockdown dipicu)...');

    final moodleUrl = _storage.getMoodleUrl();
    // getMoodleUrl() selalu non-empty (fallback ke defaultMoodleUrl)
    // Baris ini tidak bisa terjadi, tapi dipertahankan sebagai safety guard
    assert(moodleUrl.isNotEmpty, 'moodleUrl harusnya tidak pernah kosong');

    // -------------------------------------------------------------------------
    // iOS GUARD: Guided Access Detection (PRD Section 11.2)
    // HANYA dieksekusi di iOS (Platform.isIOS). Android tidak terpengaruh.
    // Jika Guided Access belum aktif: blokir load, tampilkan UI peringatan.
    // -------------------------------------------------------------------------
    final bool guidedAccessOk = await SecurityHelper()
        .isIosGuidedAccessEnabled();

    if (!guidedAccessOk) {
      _state = ExamViewState.guidedAccessRequired;
      notifyListeners();
      return; // DILARANG melanjutkan ke loadRequest
    }

    // -------------------------------------------------------------------------
    // Ekstrak host dari URL Moodle
    // Contoh: "http://192.168.1.100/moodle" → host: "192.168.1.100"
    // Digunakan NavigationDelegate untuk memvalidasi setiap navigasi.
    // -------------------------------------------------------------------------
    try {
      final uri = Uri.parse(moodleUrl);
      _allowedHost =
          uri.host; // contoh: "192.168.1.100" atau "moodle.sman4jbr.sch.id"
    } catch (_) {
      _allowedHost = null;
    }

    _state = ExamViewState.loading;
    notifyListeners();

    // -------------------------------------------------------------------------
    // Buat WebViewController dengan konfigurasi platform-specific
    // PRD Section 10.1: Platform-specific hardening
    // -------------------------------------------------------------------------
    final controller = WebViewController();

    // CATATAN Android: setSupportMultipleWindows tidak tersedia via public API
    // webview_flutter_android tanpa menambahkan direct dependency ke pubspec.
    // Popup jendela baru diblokir via NavigationDelegate Guard 1 (isMainFrame)
    // yang sudah diimplementasikan di bawah — efeknya sama.
    //
    // CATATAN iOS: allowsBackForwardNavigationGestures tidak diaktifkan oleh
    // default webview_flutter dan tidak perlu di-set manual.

    // JavaScript: unrestricted (wajib untuk Moodle)
    await controller.setJavaScriptMode(JavaScriptMode.unrestricted);

    // Background color agar tidak flash putih sebelum halaman load
    await controller.setBackgroundColor(const Color(0xFF121212));

    // -------------------------------------------------------------------------
    // NavigationDelegate — Keamanan Domain (PRD Section 4.4)
    // Blokir semua navigasi ke host di luar _allowedHost.
    // -------------------------------------------------------------------------
    await controller.setNavigationDelegate(
      NavigationDelegate(
        onNavigationRequest: (NavigationRequest request) {
          // -----------------------------------------------------------------
          // GUARD 1: Popup/new tab dari non-main frame
          // isMainFrame = false berarti request dari iframe atau popup.
          // Blokir jika URL tujuan bukan dari domain Moodle yang diizinkan.
          // Kuis Moodle yang punya iframe RESMI tetap lolos karena sub-domain
          // biasanya sama hostnya, hanya path yang berbeda.
          // -----------------------------------------------------------------
          if (!request.isMainFrame) {
            try {
              final frameUri = Uri.parse(request.url);
              if (_allowedHost != null &&
                  frameUri.host.isNotEmpty &&
                  frameUri.host != _allowedHost) {
                debugPrint('[NAV_BLOCK] Popup/iframe diblokir: ${request.url}');
                _blockedMessage = 'Akses dibatasi oleh Exambro!';
                notifyListeners();
                return NavigationDecision.prevent;
              }
            } catch (_) {
              return NavigationDecision.prevent;
            }
          }

          // -----------------------------------------------------------------
          // GUARD 2: Domain check (Prioritas 6 — DILARANG diubah)
          // Jika allowedHost belum diketahui, izinkan semua (fallback aman)
          // -----------------------------------------------------------------
          if (_allowedHost == null || _allowedHost!.isEmpty) {
            return NavigationDecision.navigate;
          }

          try {
            final requestUri = Uri.parse(request.url);

            // Izinkan: domain sama, atau about:blank (halaman kosong awal)
            if (requestUri.host == _allowedHost ||
                request.url == 'about:blank') {
              return NavigationDecision.navigate;
            }

            // Blokir: domain berbeda
            debugPrint(
              '[NAV_BLOCK] Navigasi diblokir ke: ${request.url} (host: ${requestUri.host})',
            );

            _blockedMessage = 'Akses diblokir oleh Exambro!';
            notifyListeners();

            return NavigationDecision.prevent;
          } catch (_) {
            // Jika URL tidak bisa di-parse, blokir sebagai langkah aman
            _blockedMessage = 'Akses diblokir oleh Exambro!';
            notifyListeners();
            return NavigationDecision.prevent;
          }
        },

        onPageStarted: (String url) {
          debugPrint('[WEBVIEW] Page started: $url');
        },

        onPageFinished: (String url) {
          // Log: halaman selesai dimuat — DILARANG log URL lengkap jika ada parameter token
          // Hanya log domain/path awal (truncate setelah '?') untuk keamanan.
          final safeUrl = url.contains('?')
              ? '${url.split('?').first}...'
              : url;
          LoggerService().log('Halaman selesai dimuat: $safeUrl');
          debugPrint('[WEBVIEW] Page finished: $url');

          // -----------------------------------------------------------------
          // HARDENING JS — PRD Section 10.2
          // WAJIB dieksekusi di onPageFinished agar berlaku di setiap navigasi
          // halaman soal Moodle (bukan hanya saat pertama kali load).
          // -----------------------------------------------------------------
          controller.runJavaScript(
            // iOS Safari: nonaktifkan callout menu (copy, define, share)
            "document.documentElement.style.webkitTouchCallout = 'none';"
            // iOS Safari: nonaktifkan text selection
            " document.documentElement.style.webkitUserSelect = 'none';"
            // Standard CSS: nonaktifkan text selection (Android, desktop)
            " document.documentElement.style.userSelect = 'none';"
            // Nonaktifkan long press / right-click context menu
            " document.addEventListener('contextmenu', function(e) { e.preventDefault(); });"
            // Nonaktifkan drag-and-drop (mencegah eksfiltrasi konten via drag)
            " document.addEventListener('dragstart', function(e) { e.preventDefault(); });",
          );
          // runJavaScript tidak di-await di sini karena onPageFinished bukan
          // async context yang bisa di-await — fire-and-forget sudah cukup.
        },

        onWebResourceError: (WebResourceError error) {
          debugPrint(
            '[WEBVIEW] Error: ${error.description} (code: ${error.errorCode})',
          );

          // -----------------------------------------------------------------
          // GRACEFUL ERROR HANDLING — PRD Network Error
          // Hanya tangkap error di main frame (bukan sub-resource seperti
          // gambar atau script yang gagal dimuat di iframe).
          // Error sub-frame diabaikan agar tidak spam SnackBar.
          // -----------------------------------------------------------------
          if (error.isForMainFrame != true) return;

          // Kode error jaringan standar Android WebView (WebViewClient):
          //   -2  → ERROR_HOST_LOOKUP (DNS gagal / Wi-Fi putus)
          //   -6  → ERROR_CONNECT (koneksi ditolak / server mati)
          //   -8  → ERROR_TIMEOUT (koneksi timeout)
          //   -15 → ERROR_FAILED_SSL_HANDSHAKE (SSL error)
          const networkErrorCodes = [-2, -6, -8, -15];
          final isNetworkError = networkErrorCodes.contains(error.errorCode);

          if (isNetworkError) {
            _blockedMessage = 'Koneksi terputus. Silakan tekan tombol Refresh.';
          } else {
            // Error non-jaringan (contoh: resource tertentu gagal) —
            // tampilkan pesan generik agar siswa tahu dan bisa retry.
            _blockedMessage =
                'Halaman gagal dimuat (${error.errorCode}). Coba Refresh.';
          }

          notifyListeners();
        },
      ),
    );

    // -------------------------------------------------------------------------
    // Load URL Moodle
    // Android Lockdown diaktifkan SEBELUM loadRequest agar layar terlindungi
    // FLAG_SECURE + Kiosk Mode sudah aktif sebelum soal ujian pertama muncul.
    // -------------------------------------------------------------------------
    await SecurityHelper().enableAndroidLockdown();

    await controller.loadRequest(Uri.parse(moodleUrl));

    _webViewController = controller;
    _state = ExamViewState.ready;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // PUBLIC METHODS — Utility
  // ---------------------------------------------------------------------------

  /// Reset pesan blokir setelah UI menampilkan SnackBar.
  void clearBlockedMessage() {
    _blockedMessage = null;
    // Tidak perlu notifyListeners() — hanya clear state internal
  }

  /// Reset ViewModel ke state awal dengan Session Isolation penuh.
  ///
  /// WAJIB di-await oleh ExamScreen sebelum memanggil Navigator.pushReplacementNamed.
  /// Navigasi ke /login HANYA boleh terjadi setelah fungsi ini selesai (async).
  ///
  /// Alur Session Isolation (PRD Section 6.2):
  ///   1. Bersihkan seluruh data web via WebViewHelper (cookies, cache, JS storage)
  ///   2. Nullify controller agar GC dapat mengambil alih memory
  ///   3. Reset seluruh state ViewModel ke initial
  Future<void> reset() async {
    // Nonaktifkan Android Lockdown LEBIH DULU sebelum membersihkan data.
    // WAJIB: HP siswa kembali normal SEBELUM notifyListeners() merender LoginScreen.
    await SecurityHelper().disableAndroidLockdown();

    // Jalankan session isolation HANYA jika controller masih ada
    if (_webViewController != null) {
      await WebViewHelper().clearAllWebData(_webViewController!);

      _webViewController = null;
      // MEMORY LEAK PREVENTION: Controller is nullified after session data cleared.
      // Siswa berikutnya akan mendapatkan WebViewController baru dari initWebView().
    }

    _state = ExamViewState.initial;
    _allowedHost = null;
    _blockedMessage = null;
    // Log: sesi ujian ditutup (PRD Section 12.1)
    LoggerService().log('Sesi ujian dibersihkan dan ditutup.');
    notifyListeners();
  }
}
