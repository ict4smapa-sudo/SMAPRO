// =============================================================================
// File        : admin_viewmodel.dart
// Fungsi Utama: ViewModel untuk AdminScreen.
//               Logic: membaca dan menyimpan konfigurasi URL server Moodle,
//               URL API validasi, dan PIN admin (SHA-256 ONLY — bukan plain text).
// Tanggal     : 27 Februari 2026
// PRD Section : Section 4.3
// MVVM RULE   : ViewModel HANYA boleh berisi logika bisnis.
//               DILARANG ada kode UI (Widget) di dalam ViewModel.
//               KRITIS: PIN TIDAK BOLEH disimpan atau dilog dalam plain text.
// =============================================================================

import 'package:flutter/foundation.dart';

import '../services/local_storage_service.dart';
import '../services/logger_service.dart';
import '../utils/crypto_helper.dart';

// =============================================================================
// ENUM: Hasil operasi simpan konfigurasi
// =============================================================================

/// Enum yang digunakan AdminScreen untuk menampilkan feedback yang tepat.
enum SaveStatus {
  /// Kondisi awal / idle (belum ada operasi simpan).
  idle,

  /// Sedang menyimpan ke SharedPreferences.
  saving,

  /// Konfigurasi berhasil disimpan → snackbar hijau.
  success,

  /// Validasi gagal (format URL salah, dll.) → snackbar merah.
  validationError,
}

// =============================================================================
// VIEWMODEL
// =============================================================================

/// ViewModel untuk AdminScreen — mengelola konfigurasi server Moodle dan PIN.
class AdminViewModel extends ChangeNotifier {
  // ---------------------------------------------------------------------------
  // DEPENDENCIES
  // ---------------------------------------------------------------------------

  final LocalStorageService _storage = LocalStorageService();
  final LoggerService _logger = LoggerService();

  // ---------------------------------------------------------------------------
  // STATE
  // ---------------------------------------------------------------------------

  /// URL server Moodle yang tersimpan — ditampilkan di TextField saat load.
  String _moodleUrl = '';
  String get moodleUrl => _moodleUrl;

  /// URL endpoint API validasi token — ditampilkan di TextField saat load.
  String _apiValidateUrl = '';
  String get apiValidateUrl => _apiValidateUrl;

  /// Status operasi simpan terakhir.
  SaveStatus _saveStatus = SaveStatus.idle;
  SaveStatus get saveStatus => _saveStatus;

  /// Pesan error validasi — null jika tidak ada error, berisi pesan jika ada.
  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // ---------------------------------------------------------------------------
  // PUBLIC METHODS — Load
  // ---------------------------------------------------------------------------

  /// Membaca konfigurasi dari SharedPreferences untuk diisi ke TextField.
  ///
  /// Dipanggil saat AdminScreen pertama kali dibuka (di initState).
  /// Menggunakan nilai dari LocalStorageService — tidak ada network call.
  void loadConfiguration() {
    _moodleUrl = _storage.getMoodleUrl();
    _apiValidateUrl = _storage.getApiValidateUrl();
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // PUBLIC METHODS — Save
  // ---------------------------------------------------------------------------

  /// Memvalidasi dan menyimpan konfigurasi ke SharedPreferences.
  ///
  /// Alur sesuai PRD Section 4.3:
  ///   1. Validasi [moodleUrl] dan [apiUrl] wajib diawali http:// atau https://
  ///   2. Trim trailing slash '/' dari kedua URL secara otomatis
  ///   3. Simpan URL ke SharedPreferences via LocalStorageService
  ///   4. Jika [newPin] tidak kosong: hash SHA-256 → simpan, timpa lama
  ///      Jika [newPin] kosong: biarkan hash PIN lama tidak berubah
  ///   5. Emit status sukses / error
  ///
  /// KRITIS: [newPin] HANYA digunakan untuk hashing — tidak pernah disimpan.
  Future<void> saveConfiguration({
    required String moodleUrl,
    required String apiUrl,
    required String newPin,
  }) async {
    // Guard: jangan proses jika sedang saving
    if (_saveStatus == SaveStatus.saving) return;

    _saveStatus = SaveStatus.saving;
    _errorMessage = null;
    notifyListeners();

    // -------------------------------------------------------------------------
    // VALIDASI URL
    // -------------------------------------------------------------------------
    final trimmedMoodleUrl = _trimTrailingSlash(moodleUrl.trim());
    final trimmedApiUrl = _trimTrailingSlash(apiUrl.trim());

    if (!_isValidUrl(trimmedMoodleUrl)) {
      _logger.log(
        'Admin config validation failed: Moodle URL invalid',
        isError: true,
      );
      _saveStatus = SaveStatus.validationError;
      _errorMessage =
          'Format URL Server Moodle tidak valid. Harus diawali http:// atau https://';
      notifyListeners();
      return;
    }

    if (!_isValidUrl(trimmedApiUrl)) {
      _logger.log(
        'Admin config validation failed: API URL invalid',
        isError: true,
      );
      _saveStatus = SaveStatus.validationError;
      _errorMessage =
          'Format URL API tidak valid. Harus diawali http:// atau https://';
      notifyListeners();
      return;
    }

    // -------------------------------------------------------------------------
    // SIMPAN URL
    // -------------------------------------------------------------------------
    await _storage.setMoodleUrl(trimmedMoodleUrl);
    await _storage.setApiValidateUrl(trimmedApiUrl);

    // Update state lokal
    _moodleUrl = trimmedMoodleUrl;
    _apiValidateUrl = trimmedApiUrl;

    // -------------------------------------------------------------------------
    // SIMPAN PIN (hanya jika newPin tidak kosong)
    // PRD KRITIS: DILARANG simpan plain text — wajib SHA-256 dulu.
    // -------------------------------------------------------------------------
    if (newPin.trim().isNotEmpty) {
      final pinHash = CryptoHelper.hashPin(newPin.trim());
      await _storage.setAdminPinHash(pinHash);
    }
    // Jika newPin kosong → hash PIN lama di SharedPreferences TIDAK diubah.

    // Log konfigurasi baru — DILARANG log PIN, hanya log URL dan status PIN diubah
    _logger.log(
      'Admin config saved: Moodle=$trimmedMoodleUrl | API=$trimmedApiUrl'
      ' | PIN changed: ${newPin.trim().isNotEmpty}',
    );

    _saveStatus = SaveStatus.success;
    notifyListeners();
  }

  /// Reset saveStatus ke idle setelah UI menampilkan feedback (snackbar).
  void resetSaveStatus() {
    _saveStatus = SaveStatus.idle;
    _errorMessage = null;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // PRIVATE HELPERS
  // ---------------------------------------------------------------------------

  /// Memvalidasi bahwa URL diawali dengan 'http://' atau 'https://'.
  bool _isValidUrl(String url) {
    if (url.isEmpty) return false;
    return url.startsWith('http://') || url.startsWith('https://');
  }

  /// Menghapus trailing slash '/' dari URL secara otomatis.
  /// Contoh: "http://192.168.1.100/moodle/" → "http://192.168.1.100/moodle"
  String _trimTrailingSlash(String url) {
    if (url.endsWith('/')) {
      return url.substring(0, url.length - 1);
    }
    return url;
  }

  // Hashing: gunakan CryptoHelper.hashPin() — dipindahkan ke crypto_helper.dart (DRY fix W-06)
}
