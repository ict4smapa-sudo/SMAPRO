// =============================================================================
// File        : security_helper.dart
// Fungsi Utama: Service keamanan native Android (FLAG_SECURE + Kiosk Mode)
//               dan iOS (Guided Access Detection via MethodChannel).
// Tanggal     : 27 Februari 2026
// PRD Section : Section 6.1, Section 11.2
// KRITIS      : Android → WAJIB Platform.isAndroid guard.
//               iOS     → WAJIB Platform.isIOS guard.
//               DILARANG eksekusi native call di platform yang salah.
// =============================================================================

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart';
import 'package:kiosk_mode/kiosk_mode.dart';

/// Singleton service untuk lockdown keamanan native (Android + iOS).
///
/// Penggunaan:
/// ```dart
/// await SecurityHelper().enableAndroidLockdown();      // Android: masuk ExamScreen
/// await SecurityHelper().disableAndroidLockdown();     // Android: keluar ExamScreen
/// final ok = await SecurityHelper().isIosGuidedAccessEnabled(); // iOS: cek sebelum load
/// ```
class SecurityHelper {
  // ---------------------------------------------------------------------------
  // SINGLETON PATTERN
  // ---------------------------------------------------------------------------

  static final SecurityHelper _instance = SecurityHelper._internal();

  factory SecurityHelper() => _instance;

  SecurityHelper._internal();

  // ---------------------------------------------------------------------------
  // CONSTANTS — MethodChannel iOS
  // ---------------------------------------------------------------------------

  /// Channel name WAJIB identik dengan yang didaftarkan di AppDelegate.swift
  static const MethodChannel _iosSecurityChannel = MethodChannel(
    'com.sman4jember.exambro/security',
  );

  // ---------------------------------------------------------------------------
  // PUBLIC METHODS — Enable Lockdown
  // ---------------------------------------------------------------------------

  /// Mengaktifkan lockdown penuh pada Android sebelum soal ujian ditampilkan.
  ///
  /// Urutan PRD Section 6.1:
  ///   1. FLAG_SECURE — layar tidak bisa di-screenshot atau di-screen-record
  ///   2. startKioskMode() — App Pinning aktif (siswa tidak bisa keluar aplikasi)
  ///
  /// KRITIS: HANYA dieksekusi di Android (Platform.isAndroid guard).
  ///         Jika bukan Android, langsung return tanpa efek.
  Future<void> enableAndroidLockdown() async {
    if (!Platform.isAndroid) return;

    // FLAG_SECURE sudah diaktifkan di MainActivity.kt via native Android API
    // (WindowManager.LayoutParams.FLAG_SECURE di onCreate).
    // Tidak perlu memanggil FlutterWindowManager — flutter_windowmanager v0.2.0
    // tidak kompatibel dengan Flutter v2 Embedding (error Registrar).

    // Aktifkan Kiosk Mode (App Pinning) — siswa tidak bisa pindah ke aplikasi lain
    await startKioskMode();
  }

  // ---------------------------------------------------------------------------
  // PUBLIC METHODS — Disable Lockdown
  // ---------------------------------------------------------------------------

  /// Menonaktifkan lockdown Android setelah sesi ujian berakhir.
  ///
  /// WAJIB dipanggil SEBELUM notifyListeners() pada ExamViewModel.reset()
  /// agar HP siswa kembali normal saat LoginScreen sudah ditampilkan.
  ///
  /// KRITIS: HANYA dieksekusi di Android (Platform.isAndroid guard).
  Future<void> disableAndroidLockdown() async {
    if (!Platform.isAndroid) return;

    // FLAG_SECURE dinonaktifkan di native Android pada saat Activity selesai.
    // Tidak perlu clearFlags dari Dart — MainActivity.kt yang mengelolanya.

    // Matikan Kiosk Mode — siswa kembali bisa mengakses aplikasi lain
    await stopKioskMode();
  }

  // ---------------------------------------------------------------------------
  // PUBLIC METHODS — iOS Guided Access Detection (PRD Section 11.2)
  // ---------------------------------------------------------------------------

  /// Mengecek apakah Guided Access sudah diaktifkan di iPhone/iPad.
  ///
  /// Menggunakan MethodChannel 'com.sman4jember.exambro/security'
  /// untuk memanggil UIAccessibility.isGuidedAccessEnabled via Swift.
  ///
  /// Return value:
  ///   - true  → Guided Access AKTIF → WebView Moodle boleh dimuat
  ///   - false → Guided Access BELUM AKTIF → WebView DILARANG dimuat
  ///
  /// PENTING: Jika bukan iOS, return true agar Android tidak terpengaruh.
  Future<bool> isIosGuidedAccessEnabled() async {
    // Non-iOS: return true (lolos) agar tidak memblokir Android
    if (!Platform.isIOS) return true;

    try {
      final bool? result = await _iosSecurityChannel.invokeMethod<bool>(
        'checkGuidedAccess',
      );
      return result ?? false; // null-safe: anggap false jika respons null
    } on PlatformException catch (e) {
      // PlatformException: channel tidak terdaftar, method tidak ada, dll.
      // Kembalikan false sebagai safe default → tampilkan UI peringatan.
      debugPrint('[IOS_GUIDED_ACCESS] PlatformException: ${e.message}');
      return false;
    } catch (_) {
      // Fallback untuk error tak terduga
      return false;
    }
  }
}
