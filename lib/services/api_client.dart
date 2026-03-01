// =============================================================================
// File        : api_client.dart
// Fungsi Utama: HTTP Client singleton untuk request validasi token ke backend.
//               Timeout: 10 detik. Retry otomatis: 1 kali (PRD Section 2.3).
//               Endpoint: POST /api/validate dengan body {token: "..."}.
// Tanggal     : 27 Februari 2026
// PRD Section : Section 2.3, Section 5.3, Section 6.3
// PERHATIAN   : Service bersifat singleton + stateless.
//               DILARANG menyimpan token dalam log atau variabel persisten.
// =============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/token_model.dart';
import '../utils/constants.dart';
import 'logger_service.dart';

/// Jenis error jaringan yang sudah dikategorikan — digunakan oleh LoginViewModel
/// untuk menampilkan pesan snackbar yang tepat sesuai PRD.
enum ApiErrorType {
  /// Server tidak dapat dijangkau (WiFi mati, IP salah, server down).
  networkError,

  /// Request time out setelah [AppConstants.httpTimeoutSeconds] detik, bahkan
  /// setelah 1 kali retry otomatis.
  timeout,

  /// Server mengembalikan HTTP error (4xx / 5xx).
  serverError,
}

/// Exception kustom yang dilempar oleh [ApiClient.validateToken].
class ApiException implements Exception {
  final ApiErrorType type;
  final String message;

  const ApiException({required this.type, required this.message});

  @override
  String toString() => 'ApiException(type: $type, message: $message)';
}

/// Singleton HTTP client untuk semua request ke backend Exambro.
///
/// Pola penggunaan:
/// ```dart
/// final client = ApiClient();
/// final response = await client.validateToken(apiUrl, token);
/// ```
class ApiClient {
  // ---------------------------------------------------------------------------
  // SINGLETON PATTERN
  // ---------------------------------------------------------------------------

  static final ApiClient _instance = ApiClient._internal();

  factory ApiClient() => _instance;

  ApiClient._internal();

  // ---------------------------------------------------------------------------
  // PUBLIC METHODS
  // ---------------------------------------------------------------------------

  /// Mengirim token ujian ke backend untuk divalidasi.
  ///
  /// [apiUrl] : URL endpoint, contoh "http://192.168.1.100/api/validate"
  ///             (diambil dari LocalStorageService di ViewModel)
  /// [token]  : Token yang diinput siswa di LoginScreen
  ///
  /// Returns [TokenResponse] jika request berhasil (HTTP 200).
  /// Throws [ApiException] dengan [ApiErrorType] yang sesuai jika gagal.
  ///
  /// Retry policy (PRD Section 2.3):
  ///   1. Coba pertama kali
  ///   2. Jika TimeoutException → coba sekali lagi
  ///   3. Jika masih gagal → lempar ApiException(type: timeout)
  Future<TokenResponse> validateToken(String apiUrl, String token) async {
    // Coba hingga maxRetryCount + 1 kali total (1 attempt awal + 1 retry).
    int attempts = 0;
    const maxAttempts = AppConstants.maxRetryCount + 1; // = 2

    while (attempts < maxAttempts) {
      attempts++;
      try {
        final response = await _doPost(apiUrl, {'token': token});
        // DILARANG LOG TOKEN — hanya log status HTTP dan hasil
        LoggerService().log(
          'Token validation attempt $attempts: HTTP ${response.statusCode}',
        );
        return _parseResponse(response);
      } on TimeoutException {
        // Jika masih ada sisa percobaan, log dan retry
        if (attempts < maxAttempts) {
          LoggerService().log(
            'Timeout attempt $attempts, retrying... (max: $maxAttempts)',
            isError: true,
          );
          continue;
        }
        // Sudah habis percobaan
        LoggerService().log(
          'Token validation failed: Timeout after $maxAttempts attempts',
          isError: true,
        );
        throw const ApiException(
          type: ApiErrorType.timeout,
          message:
              'Tidak dapat terhubung ke Server Lokal. Periksa koneksi Wi-Fi ujian.',
        );
      } on SocketException catch (e) {
        // SocketException terjadi saat tidak ada koneksi sama sekali — tidak perlu retry
        LoggerService().log(
          'Token validation failed: SocketException — ${e.message}',
          isError: true,
        );
        throw const ApiException(
          type: ApiErrorType.networkError,
          message:
              'Tidak dapat terhubung ke Server Lokal. Periksa koneksi Wi-Fi ujian.',
        );
      } on ApiException catch (e) {
        LoggerService().log(
          'Token validation failed: ApiException [${e.type.name}] ${e.message}',
          isError: true,
        );
        // ApiException dari _parseResponse (HTTP error) — re-throw langsung
        rethrow;
      } catch (e) {
        // Error tidak terduga
        LoggerService().log(
          'Token validation failed: Unexpected error — ${e.runtimeType}',
          isError: true,
        );
        throw ApiException(
          type: ApiErrorType.networkError,
          message: 'Terjadi kesalahan tidak terduga: ${e.toString()}',
        );
      }
    }

    // Seharusnya tidak pernah tercapai, tapi diperlukan Dart type system
    throw const ApiException(
      type: ApiErrorType.networkError,
      message: 'Gagal menghubungi server.',
    );
  }

  // ---------------------------------------------------------------------------
  // PRIVATE HELPERS
  // ---------------------------------------------------------------------------

  /// Melakukan HTTP POST dengan timeout sesuai PRD (10 detik).
  Future<http.Response> _doPost(String url, Map<String, dynamic> body) async {
    return http
        .post(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: AppConstants.httpTimeoutSeconds));
  }

  /// Mem-parsing http.Response menjadi TokenResponse.
  /// Melempar ApiException jika HTTP status bukan 200.
  TokenResponse _parseResponse(http.Response response) {
    if (response.statusCode == 200) {
      try {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return TokenResponse.fromJson(json);
      } catch (e) {
        throw const ApiException(
          type: ApiErrorType.serverError,
          message: 'Response server tidak valid.',
        );
      }
    } else if (response.statusCode == 429) {
      // Rate limit (PRD Section 5.4)
      throw const ApiException(
        type: ApiErrorType.serverError,
        message: 'Terlalu banyak percobaan. Tunggu 60 detik.',
      );
    } else {
      throw ApiException(
        type: ApiErrorType.serverError,
        message: 'Server error: HTTP ${response.statusCode}',
      );
    }
  }
}
