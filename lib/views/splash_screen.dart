// =============================================================================
// File        : splash_screen.dart
// Fungsi Utama: Halaman awal aplikasi (route: '/').
//               Menampilkan logo sekolah + CircularProgressIndicator selama 2 detik.
//               TIDAK ada teks versi atau informasi tambahan (PRD: KRITIS).
//               Selalu navigasi ke /login — konfigurasi kosong ditangani LoginViewModel.
// Tanggal     : 27 Februari 2026
// PRD Section : Section 4.1
// MVVM RULE   : Logika pengecekan SharedPreferences ada di SplashViewModel.
//               DILARANG mengakses SharedPreferences langsung dari Screen ini.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../utils/colors.dart';
import '../utils/routes.dart';
import '../viewmodels/splash_viewmodel.dart';

/// Splash Screen — halaman pertama yang ditampilkan saat aplikasi dibuka.
///
/// Alur UI berdasarkan [SplashState]:
///   - initial / checking : tampilkan logo + loading indicator
///   - readyToNavigate    : pushReplacementNamed ke /login (tidak boleh kembali)
///
/// Konfigurasi kosong tidak memblokir di sini — login_viewmodel.dart yang menangani.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  // Flag untuk memastikan navigasi hanya dipanggil sekali.
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    // Jalankan checkConfiguration() setelah frame pertama selesai di-render.
    // Menggunakan addPostFrameCallback agar context sudah valid saat dipanggil.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Ambil ViewModel tanpa listen — kita hanya perlu panggil method sekali.
      context.read<SplashViewModel>().checkConfiguration();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Consumer<SplashViewModel>(
        builder: (context, viewModel, _) {
          // ------------------------------------------------------------------
          // Reaksi terhadap perubahan state ViewModel
          // Menggunakan addPostFrameCallback untuk menghindari setState() di
          // tengah frame build yang sedang berjalan.
          // ------------------------------------------------------------------

          if (viewModel.state == SplashState.readyToNavigate && !_navigated) {
            _navigated = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                // PRD KRITIS: DILARANG navigasi ke halaman lain selain /login.
                Navigator.of(context).pushReplacementNamed(AppRoutes.login);
              }
            });
          }

          // ------------------------------------------------------------------
          // UI — Minimalis, sesuai PRD Section 4.1:
          //   Logo sekolah di tengah + loading indicator di bawahnya.
          //   TIDAK ada teks versi atau informasi lain.
          // ------------------------------------------------------------------
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo sekolah SMAN 4 Jember — dari assets resmi.
                Image.asset(
                  'assets/images/logo_smapa.png',
                  width: 150,
                  height: 150,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.school, size: 100, color: Colors.blue),
                ),

                const SizedBox(height: 40),

                // Loading indicator — kecil, warna aksen biru
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.accent),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
