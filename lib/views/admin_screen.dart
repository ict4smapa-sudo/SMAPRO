// =============================================================================
// File        : admin_screen.dart
// Fungsi Utama: Halaman konfigurasi server Moodle dan PIN admin (route: '/admin').
//               HANYA dapat diakses melalui hidden gesture 7-tap + verifikasi PIN.
//               TIDAK ada link/tombol yang mengarah ke sini dari layar siswa.
// Tanggal     : 27 Februari 2026
// PRD Section : Section 4.3
// MVVM RULE   : Semua logika bisnis (validasi URL, hashing PIN) ada di AdminViewModel.
//               DILARANG mengakses SharedPreferences atau crypto langsung dari UI ini.
//               KRITIS: DILARANG simpan PIN plain text — hashing wajib di ViewModel.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../utils/colors.dart';
import '../utils/routes.dart';
import '../viewmodels/admin_viewmodel.dart';

/// Admin Screen — konfigurasi URL server Moodle dan PIN admin.
///
/// Diakses HANYA melalui hidden gesture 7-tap pada logo di LoginScreen
/// diikuti verifikasi PIN SHA-256.
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  // ---------------------------------------------------------------------------
  // CONTROLLERS
  // ---------------------------------------------------------------------------

  /// Controller URL server Moodle (contoh: http://192.168.1.100/moodle).
  final TextEditingController _moodleUrlController = TextEditingController();

  /// Controller URL endpoint API validasi token (contoh: http://192.168.1.100/api/validate).
  final TextEditingController _apiUrlController = TextEditingController();

  /// Controller PIN admin baru. Kosongkan jika tidak ingin mengganti PIN.
  /// Field ini bersifat obscure — PIN tidak terlihat saat diketik.
  final TextEditingController _pinController = TextEditingController();

  /// Visibility toggle untuk field PIN (icon mata).
  bool _isPinVisible = false;

  // ---------------------------------------------------------------------------
  // LIFECYCLE
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    // Muat konfigurasi tersimpan dari SharedPreferences ke TextField.
    // Menggunakan addPostFrameCallback agar context sudah valid.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final vm = context.read<AdminViewModel>();
      vm.loadConfiguration();
      // Isi nilai yang baru dimuat ke controller text
      _moodleUrlController.text = vm.moodleUrl;
      _apiUrlController.text = vm.apiValidateUrl;
    });
  }

  @override
  void dispose() {
    _moodleUrlController.dispose();
    _apiUrlController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // UI HELPERS — Snackbar
  // ---------------------------------------------------------------------------

  void _showSnackBar(String message, Color backgroundColor) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // ACTION HANDLER — Simpan Konfigurasi
  // ---------------------------------------------------------------------------

  Future<void> _handleSave() async {
    // Unfocus keyboard sebelum menyimpan
    FocusScope.of(context).unfocus();

    final vm = context.read<AdminViewModel>();
    await vm.saveConfiguration(
      moodleUrl: _moodleUrlController.text,
      apiUrl: _apiUrlController.text,
      newPin: _pinController.text,
    );

    if (!mounted) return;

    switch (vm.saveStatus) {
      case SaveStatus.success:
        // Berhasil → bersihkan field PIN + snackbar hijau (PRD Section 4.3)
        _pinController.clear();
        vm.resetSaveStatus();
        _showSnackBar('Konfigurasi berhasil disimpan.', AppColors.snackSuccess);

        // Update controller agar menampilkan URL yang sudah di-trim oleh ViewModel
        _moodleUrlController.text = vm.moodleUrl;
        _apiUrlController.text = vm.apiValidateUrl;

      case SaveStatus.validationError:
        // Validasi gagal → snackbar merah
        vm.resetSaveStatus();
        _showSnackBar(
          vm.errorMessage ?? 'Format URL tidak valid.',
          AppColors.snackError,
        );

      case SaveStatus.idle:
      case SaveStatus.saving:
        break;
    }
  }

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        // Tombol back default AppBar — navigasi ke halaman sebelumnya (LoginScreen)
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_rounded,
            color: AppColors.textSecondary,
          ),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Kembali ke Login',
        ),
        title: const Text(
          'Konfigurasi Admin',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),

      // SingleChildScrollView mencegah overflow saat keyboard muncul di HP
      body: Consumer<AdminViewModel>(
        builder: (context, vm, _) {
          final isSaving = vm.saveStatus == SaveStatus.saving;

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --------------------------------------------------------------
                // HEADER INFO
                // --------------------------------------------------------------
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border, width: 1),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: AppColors.accent,
                        size: 20,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Konfigurasi ini hanya visible untuk pengawas. '
                          'Siswa tidak dapat mengakses halaman ini.',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // --------------------------------------------------------------
                // SECTION: Konfigurasi Server
                // --------------------------------------------------------------
                const Text(
                  'KONFIGURASI SERVER',
                  style: TextStyle(
                    color: AppColors.accent,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),

                const SizedBox(height: 14),

                // FIELD 1: URL Server Moodle
                _buildLabel('URL Server Moodle'),
                const SizedBox(height: 8),
                TextField(
                  controller: _moodleUrlController,
                  enabled: !isSaving,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                  ),
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    hintText: 'http://192.168.1.100/moodle',
                    prefixIcon: Icon(
                      Icons.dns_rounded,
                      color: AppColors.textHint,
                      size: 20,
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                // FIELD 2: URL API Validasi Token
                _buildLabel('URL API Validasi Token'),
                const SizedBox(height: 8),
                TextField(
                  controller: _apiUrlController,
                  enabled: !isSaving,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                  ),
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    hintText: 'http://192.168.1.100/api/validate',
                    prefixIcon: Icon(
                      Icons.api_rounded,
                      color: AppColors.textHint,
                      size: 20,
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // DIVIDER
                const Divider(color: AppColors.border, thickness: 1),

                const SizedBox(height: 24),

                // --------------------------------------------------------------
                // SECTION: Keamanan PIN
                // --------------------------------------------------------------
                const Text(
                  'KEAMANAN PIN ADMIN',
                  style: TextStyle(
                    color: AppColors.accent,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),

                const SizedBox(height: 6),

                const Text(
                  'Kosongkan field ini jika tidak ingin mengganti PIN.',
                  style: TextStyle(color: AppColors.textHint, fontSize: 12),
                ),

                const SizedBox(height: 14),

                // FIELD 3: PIN Admin Baru — obscure text + toggle visibility
                _buildLabel('Ganti PIN Admin'),
                const SizedBox(height: 8),
                StatefulBuilder(
                  builder: (_, setFieldState) {
                    return TextField(
                      controller: _pinController,
                      enabled: !isSaving,
                      obscureText: !_isPinVisible,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                      ),
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => isSaving ? null : _handleSave(),
                      decoration: InputDecoration(
                        hintText: 'Kosongkan jika tidak ganti',
                        prefixIcon: const Icon(
                          Icons.lock_outline_rounded,
                          color: AppColors.textHint,
                          size: 20,
                        ),
                        // Toggle visibility icon di suffix
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isPinVisible
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: AppColors.textHint,
                            size: 20,
                          ),
                          onPressed: () {
                            setState(() => _isPinVisible = !_isPinVisible);
                          },
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 36),

                // --------------------------------------------------------------
                // TOMBOL: Simpan Konfigurasi
                // PRD: ElevatedButton, warna biru, lebar penuh
                // --------------------------------------------------------------
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: isSaving ? null : _handleSave,
                    icon: isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.textPrimary,
                            ),
                          )
                        : const Icon(Icons.save_rounded, size: 20),
                    label: Text(
                      isSaving ? 'Menyimpan...' : 'Simpan Konfigurasi',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // --------------------------------------------------------------
                // TOMBOL: Kembali ke Login
                // PRD: Tombol kembali ke halaman login
                // --------------------------------------------------------------
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: isSaving
                        ? null
                        : () {
                            // Pop kembali ke Login (dari pushNamed), atau
                            // pushReplacementNamed jika stack navigasi tidak memadai
                            if (Navigator.of(context).canPop()) {
                              Navigator.of(context).pop();
                            } else {
                              Navigator.of(
                                context,
                              ).pushReplacementNamed(AppRoutes.login);
                            }
                          },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: const BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                    label: const Text(
                      'Kembali ke Login',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                ),

                // Tambahan padding bawah agar konten tidak tertutup keyboard
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // WIDGET HELPER — Label TextField
  // ---------------------------------------------------------------------------

  /// Membuat label teks di atas setiap TextField dengan style yang konsisten.
  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.textSecondary,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}
