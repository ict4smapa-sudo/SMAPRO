// =============================================================================
// File        : colors.dart
// Fungsi Utama: Definisi warna tema Dark Mode aplikasi Exambro SMAN 4 Jember.
//               Background utama: #121212 (Material grey[900]).
//               Digunakan konsisten di semua Screen dan Widget.
// Tanggal     : 27 Februari 2026
// PRD Section : Section 2.1 (Tema: Dark Mode statis #121212 / grey[900])
// =============================================================================

import 'package:flutter/material.dart';

/// Konstanta warna tema Dark Mode Exambro.
/// Kelas ini tidak boleh di-instantiasi — semua member bersifat static const.
class AppColors {
  // Konstruktor private
  AppColors._();

  // ---------------------------------------------------------------------------
  // BACKGROUND
  // ---------------------------------------------------------------------------

  /// Background utama seluruh halaman (#121212).
  static const Color background = Color(0xFF121212);

  /// Background surface / card (#1E1E1E) — sedikit lebih terang dari background.
  static const Color surface = Color(0xFF1E1E1E);

  /// Background input field (#2A2A2A).
  static const Color inputFill = Color(0xFF2A2A2A);

  // ---------------------------------------------------------------------------
  // TEXT
  // ---------------------------------------------------------------------------

  /// Teks utama — putih penuh.
  static const Color textPrimary = Color(0xFFFFFFFF);

  /// Teks sekunder — abu-abu terang.
  static const Color textSecondary = Color(0xFFAAAAAA);

  /// Teks hint / placeholder di TextField.
  static const Color textHint = Color(0xFF666666);

  // ---------------------------------------------------------------------------
  // ACCENT / BUTTON
  // ---------------------------------------------------------------------------

  /// Aksen utama — biru Material (ElevatedButton, progress indicator, dll).
  static const Color accent = Color(0xFF1565C0);

  /// Aksen biru terang untuk hover / pressed state.
  static const Color accentLight = Color(0xFF1976D2);

  /// Warna border input field dalam kondisi normal.
  static const Color border = Color(0xFF444444);

  // ---------------------------------------------------------------------------
  // SNACKBAR STATES
  // ---------------------------------------------------------------------------

  /// Snackbar hijau — aksi berhasil (contoh: "Konfigurasi berhasil disimpan").
  static const Color snackSuccess = Color(0xFF2E7D32);

  /// Snackbar merah — error kritis (contoh: "Token salah / ujian belum dibuka").
  static const Color snackError = Color(0xFFC62828);

  /// Snackbar kuning — peringatan (contoh: "Ujian belum dimulai oleh pengawas").
  static const Color snackWarning = Color(0xFFF9A825);

  /// Snackbar oranye — network error (contoh: "Tidak dapat terhubung ke server lokal").
  static const Color snackInfo = Color(0xFFE65100);
}
