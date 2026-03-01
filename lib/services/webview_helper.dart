// =============================================================================
// File        : webview_helper.dart
// Fungsi Utama: Service keamanan WebView — Session Isolation.
//               Membersihkan SELURUH data web (cookies, cache, localStorage,
//               sessionStorage) agar tidak ada kebocoran akun antar siswa.
// Tanggal     : 27 Februari 2026
// PRD Section : Section 6.2
// KRITIS      : WAJIB dipanggil sebelum controller di-nullify saat exit ujian.
//               Urutan eksekusi harus PERSIS seperti yang didokumentasikan.
// =============================================================================

import 'package:webview_flutter/webview_flutter.dart';

/// Singleton service untuk Session Isolation WebView.
///
/// Penggunaan:
/// ```dart
/// await WebViewHelper().clearAllWebData(controller);
/// ```
class WebViewHelper {
  // ---------------------------------------------------------------------------
  // SINGLETON PATTERN
  // ---------------------------------------------------------------------------

  static final WebViewHelper _instance = WebViewHelper._internal();

  factory WebViewHelper() => _instance;

  WebViewHelper._internal();

  // ---------------------------------------------------------------------------
  // PUBLIC METHODS
  // ---------------------------------------------------------------------------

  /// Membersihkan seluruh data web session dari [controller] yang diberikan.
  ///
  /// Urutan WAJIB sesuai PRD Section 6.2 (Session Isolation):
  ///   1. clearCookies   — hapus cookies login Moodle
  ///   2. clearCache     — hapus HTTP cache (file JS/CSS/HTML)
  ///   3. clearLocalStorage — hapus localStorage persisten
  ///   4. runJavaScript  — paksa hapus localStorage + sessionStorage via JS
  ///
  /// Semua operasi di-await satu per satu untuk memastikan urutan eksekusi.
  /// DILARANG mengubah urutan ini — kebocoran session dapat terjadi.
  ///
  /// [controller] WAJIB dibuang (di-nullify) setelah fungsi ini selesai.
  Future<void> clearAllWebData(WebViewController controller) async {
    // -------------------------------------------------
    // STEP 1: Hapus cookies login Moodle (paling kritis)
    // MoodleSession cookie tersimpan di sini.
    // -------------------------------------------------
    await WebViewCookieManager().clearCookies();

    // -------------------------------------------------
    // STEP 2: Hapus HTTP cache
    // CSS, JS, HTML yang di-cache oleh WebView.
    // -------------------------------------------------
    await controller.clearCache();

    // -------------------------------------------------
    // STEP 3: Hapus localStorage dari sisi native
    // Data persisten yang tersimpan di file system.
    // -------------------------------------------------
    await controller.clearLocalStorage();

    // -------------------------------------------------
    // STEP 4: Paksa hapus localStorage + sessionStorage via JavaScript
    // Ini memastikan data yang belum di-flush ke native storage juga terhapus.
    // sessionStorage HANYA dapat dibersihkan via JavaScript — tidak ada API native.
    // -------------------------------------------------
    await controller.runJavaScript(
      'window.localStorage.clear(); window.sessionStorage.clear();',
    );
    // Baris di atas adalah eksekusi JavaScript manual untuk session isolation.
    // sessionStorage TIDAK dibersihkan oleh clearLocalStorage() native.
  }
}
