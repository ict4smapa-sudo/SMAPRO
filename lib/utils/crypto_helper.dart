// =============================================================================
// File        : crypto_helper.dart
// Fungsi Utama: Kumpulan utility kriptografi yang digunakan secara global.
//               Dipindahkan dari ViewModel individual untuk menegakkan DRY.
// Tanggal     : 01 Maret 2026
// PRD Section : Section 6 (Security Implementation)
// KRITIS      : DILARANG menambahkan metode yang log atau simpan plain-text PIN.
//               Hanya boleh digunakan untuk hashing satu arah (one-way).
// =============================================================================

import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Utility class kriptografi — semua metode bersifat statis (tidak perlu instansiasi).
///
/// Penggunaan:
/// ```dart
/// import '../utils/crypto_helper.dart';
/// final hash = CryptoHelper.hashPin('123456');
/// ```
class CryptoHelper {
  // Konstruktor private — class ini tidak boleh diinstansiasi.
  CryptoHelper._();

  /// Menghasilkan SHA-256 hex string dari [pin].
  ///
  /// KRITIS: DILARANG menyimpan atau me-log [pin] dalam bentuk plain text.
  /// Metode ini HANYA boleh dipanggil untuk keperluan autentikasi/penyimpanan hash.
  static String hashPin(String pin) {
    final bytes = utf8.encode(pin);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}
