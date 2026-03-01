// =============================================================================
// File        : constants.dart
// Fungsi Utama: Konstanta global aplikasi — SharedPreferences keys, timeout,
//               retry count, admin gesture config, dan log buffer size.
//               Digunakan di seluruh lapisan View, ViewModel, dan Service.
// Tanggal     : 27 Februari 2026
// PRD Section : Section 2.3, Section 4.2, Section 6.3, Section 6.5
// =============================================================================

/// Konstanta global Exambro SMAN 4 Jember.
/// Kelas ini tidak boleh di-instantiasi — semua member bersifat static const.
class AppConstants {
  // Konstruktor private
  AppConstants._();

  // ---------------------------------------------------------------------------
  // SHARED PREFERENCES KEYS
  // ---------------------------------------------------------------------------

  /// Key URL server Moodle (contoh: http://192.168.1.100/moodle).
  static const String keyServerIpUrl = 'server_ip_url';

  /// Key URL endpoint validasi token (contoh: http://192.168.1.100/api/validate).
  static const String keyApiValidateUrl = 'api_validate_url';

  /// Key hash SHA-256 dari PIN admin (DILARANG simpan plain text).
  static const String keyAdminPinHash = 'admin_pin_hash';

  /// Key hash SHA-256 dari PIN keluar ujian (DILARANG simpan plain text).
  /// Terpisah dari [keyAdminPinHash] — PIN Masuk dan PIN Keluar bisa berbeda.
  static const String keyExitPinHash = 'exit_pin_hash';

  // ---------------------------------------------------------------------------
  // HTTP / NETWORK
  // ---------------------------------------------------------------------------

  /// Timeout HTTP dalam detik untuk semua request ke backend. PRD: 10 detik.
  static const int httpTimeoutSeconds = 10;

  /// Jumlah maksimal retry otomatis setelah timeout. PRD: 1 kali.
  static const int maxRetryCount = 1;

  // ---------------------------------------------------------------------------
  // ADMIN HIDDEN GESTURE
  // ---------------------------------------------------------------------------

  /// Jumlah tap pada logo yang diperlukan untuk memicu dialog PIN admin.
  /// PRD Section 4.2: 7 kali tap dalam 3 detik.
  static const int adminTapCount = 7;

  /// Window waktu (detik) untuk menghitung adminTapCount sebelum counter direset.
  static const int adminTapWindowSeconds = 3;

  // ---------------------------------------------------------------------------
  // SPLASH SCREEN
  // ---------------------------------------------------------------------------

  /// Durasi delay (detik) di Splash Screen sebelum navigasi ke /login.
  /// PRD Section 4.1: "tunggu 2 detik (Future.delayed)".
  static const int splashDelaySeconds = 2;

  // ---------------------------------------------------------------------------
  // LOGGING (Prioritas 12)
  // ---------------------------------------------------------------------------

  /// Ukuran maksimal ring buffer log lokal (debug build).
  /// PRD Section 6.5: ring buffer, max 1000 entri.
  static const int logRingBufferSize = 1000;

  // ---------------------------------------------------------------------------
  // DEFAULT API URL (Centralized Configuration — Prioritas 13)
  // ---------------------------------------------------------------------------

  /// URL default endpoint validasi token.
  /// Digunakan sebagai fallback jika admin belum mengisi API URL via AdminScreen.
  /// Ganti IP ini sebelum release build ke jaringan sekolah.
  static const String defaultApiUrl = 'http://192.168.0.7:3000/api/validate';

  /// URL default server Moodle.
  /// Digunakan sebagai fallback jika belum ada URL dari response server.
  /// Siswa tetap bisa masuk ujian tanpa konfigurasi manual.
  static const String defaultMoodleUrl =
      'http://182.253.41.180/login/index.php';
}
