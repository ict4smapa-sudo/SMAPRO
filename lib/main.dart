// =============================================================================
// File        : main.dart
// Fungsi Utama: Entry point aplikasi Exambro SMAN 4 Jember.
//               Menginisialisasi LocalStorageService, mendaftarkan semua
//               ViewModel via MultiProvider, dan menetapkan ThemeData dark mode.
// Tanggal     : 27 Februari 2026
// PRD Section : Section 2.1, Section 3.1
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'services/local_storage_service.dart';
import 'utils/colors.dart';
import 'utils/routes.dart';
import 'viewmodels/admin_viewmodel.dart';
import 'viewmodels/exam_viewmodel.dart';
import 'viewmodels/login_viewmodel.dart';
import 'viewmodels/splash_viewmodel.dart';
import 'views/admin_screen.dart';
import 'views/exam_screen.dart';
import 'views/login_screen.dart';
import 'views/splash_screen.dart';

/// Entry point aplikasi. Inisialisasi LocalStorageService sebelum runApp
/// agar SharedPreferences sudah siap digunakan oleh semua ViewModel.
Future<void> main() async {
  // Pastikan binding Flutter diinisialisasi sebelum memanggil plugin apapun.
  WidgetsFlutterBinding.ensureInitialized();

  // Inisialisasi LocalStorageService (SharedPreferences) satu kali di sini.
  // Setelah ini, LocalStorageService() bisa dipanggil di mana saja tanpa await.
  await LocalStorageService().init();

  runApp(
    // MultiProvider mendaftarkan semua ViewModel ke widget tree.
    // Urutan tidak berpengaruh — setiap ViewModel independen.
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SplashViewModel()),
        ChangeNotifierProvider(create: (_) => LoginViewModel()),
        ChangeNotifierProvider(create: (_) => AdminViewModel()),
        ChangeNotifierProvider(create: (_) => ExamViewModel()),
      ],
      child: const ExambroApp(),
    ),
  );
}

/// Root widget aplikasi Exambro.
class ExambroApp extends StatelessWidget {
  const ExambroApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // Identitas aplikasi
      title: 'Exambro SMAN 4 Jember',

      // Sembunyikan banner "DEBUG" di pojok kanan atas.
      debugShowCheckedModeBanner: false,

      // -----------------------------------------------------------------------
      // TEMA DARK MODE — PRD Section 2.1
      // Background utama: #121212 (grey[900]), konsisten di semua halaman.
      // -----------------------------------------------------------------------
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.accent,
          secondary: AppColors.accentLight,
          surface: AppColors.surface,
          onPrimary: AppColors.textPrimary,
          onSurface: AppColors.textPrimary,
          error: AppColors.snackError,
        ),

        // AppBar — background sama dengan scaffold agar seamless
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.background,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),

        // ElevatedButton — biru, rounded corners
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: AppColors.textPrimary,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        // TextField — border abu-abu, teks putih, fill gelap
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.inputFill,
          hintStyle: const TextStyle(color: AppColors.textHint),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.accent, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),

        // SnackBar — background gelap dengan teks putih
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: AppColors.surface,
          contentTextStyle: TextStyle(color: AppColors.textPrimary),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
        ),
      ),

      // -----------------------------------------------------------------------
      // ROUTING — Semua routes menggunakan konstanta AppRoutes
      // -----------------------------------------------------------------------

      // Halaman pertama yang ditampilkan adalah Splash Screen.
      initialRoute: AppRoutes.splash,

      routes: {
        AppRoutes.splash: (_) => const SplashScreen(),
        AppRoutes.login: (_) => const LoginScreen(),
        AppRoutes.admin: (_) => const AdminScreen(),
        AppRoutes.exam: (_) => const ExamScreen(),
      },
    );
  }
}
