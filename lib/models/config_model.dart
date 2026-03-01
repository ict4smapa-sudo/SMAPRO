// =============================================================================
// File        : config_model.dart
// Fungsi Utama: Model data untuk konfigurasi server lokal (Moodle + API).
//               Digunakan sebagai representasi data yang dibaca dari
//               LocalStorageService — memudahkan transfer antar layer jika
//               diperlukan di masa mendatang.
// Tanggal     : 27 Februari 2026
// PRD Section : Section 4.3, Section 4.4
// CATATAN     : Saat ini LocalStorageService diakses langsung oleh ViewModel.
//               ConfigModel disediakan sebagai data class yang valid dan bersih.
// =============================================================================

// RESERVED FOR FUTURE USE (PHASE 2 — OTA CONFIG UPDATES)
// Class ini saat ini tidak diinstansiasi secara langsung karena ViewModel mengakses
// LocalStorageService secara langsung. Di Phase 2, class ini akan menjadi pondasi
// untuk deserialisasi remote config dari endpoint /api/config OTA.

/// Model data konfigurasi server lokal Exambro.
///
/// Field:
///   - [moodleUrl]     : URL server Moodle (wajib diawali http:// atau https://)
///   - [apiValidateUrl]: URL endpoint POST /api/validate
///   - [adminPinHash]  : SHA-256 hash PIN admin (DILARANG plain text)
class ConfigModel {
  /// URL server Moodle. Contoh: "http://192.168.1.100/moodle"
  final String moodleUrl;

  /// URL endpoint API validasi token. Contoh: "http://192.168.1.100/api/validate"
  final String apiValidateUrl;

  /// SHA-256 hex string dari PIN admin.
  /// KRITIS: Field ini HANYA menyimpan hash, bukan PIN asli.
  final String adminPinHash;

  const ConfigModel({
    required this.moodleUrl,
    required this.apiValidateUrl,
    required this.adminPinHash,
  });

  /// Membuat ConfigModel dari Map JSON (untuk keperluan serialisasi masa depan).
  factory ConfigModel.fromJson(Map<String, dynamic> json) {
    return ConfigModel(
      moodleUrl: json['moodle_url'] as String? ?? '',
      apiValidateUrl: json['api_validate_url'] as String? ?? '',
      adminPinHash: json['admin_pin_hash'] as String? ?? '',
    );
  }

  /// Mengkonversi ConfigModel ke Map JSON.
  Map<String, dynamic> toJson() {
    return {
      'moodle_url': moodleUrl,
      'api_validate_url': apiValidateUrl,
      'admin_pin_hash': adminPinHash,
    };
  }

  /// Mengembalikan representasi string untuk debugging.
  /// KRITIS: adminPinHash tidak ditampilkan secara penuh demi keamanan.
  @override
  String toString() {
    return 'ConfigModel(moodleUrl: $moodleUrl, apiValidateUrl: $apiValidateUrl, '
        'adminPinHash: ${adminPinHash.isNotEmpty ? "[SET]" : "[EMPTY]"})';
  }
}
