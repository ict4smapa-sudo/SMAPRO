// =============================================================================
// File        : splash_viewmodel.dart
// Fungsi Utama: ViewModel untuk SplashScreen.
//               Logic: mengecek konfigurasi server di SharedPreferences,
//               lalu menentukan apakah navigasi ke /login atau tampilkan
//               dialog peringatan pengawas.
// Tanggal     : 27 Februari 2026
// PRD Section : Section 4.1
// MVVM RULE   : ViewModel HANYA boleh berisi logika bisnis.
//               DILARANG ada kode UI (Widget) di dalam ViewModel.
// =============================================================================

import 'package:flutter/foundation.dart';
import '../utils/constants.dart';

/// Enum state Splash Screen — digunakan UI untuk menentukan apa yang ditampilkan.
enum SplashState {
  /// Kondisi awal saat ViewModel baru dibuat.
  initial,

  /// Sedang dalam delay 2 detik (menampilkan logo + loading).
  checking,

  /// Delay selesai — UI wajib navigasi ke /login.
  /// Berlaku baik saat konfigurasi ADA maupun KOSONG.
  readyToNavigate,
}

/// ViewModel untuk SplashScreen.
/// Di-provide melalui [ChangeNotifierProvider] di main.dart.
class SplashViewModel extends ChangeNotifier {
  // ---------------------------------------------------------------------------
  // STATE
  // ---------------------------------------------------------------------------

  SplashState _state = SplashState.initial;

  /// State saat ini dari proses pengecekan konfigurasi.
  SplashState get state => _state;

  // ---------------------------------------------------------------------------
  // PUBLIC METHODS
  // ---------------------------------------------------------------------------

  /// Menjalankan delay splash dan selalu lanjut ke /login.
  ///
  /// Alur baru (fix logical trap):
  ///   1. Set state = checking
  ///   2. Delay 2 detik (menampilkan logo + loading indicator)
  ///   3. Set state = readyToNavigate — UI navigasi ke /login
  ///
  /// Konfigurasi kosong TIDAK memblokir di sini.
  /// LoginViewModel yang menangani error konfigurasi kosong via snackbar.
  Future<void> checkConfiguration() async {
    // Hindari re-run jika sudah tidak di state awal
    if (_state != SplashState.initial) return;

    _state = SplashState.checking;
    notifyListeners();

    // Delay 2 detik sesuai PRD — baik konfigurasi ADA maupun KOSONG
    await Future.delayed(
      const Duration(seconds: AppConstants.splashDelaySeconds),
    );

    _state = SplashState.readyToNavigate;
    notifyListeners();
  }

  /// Reset state ke initial — digunakan jika perlu menjalankan checkConfiguration()
  /// kembali (misalnya setelah pengawas mengisi konfigurasi).
  void reset() {
    _state = SplashState.initial;
    notifyListeners();
  }
}
