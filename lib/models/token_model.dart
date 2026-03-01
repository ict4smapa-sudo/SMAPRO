// =============================================================================
// File        : token_model.dart
// Fungsi Utama: Model untuk response validasi token dari backend API.
//               Merepresentasikan data JSON yang dikembalikan oleh endpoint
//               POST /api/validate sesuai PRD Section 5.3.
// Tanggal     : 27 Februari 2026
// PRD Section : Section 5.3
// =============================================================================

/// Response dari endpoint POST /api/validate.
///
/// Contoh JSON sukses (token valid, ujian aktif):
/// ```json
/// { "success": true, "exam_active": true, "server_time": "...", "message": "Token valid",
///   "moodle_url": "http://...", "admin_pin": "123456", "exit_pin": "123456" }
/// ```
class TokenResponse {
  /// true jika token ditemukan di database backend.
  final bool success;

  /// true jika ujian sedang aktif/dibuka oleh pengawas.
  final bool examActive;

  /// Pesan dari server (untuk logging internal).
  final String message;

  /// Waktu server saat response dikirim (ISO 8601).
  final String serverTime;

  // ---------------------------------------------------------------------------
  // CENTRALIZED CONFIGURATION (dikembalikan hanya saat exam_active: true)
  // ---------------------------------------------------------------------------

  /// URL server Moodle dari backend. Null jika ujian belum aktif.
  final String? moodleUrl;

  /// PIN Masuk/Admin dari backend (plain text — SEGERA di-hash sebelum disimpan).
  /// Null jika ujian belum aktif.
  final String? adminPin;

  /// PIN Keluar Ujian dari backend (plain text — SEGERA di-hash sebelum disimpan).
  /// Null jika ujian belum aktif.
  final String? exitPin;

  const TokenResponse({
    required this.success,
    required this.examActive,
    required this.message,
    required this.serverTime,
    this.moodleUrl,
    this.adminPin,
    this.exitPin,
  });

  /// Factory constructor untuk mem-parsing JSON response dari backend.
  factory TokenResponse.fromJson(Map<String, dynamic> json) {
    return TokenResponse(
      success: json['success'] as bool? ?? false,
      examActive: json['exam_active'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      serverTime: json['server_time'] as String? ?? '',
      moodleUrl: json['moodle_url'] as String?,
      adminPin: json['admin_pin'] as String?,
      exitPin: json['exit_pin'] as String?,
    );
  }

  @override
  String toString() =>
      'TokenResponse(success: $success, examActive: $examActive, message: $message)';
}
