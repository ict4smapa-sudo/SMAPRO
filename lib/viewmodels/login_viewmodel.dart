// =============================================================================
// File        : login_viewmodel.dart
// Fungsi Utama: ViewModel untuk LoginScreen.
//               Logic: validasi token via API, hidden gesture counter,
//               verifikasi PIN admin (SHA-256), dan manajemen UI state.
// Tanggal     : 27 Februari 2026
// PRD Section : Section 4.2
// MVVM RULE   : ViewModel HANYA boleh berisi logika bisnis.
//               DILARANG ada kode UI (Widget) di dalam ViewModel.
//               KRITIS: PIN TIDAK BOLEH disimpan atau dilog dalam plain text.
// =============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../services/api_client.dart';
import '../services/local_storage_service.dart';
import '../services/logger_service.dart';
import '../utils/constants.dart';
import '../utils/crypto_helper.dart';

// =============================================================================
// ENUM: State manajemen Token Submission
// =============================================================================

/// Enum untuk status pengiriman token — digunakan UI untuk menampilkan
/// loading indicator dan snackbar yang tepat.
enum SubmitStatus {
  /// Kondisi awal / idle.
  idle,

  /// Sedang mengirim request ke backend API.
  loading,

  /// Token valid dan ujian aktif — UI harus navigasi ke /exam.
  successNavigate,

  /// Token valid tapi ujian belum dibuka — snackbar kuning.
  examNotActive,

  /// Token tidak ditemukan di database server — snackbar merah.
  tokenInvalid,

  /// Error jaringan / timeout — snackbar oranye.
  networkError,

  /// Rate limit dari server (429) — snackbar merah.
  rateLimited,
}

// =============================================================================
// VIEWMODEL
// =============================================================================

/// ViewModel untuk LoginScreen.
class LoginViewModel extends ChangeNotifier {
  // ---------------------------------------------------------------------------
  // DEPENDENCIES
  // ---------------------------------------------------------------------------

  final ApiClient _apiClient = ApiClient();
  final LocalStorageService _storage = LocalStorageService();
  final LoggerService _logger = LoggerService();

  // ---------------------------------------------------------------------------
  // STATE — Token Submission
  // ---------------------------------------------------------------------------

  SubmitStatus _submitStatus = SubmitStatus.idle;

  /// Status pengiriman token saat ini.
  SubmitStatus get submitStatus => _submitStatus;

  /// Pesan error yang akan ditampilkan di snackbar. Null jika tidak ada error.
  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // ---------------------------------------------------------------------------
  // STATE — Hidden Gesture (Admin Access)
  // ---------------------------------------------------------------------------

  /// Counter tap tersembunyi pada logo. Reset setiap [AppConstants.adminTapWindowSeconds] detik.
  int _tapCount = 0;

  /// Timer untuk mereset [_tapCount] saat window 3 detik berakhir.
  Timer? _tapResetTimer;

  // ---------------------------------------------------------------------------
  // PUBLIC METHODS — Token Submission
  // ---------------------------------------------------------------------------

