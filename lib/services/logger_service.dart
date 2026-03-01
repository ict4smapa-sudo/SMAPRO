// =============================================================================
// File        : logger_service.dart
// Fungsi Utama: Service logging singleton dengan ring buffer (maks. 1000 entri).
//               Mode Debug: simpan semua log. Mode Release: simpan error saja.
//               Timestamp menggunakan DateTime.now() — tidak memerlukan package intl
//               karena Flutter tidak mewajibkan intl untuk ISO8601 formatting.
// Tanggal     : 27 Februari 2026
// PRD Section : Section 12.1
// KRITIS      : DILARANG KERAS mencatat token ujian atau PIN admin dalam plain text.
//               Log HANYA boleh berisi status, error type, dan timestamp.
// =============================================================================

import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;

import 'local_storage_service.dart';

/// Singleton logging service dengan ring buffer dan mode-aware persistence.
///
/// Penggunaan:
/// ```dart
/// LoggerService().log('Pesan info');
/// LoggerService().log('Error terjadi', isError: true);
/// ```
class LoggerService {
  // ---------------------------------------------------------------------------
  // SINGLETON PATTERN
  // ---------------------------------------------------------------------------

  static final LoggerService _instance = LoggerService._internal();

  factory LoggerService() => _instance;

  LoggerService._internal();

  // ---------------------------------------------------------------------------
  // CONSTANTS
  // ---------------------------------------------------------------------------

  /// Jumlah maksimum entri log yang disimpan di SharedPreferences.
  /// Jika melampaui batas, entri tertua dihapus (FIFO / ring buffer).
  static const int _maxLogEntries = 1000;

  // ---------------------------------------------------------------------------
  // DEPENDENCIES
  // ---------------------------------------------------------------------------

  final LocalStorageService _storage = LocalStorageService();

  // ---------------------------------------------------------------------------
  // PUBLIC METHODS
  // ---------------------------------------------------------------------------

  /// Mencatat [message] ke log storage.
  ///
  /// PRD Section 12.1 — Mode behavior:
  ///   - kDebugMode = true  : selalu simpan ke storage (semua event)
  ///   - kDebugMode = false : HANYA simpan jika [isError] = true
  ///
  /// Format log entry: "[YYYY-MM-DD HH:mm:ss] [LEVEL] message"
  ///
  /// KRITIS: [message] DILARANG mengandung token ujian atau PIN plain text.
  void log(String message, {bool isError = false}) {
    // Format timestamp menggunakan ISO8601 dari DateTime.now()
    // Contoh output: "2026-02-27 15:00:00"
    final now = DateTime.now();
    final timestamp =
        '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')} '
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}';

    final level = isError ? 'ERROR' : 'INFO ';
    final entry = '[$timestamp] [$level] $message';

    // Cetak ke console (selalu — bahkan di release untuk debugging crash)
    debugPrint('[LOG] $entry');

    // Persistence ke SharedPreferences (mode-aware)
    if (kDebugMode || isError) {
      _persistLog(entry);
    }
  }

  // ---------------------------------------------------------------------------
  // PRIVATE HELPERS
  // ---------------------------------------------------------------------------

  /// Menyimpan [entry] ke SharedPreferences dengan ring buffer.
  ///
  /// Ring buffer logic:
  ///   1. Ambil list log yang ada
  ///   2. Tambahkan entri baru
  ///   3. Jika > maxLogEntries: hapus entri tertua (removeAt(0))
  ///   4. Simpan kembali
  void _persistLog(String entry) {
    try {
      final logs = _storage.getLogs();
      logs.add(entry);

      // Ring buffer: hapus entri tertua jika melampaui batas
      while (logs.length > _maxLogEntries) {
        logs.removeAt(0);
      }

      _storage.saveLogs(logs);
    } catch (_) {
      // Logging failure tidak boleh crash aplikasi — silent fail
    }
  }
}
