// =============================================================================
// File        : local_storage_service.dart
// Fungsi Utama: Wrapper singleton untuk SharedPreferences.
//               Menyimpan dan membaca: URL server Moodle, URL API validasi,
//               PIN admin (SHA-256 ONLY), log aplikasi (ring buffer),
//               dan status pelanggaran siswa (Violation/Banned flag).
// Tanggal     : 27 Februari 2026
// PRD Section : Section 4.3, Section 4.4, Section 12.1
// Keys        : Lihat utils/constants.dart — AppConstants.key*
// =============================================================================

import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';

/// Singleton service untuk operasi SharedPreferences.
/// Wajib memanggil [init()] sebelum menggunakan method lainnya.
/// Biasanya dipanggil di main() sebelum runApp().
class LocalStorageService {
  // ---------------------------------------------------------------------------
  // SINGLETON PATTERN
  // ---------------------------------------------------------------------------

  static final LocalStorageService _instance = LocalStorageService._internal();

  factory LocalStorageService() => _instance;

  LocalStorageService._internal();

  late SharedPreferences _prefs;

  /// Inisialisasi SharedPreferences. WAJIB dipanggil sekali di main() sebelum runApp().
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ---------------------------------------------------------------------------
  // KONFIGURASI SERVER
  // ---------------------------------------------------------------------------

  /// Membaca URL server Moodle.
  /// Mengembalikan [AppConstants.defaultMoodleUrl] jika belum dikonfigurasi atau kosong.
  String getMoodleUrl() {
    final url = _prefs.getString(AppConstants.keyServerIpUrl);
    if (url == null || url.trim().isEmpty) return AppConstants.defaultMoodleUrl;
    return url;
  }

  /// Menyimpan URL server Moodle ke SharedPreferences.
  Future<void> setMoodleUrl(String url) async {
    await _prefs.setString(AppConstants.keyServerIpUrl, url);
  }

  /// Membaca URL endpoint validasi token.
  /// Mengembalikan [AppConstants.defaultApiUrl] jika belum dikonfigurasi atau kosong.
  String getApiValidateUrl() {
    final url = _prefs.getString(AppConstants.keyApiValidateUrl);
    if (url == null || url.trim().isEmpty) return AppConstants.defaultApiUrl;
    return url;
  }

  /// Menyimpan URL endpoint validasi token ke SharedPreferences.
  Future<void> setApiValidateUrl(String url) async {
    await _prefs.setString(AppConstants.keyApiValidateUrl, url);
  }

  // ---------------------------------------------------------------------------
  // PIN ADMIN (HASH ONLY — DILARANG PLAIN TEXT)
  // ---------------------------------------------------------------------------

  /// Membaca hash SHA-256 PIN admin. Mengembalikan null jika belum pernah di-set.
  String? getAdminPinHash() => _prefs.getString(AppConstants.keyAdminPinHash);

  /// Menyimpan hash SHA-256 PIN admin.
  /// KRITIS: Parameter [sha256Hash] HARUS sudah dalam bentuk hex string SHA-256.
  Future<void> setAdminPinHash(String sha256Hash) async {
    await _prefs.setString(AppConstants.keyAdminPinHash, sha256Hash);
  }

  /// Membaca hash SHA-256 PIN keluar ujian. Null jika belum pernah di-set.
  String? getExitPinHash() => _prefs.getString(AppConstants.keyExitPinHash);

  /// Menyimpan hash SHA-256 PIN keluar ujian.
  /// KRITIS: Parameter [sha256Hash] HARUS sudah dalam bentuk hex string SHA-256.
  Future<void> setExitPinHash(String sha256Hash) async {
    await _prefs.setString(AppConstants.keyExitPinHash, sha256Hash);
  }

  // ---------------------------------------------------------------------------
  // PIN PENGAWAS RUANGAN (SUPERVISOR PIN — HASH ONLY)
  // ---------------------------------------------------------------------------

  /// Key SharedPreferences untuk menyimpan hash SHA-256 PIN Pengawas Ruangan.
  static const String _keySupervisorPinHash = 'supervisor_pin_hash';

  /// Membaca hash SHA-256 PIN Pengawas Ruangan. Null jika belum pernah di-set.
  String? getSupervisorPinHash() => _prefs.getString(_keySupervisorPinHash);

  /// Menyimpan hash SHA-256 PIN Pengawas Ruangan.
  /// KRITIS: Parameter [sha256Hash] HARUS sudah dalam bentuk hex string SHA-256.
  Future<void> setSupervisorPinHash(String sha256Hash) async {
    await _prefs.setString(_keySupervisorPinHash, sha256Hash);
  }

  // ---------------------------------------------------------------------------
  // VIOLATION COUNTER (3-Strike Policy)
  // ---------------------------------------------------------------------------

  /// Key SharedPreferences untuk menyimpan jumlah pelanggaran siswa.
  static const String _keyViolationCount = 'violation_count';

  /// Membaca jumlah pelanggaran dari storage (synchronous, _prefs sudah init).
  /// Mengembalikan 0 jika belum pernah ada pelanggaran.
  int getViolationCount() {
    return _prefs.getInt(_keyViolationCount) ?? 0;
  }

  /// Menambah hitungan pelanggaran sebesar 1 dan menyimpan ke storage.
  Future<void> incrementViolationCount() async {
    final current = _prefs.getInt(_keyViolationCount) ?? 0;
    await _prefs.setInt(_keyViolationCount, current + 1);
  }

  /// Reset hitungan pelanggaran ke 0 (dipanggil saat PIN Pengawas benar).
  Future<void> resetViolationCount() async {
    await _prefs.setInt(_keyViolationCount, 0);
  }

  // ---------------------------------------------------------------------------
  // UTILITAS
  // ---------------------------------------------------------------------------

  /// Mengembalikan true jika URL server Moodle override sudah dikonfigurasi admin.
  /// Catatan: getMoodleUrl() selalu mengembalikan defaultMoodleUrl jika belum diset.
  bool isConfigured() {
    final url = _prefs.getString(AppConstants.keyServerIpUrl);
    return url != null && url.trim().isNotEmpty;
  }

  /// Menghapus semua data konfigurasi (untuk keperluan reset / testing).
  Future<void> clearAll() async {
    await _prefs.clear();
  }

  // ---------------------------------------------------------------------------
  // LOG STORAGE (PRD Section 12.1 — Ring Buffer)
  // ---------------------------------------------------------------------------

  /// Key SharedPreferences untuk menyimpan list log.
  static const String _keyLogs = 'exam_logs';

  /// Membaca semua entri log yang tersimpan.
  /// Mengembalikan List kosong jika belum ada log.
  List<String> getLogs() {
    return _prefs.getStringList(_keyLogs) ?? [];
  }

  /// Menyimpan [logs] ke SharedPreferences.
  /// Dipanggil oleh LoggerService setelah ring buffer diperbarui.
  void saveLogs(List<String> logs) {
    _prefs.setStringList(_keyLogs, logs);
    // Tidak di-await karena saveLogs dipanggil dari LoggerService._persistLog
    // secara fire-and-forget. Konsisten dengan pola log yang tidak boleh crash.
  }
}