  /// Mengirim token ke backend API untuk divalidasi.
  ///
  /// Alur sesuai PRD Section 4.2:
  ///   1. Validasi input tidak boleh kosong
  ///   2. Set state = loading
  ///   3. Kirim POST ke URL API (dari LocalStorageService)
  ///   4. Tangani setiap kasus response dengan state yang sesuai
  ///
  /// UI bereaksi terhadap perubahan [submitStatus] dan [errorMessage].
  Future<void> submitToken(String token) async {
    // Guard: Jangan kirim request jika sedang loading
    if (_submitStatus == SubmitStatus.loading) return;

    // Validasi input tidak boleh kosong (handle di UI juga, tapi double-check di sini)
    if (token.trim().isEmpty) return;

    // Gunakan URL dari storage; fallback ke defaultApiUrl hardcoded jika belum dikonfigurasi.
    // Ini memungkinkan aplikasi bekerja langsung tanpa konfigurasi manual via AdminScreen.
    final apiUrl = _storage.getApiValidateUrl();

    _submitStatus = SubmitStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiClient.validateToken(apiUrl, token.trim());

      if (response.success && response.examActive) {
        // Token valid & ujian aktif → simpan konfigurasi dari server lalu navigasi ke /exam
        // KRITIS: PIN di-hash SEBELUM disimpan — DILARANG simpan plain text.
        if (response.moodleUrl != null && response.moodleUrl!.isNotEmpty) {
          await _storage.setMoodleUrl(response.moodleUrl!);
          _logger.log('submitToken: moodleUrl dari server disimpan ke storage');
        }
        if (response.adminPin != null && response.adminPin!.isNotEmpty) {
          await _storage.setAdminPinHash(
            CryptoHelper.hashPin(response.adminPin!),
          );
          // DILARANG log plain text PIN
        }
        if (response.exitPin != null && response.exitPin!.isNotEmpty) {
          await _storage.setExitPinHash(
            CryptoHelper.hashPin(response.exitPin!),
          );
        }

        _logger.log(
          'Token validation: SUCCESS — exam active, navigating to /exam',
        );
        _submitStatus = SubmitStatus.successNavigate;
      } else if (response.success && !response.examActive) {
        // Token valid tapi ujian belum dibuka oleh pengawas
        _logger.log('Token validation: SUCCESS — exam not yet active');
        _submitStatus = SubmitStatus.examNotActive;
        _errorMessage = 'Ujian belum dimulai oleh pengawas.';
      } else {
        // Token tidak ditemukan / salah
        _logger.log('Token validation: INVALID token submitted', isError: true);
        _submitStatus = SubmitStatus.tokenInvalid;
        _errorMessage = 'Token salah / ujian belum dibuka.';
      }
    } on ApiException catch (e) {
      // Kategorisasi error sesuai PRD
      // (ApiClient sudah log detail error — di sini hanya log kategori UI)
      _logger.log(
        'Login error: [${e.type.name}] — UI akan tampilkan snackbar',
        isError: true,
      );
      switch (e.type) {
        case ApiErrorType.timeout:
        case ApiErrorType.networkError:
          _submitStatus = SubmitStatus.networkError;
          _errorMessage =
              'Tidak dapat terhubung ke server lokal. Periksa koneksi Wi-Fi ujian.';
        case ApiErrorType.serverError:
          // Cek apakah pesan mengandung kata "rate limit"
          if (e.message.contains('banyak percobaan')) {
            _submitStatus = SubmitStatus.rateLimited;
            _errorMessage = e.message;
          } else {
            _submitStatus = SubmitStatus.networkError;
            _errorMessage = e.message;
          }
      }
    } catch (e) {
      _logger.log('Login error: Unexpected — ${e.runtimeType}', isError: true);
      _submitStatus = SubmitStatus.networkError;
      _errorMessage =
          'Tidak dapat terhubung ke server lokal. Periksa koneksi Wi-Fi ujian.';
    }

