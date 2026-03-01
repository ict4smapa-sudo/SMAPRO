// =============================================================================
// File        : security_helper.dart
// Fungsi Utama: Service keamanan native Android (FLAG_SECURE + Kiosk Mode)
//               dan iOS (Guided Access Detection via MethodChannel).
// Tanggal     : 27 Februari 2026 | Update Kiosk: 01 Maret 2026
// PRD Section : Section 6.1, Section 11.2
// KRITIS      : Android → WAJIB Platform.isAndroid guard.
//               iOS     → WAJIB Platform.isIOS guard.
//               DILARANG eksekusi native call di platform yang salah.
// =============================================================================

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart';

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
  // CONSTANTS — MethodChannels
  // ---------------------------------------------------------------------------

  /// Channel kiosk mode Android + iOS Guided Access — channel tunggal terpadu.
  /// WAJIB identik dengan: MainActivity.kt (KIOSK_CHANNEL) & AppDelegate.swift.
  static const MethodChannel _kioskChannel = MethodChannel(
    'id.sman4jember.exambro/kiosk',
  );

  // ---------------------------------------------------------------------------
  // PUBLIC METHODS — Enable Lockdown
  // ---------------------------------------------------------------------------

  /// Mengaktifkan lockdown penuh pada Android sebelum soal ujian ditampilkan.
  ///
  /// Urutan PRD Section 6.1:
  ///   1. FLAG_SECURE — sudah aktif sejak onCreate() di MainActivity.kt
  ///   2. enableKioskMode via MethodChannel → startLockTask() native
  ///
  /// KRITIS: HANYA dieksekusi di Android (Platform.isAndroid guard).
  Future<void> enableAndroidLockdown() async {
    if (!Platform.isAndroid) return;

    // FLAG_SECURE sudah diaktifkan di MainActivity.kt onCreate() — tidak perlu diulang.

    // Aktifkan App Pinning (Screen Pinning) via MethodChannel → startLockTask() native
    try {
      await _kioskChannel.invokeMethod<void>('enableKioskMode');
      debugPrint('[SECURITY] Kiosk Mode AKTIF (startLockTask dipanggil).');
    } on PlatformException catch (e) {
      // PlatformException tidak boleh crash app — cukup log dan lanjut
      debugPrint('[SECURITY] enableKioskMode PlatformException: ${e.message}');
    } catch (e) {
      debugPrint('[SECURITY] enableKioskMode error: $e');
    }

    // Minta whitelist dari Battery Optimization OS (MIUI/HyperOS/ColorOS).
    // Hanya tampil sekali jika belum diizinkan — idempotent (tidak spam dialog).
    try {
      await _kioskChannel.invokeMethod<void>('requestBatteryExemption');
      debugPrint('[SECURITY] Battery Exemption diminta ke OS.');
    } catch (e) {
      // iOS / emulator tidak punya PowerManager — abaikan tanpa crash
      debugPrint('[SECURITY] requestBatteryExemption tidak tersedia: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // PUBLIC METHODS — Granular Lockdown (untuk split-phase di ExamViewModel)
  // ---------------------------------------------------------------------------

  /// Hanya mengaktifkan Kiosk Mode (Screen Pinning) tanpa Battery Exemption.
  /// Digunakan untuk fire-and-forget activation agar tidak blocking loadRequest.
  Future<void> enableKioskModeOnly() async {
    if (!Platform.isAndroid) return;
    try {
      await _kioskChannel.invokeMethod<void>('enableKioskMode');
      debugPrint('[SECURITY] Kiosk Mode AKTIF (startLockTask dipanggil).');
    } on PlatformException catch (e) {
      debugPrint('[SECURITY] enableKioskMode PlatformException: ${e.message}');
    } catch (e) {
      debugPrint('[SECURITY] enableKioskMode error: $e');
    }
  }

  /// Hanya meminta Battery Exemption tanpa mengaktifkan Kiosk Mode.
  /// Dijalankan setelah WebView frame pertama selesai (deferred 1500ms).
  Future<void> requestBatteryExemptionOnly() async {
    if (!Platform.isAndroid) return;
    try {
      await _kioskChannel.invokeMethod<void>('requestBatteryExemption');
      debugPrint('[SECURITY] Battery Exemption diminta ke OS.');
    } catch (e) {
      debugPrint('[SECURITY] requestBatteryExemption tidak tersedia: $e');
    }
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

    // Nonaktifkan App Pinning via MethodChannel → stopLockTask() native
    try {
      await _kioskChannel.invokeMethod<void>('disableKioskMode');
      debugPrint('[SECURITY] Kiosk Mode NONAKTIF (stopLockTask dipanggil).');
    } on PlatformException catch (e) {
      debugPrint('[SECURITY] disableKioskMode PlatformException: ${e.message}');
    } catch (e) {
      debugPrint('[SECURITY] disableKioskMode error: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // PUBLIC METHODS — iOS Guided Access Detection (PRD Section 11.2)
  // ---------------------------------------------------------------------------

  /// Mengecek apakah Guided Access sudah diaktifkan di iPhone/iPad.
  ///
  /// Menggunakan `_kioskChannel` (channel terpadu) — method "isGuidedAccessEnabled".
  /// Didaftarkan di AppDelegate.swift → UIAccessibility.isGuidedAccessEnabled.
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
      final bool? result = await _kioskChannel.invokeMethod<bool>(
        'isGuidedAccessEnabled',
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
