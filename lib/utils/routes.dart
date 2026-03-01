// =============================================================================
// File        : routes.dart
// Fungsi Utama: Definisi named routes untuk navigasi aplikasi Exambro.
//               Semua navigasi WAJIB menggunakan konstanta di class ini.
//               DILARANG hard-code string route di luar file ini.
// Tanggal     : 27 Februari 2026
// PRD Section : Section 4.1 – 4.4
// =============================================================================

/// Named routes aplikasi Exambro SMAN 4 Jember.
///
/// Pola navigasi yang diizinkan sesuai PRD:
///   splash → login  : Navigator.pushReplacementNamed — tidak boleh kembali
///   login  → admin  : Navigator.pushNamed            — bisa kembali ke login
///   login  → exam   : Navigator.pushReplacementNamed — tidak boleh kembali
///   exam   → login  : Navigator.pushReplacementNamed — setelah session isolation
class AppRoutes {
  // Konstruktor private
  AppRoutes._();

  /// Route Splash Screen — halaman awal, cek konfigurasi server. PRD: Section 4.1
  static const String splash = '/';

  /// Route Login Screen — input token ujian siswa. PRD: Section 4.2
  static const String login = '/login';

  /// Route Admin Screen — konfigurasi server (hanya via hidden gesture + PIN). PRD: Section 4.3
  static const String admin = '/admin';

  /// Route Exam Screen — WebView Moodle fullscreen + lockdown. PRD: Section 4.4
  static const String exam = '/exam';
}