    notifyListeners();
  }

  /// Reset submitStatus ke idle setelah UI menangani state (menampilkan snackbar/navigasi).
  void resetSubmitStatus() {
    _submitStatus = SubmitStatus.idle;
    _errorMessage = null;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // PUBLIC METHODS — Hidden Gesture + PIN Admin
  // ---------------------------------------------------------------------------

  /// Dipanggil setiap kali logo di-tap.
  ///
  /// Alur sesuai PRD Section 4.2 — Hidden Gesture:
  ///   1. Increment [_tapCount]
  ///   2. Reset (atau restart) Timer 3 detik
  ///   3. Jika [_tapCount] ≥ 7 → kembalikan true (signal UI untuk tampilkan dialog PIN)
  ///   4. Timer selesai → reset [_tapCount] ke 0
  ///
  /// Returns true jika sudah mencapai adminTapCount (7 tap).
  bool onLogoTap() {
    _tapCount++;

    // Restart timer setiap kali ada tap baru
    _tapResetTimer?.cancel();
    _tapResetTimer = Timer(
      const Duration(seconds: AppConstants.adminTapWindowSeconds),
      () {
        _tapCount = 0;
      },
    );

    if (_tapCount >= AppConstants.adminTapCount) {
      // Reset counter setelah trigger
      _tapCount = 0;
      _tapResetTimer?.cancel();
      // Log: hidden gesture sukses — DILARANG log PIN atau detail sensitif
      LoggerService().log('Hidden admin gesture triggered — PIN dialog opened');
      return true; // signal ke UI untuk tampilkan dialog PIN
    }

    return false;
  }

  /// Memverifikasi PIN admin (PIN MASUK) yang diinput pengguna.
  ///
  /// Membandingkan hash [inputPin] dengan [getAdminPinHash()].
  /// Fallback: jika hash belum ada → bandingkan dengan hash '123456'.
  Future<bool> verifyAdminPin(String inputPin) async {
    try {
      final inputHash = CryptoHelper.hashPin(inputPin);
      final storedHash = _storage.getAdminPinHash();

      if (storedHash == null || storedHash.isEmpty) {
        return inputHash == CryptoHelper.hashPin('123456');
      }
      return inputHash == storedHash;
    } catch (e) {
      _logger.log('verifyAdminPin error: ${e.runtimeType}', isError: true);
      return false;
    }
  }

  /// Memverifikasi PIN keluar ujian (EXIT PIN) yang diinput pengguna.
  /// Verifikasi Exit PIN secara REAL-TIME dari server (Live API Call).
  ///
  /// Alur:
  ///   1. POST ke /api/verify-exit dengan timeout 5 detik.
  ///   2. Jika server merespons: gunakan nilai `valid` dari response.
  ///   3. CRITICAL FALLBACK: Jika SocketException, TimeoutException, atau
  ///      server error → gunakan hash lokal agar siswa tidak terjebak.
  Future<bool> verifyExitPin(String inputPin) async {
    // -------------------------------------------------------------------------
    // LIVE API VERIFICATION
    // -------------------------------------------------------------------------
    try {
      final apiUrl = _storage.getApiValidateUrl();
      // Konstruksi exitUrl secara absolut dari base URL.
      // Lebih aman dari replaceAll() yang bergantung pada format string tertentu.
      final baseUrl = apiUrl.substring(0, apiUrl.lastIndexOf('/'));
      final exitUrl = '$baseUrl/verify-exit';

      final response = await http
          .post(
            Uri.parse(exitUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'pin': inputPin}),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true) {
          return data['valid'] == true;
        }
      }
      // Server merespons tapi hasilnya tidak valid atau format salah
      // Tetap fallback ke lokal agar tidak memblokir
      _logger.log(
        '[EXIT-PIN] Server response tidak expected, fallback ke lokal',
        isError: false,
      );
    } on SocketException {
      _logger.log(
        '[EXIT-PIN] SocketException — fallback ke hash lokal',
        isError: false,
      );
    } on TimeoutException {
      _logger.log(
        '[EXIT-PIN] Timeout 5s — fallback ke hash lokal',
        isError: false,
      );
    } catch (e) {
      _logger.log(
        '[EXIT-PIN] Error tidak terduga: ${e.runtimeType} — fallback',
        isError: true,
      );
    }

    // -------------------------------------------------------------------------
    // FALLBACK: Verifikasi lokal via SHA-256 (offline / server down)
    // -------------------------------------------------------------------------
    try {
      final inputHash = CryptoHelper.hashPin(inputPin);
      final storedHash = _storage.getExitPinHash();
      if (storedHash == null || storedHash.isEmpty) {
        return inputHash == CryptoHelper.hashPin('123456');
      }
      return inputHash == storedHash;
    } catch (e) {
      _logger.log(
        'verifyExitPin fallback error: ${e.runtimeType}',
        isError: true,
      );
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // LIFECYCLE
  // ---------------------------------------------------------------------------

  @override
  void dispose() {
    _tapResetTimer?.cancel();
    super.dispose();
  }
}
