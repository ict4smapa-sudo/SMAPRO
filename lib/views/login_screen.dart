// =============================================================================
// File        : login_screen.dart
// Fungsi Utama: Halaman input token ujian oleh siswa (route: '/login').
//               Berisi hidden gesture 7-tap pada logo untuk akses Admin Screen.
//               TIDAK ada tombol back, TIDAK ada link navigasi lain ke /admin.
// Tanggal     : 27 Februari 2026
// PRD Section : Section 4.2
// MVVM RULE   : Semua logika bisnis ada di LoginViewModel.
//               DILARANG mengakses SharedPreferences/ApiClient langsung dari sini.
//               KRITIS: DILARANG langsung navigasi ke /admin tanpa verifikasi PIN.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/local_storage_service.dart';
import '../utils/colors.dart';
import '../utils/crypto_helper.dart';
import '../utils/routes.dart';
import '../viewmodels/login_viewmodel.dart';

/// Login Screen — halaman input token ujian siswa.
///
/// Interaksi utama:
///   1. Siswa mengetik token → tap "Mulai Ujian" → validasi ke API
///   2. Hidden gesture: 7x tap logo dalam 3 detik → dialog PIN → /admin (jika benar)
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // ---------------------------------------------------------------------------
  // CONTROLLERS
  // ---------------------------------------------------------------------------

  /// Controller untuk TextField input token ujian.
  final TextEditingController _tokenController = TextEditingController();

  /// FocusNode untuk mengatur keyboard saat submit.
  final FocusNode _tokenFocusNode = FocusNode();

  /// Jumlah pelanggaran dari 3-Strike Policy.
  /// 0-2 = boleh login, >=3 = layar merah blokir sampai PIN Pengawas benar.
  int _violationCount = 0;

  // ---------------------------------------------------------------------------
  // LIFECYCLE
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    // Baca counter pelanggaran SECARA SINKRON dari _prefs yang sudah di-init di main().
    // Tidak perlu addPostFrameCallback — _prefs sudah siap sebelum runApp().
    _violationCount = LocalStorageService().getViolationCount();
  }

  @override
  void dispose() {
    _tokenController.dispose();
    _tokenFocusNode.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // UI HELPERS — Snackbar
  // ---------------------------------------------------------------------------

  /// Menampilkan snackbar dengan warna dan pesan sesuai PRD.
  void _showSnackBar(String message, Color backgroundColor) {
    if (!mounted) return;
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
  // UI HELPERS — Banned Unlock Dialog
  // ---------------------------------------------------------------------------

  /// Menampilkan [_LoginSupervisorPinDialog] untuk membuka blokir perangkat banned.
  /// Controller lifecycle dikelola sepenuhnya oleh widget dialog.
  void _showBannedUnlockDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _LoginSupervisorPinDialog(
        onSuccess: () async {
          // Reset counter pelanggaran ke 0 di persistent storage
          await LocalStorageService().resetViolationCount();
          if (!mounted) return;
          setState(() => _violationCount = 0);
        },
        onWrongPin: () =>
            _showSnackBar('PIN salah. Hubungi pengawas.', Colors.red.shade300),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // UI HELPERS — Submit Token
  // ---------------------------------------------------------------------------

  /// Dipanggil saat tombol "Mulai Ujian" ditekan.
  Future<void> _handleSubmitToken() async {
    final token = _tokenController.text.trim();

    if (token.isEmpty) {
      _showSnackBar('Token ujian tidak boleh kosong.', AppColors.snackError);
      return;
    }

    _tokenFocusNode.unfocus();
    final vm = context.read<LoginViewModel>();
    await vm.submitToken(token);

    if (!mounted) return;

    // Reaksi terhadap submitStatus setelah await selesai
    switch (vm.submitStatus) {
      case SubmitStatus.successNavigate:
        // Token valid & ujian aktif → navigasi ke /exam (tidak bisa kembali ke login)
        vm.resetSubmitStatus();
        Navigator.of(context).pushReplacementNamed(AppRoutes.exam);

      case SubmitStatus.examNotActive:
        // Token valid tapi ujian belum dibuka — snackbar kuning
        vm.resetSubmitStatus();
        _showSnackBar(
          vm.errorMessage ?? 'Ujian belum dimulai oleh pengawas.',
          AppColors.snackWarning,
        );

      case SubmitStatus.tokenInvalid:
        // Token salah — snackbar merah
        vm.resetSubmitStatus();
        _showSnackBar(
          vm.errorMessage ?? 'Token salah / ujian belum dibuka.',
          AppColors.snackError,
        );

      case SubmitStatus.networkError:
        // Error jaringan — snackbar oranye
        vm.resetSubmitStatus();
        _showSnackBar(
          vm.errorMessage ??
              'Tidak dapat terhubung ke server lokal. Periksa koneksi Wi-Fi ujian.',
          AppColors.snackInfo,
        );

      case SubmitStatus.rateLimited:
        // Rate limit 429 — snackbar merah
        vm.resetSubmitStatus();
        _showSnackBar(
          vm.errorMessage ?? 'Terlalu banyak percobaan. Tunggu 60 detik.',
          AppColors.snackError,
        );

      case SubmitStatus.idle:
      case SubmitStatus.loading:
        break;
    }
  }

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<LoginViewModel>();

    // -------------------------------------------------------------------------
    // OTA UPDATE GATE
    // Tampil jika versi aplikasi lebih rendah dari min_required_version server.
    // Siswa TIDAK dapat login sampai mengunduh dan menginstal versi terbaru.
    // -------------------------------------------------------------------------
    if (vm.isUpdateRequired) {
      return PopScope(
        canPop: false, // Blokir tombol kembali perangkat
        child: Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(24.0),
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 10),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.system_update_rounded,
                      size: 80,
                      color: Colors.blueAccent,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Pembaruan Wajib',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      vm.updateMessage,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () async {
                          final Uri url = Uri.parse(vm.apkDownloadUrl);
                          if (await canLaunchUrl(url)) {
                            await launchUrl(
                              url,
                              mode: LaunchMode.externalApplication,
                            );
                          }
                        },
                        child: const Text(
                          'Unduh Pembaruan Sekarang',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    // -------------------------------------------------------------------------
    // DEVICE BANNED GATE
    // Tampil jika perangkat memiliki flag pelanggaran permanen di storage.
    // Siswa TIDAK bisa masuk ujian sampai Pengawas memasukkan PIN yang benar.
    // -------------------------------------------------------------------------
    if (_violationCount >= 3) {
      return Scaffold(
        backgroundColor: Colors.red.shade800,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.gpp_bad_rounded,
                    color: Colors.white,
                    size: 90,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'PERANGKAT DIBLOKIR',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Perangkat ini tercatat pernah melakukan pelanggaran '
                    'selama sesi ujian.\n\n'
                    'Harap hubungi pengawas untuk membuka blokir.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.red.shade800,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(Icons.lock_open_rounded, size: 20),
                      label: const Text(
                        'Buka Blokir (PIN Pengawas)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      onPressed: () => _showBannedUnlockDialog(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // -------------------------------------------------------------------------
    // NORMAL LOGIN UI
    // -------------------------------------------------------------------------
    return Scaffold(
      backgroundColor: AppColors.background,
      // Pastikan tidak ada back button — PRD: TIDAK ada tombol back
      body: SafeArea(
        child: Consumer<LoginViewModel>(
          builder: (context, vm, _) {
            final isLoading = vm.submitStatus == SubmitStatus.loading;

            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // ----------------------------------------------------------
                    // LOGO SMAN 4 JEMBER — dibungkus GestureDetector (7-tap hidden)
                    // PRD Section 4.2: 7 tap dalam 3 detik → dialog PIN admin
                    // ----------------------------------------------------------
                    GestureDetector(
                      onTap: () {
                        final shouldShowDialog = vm.onLogoTap();
                        if (shouldShowDialog) {
                          // AdminPinDialog adalah StatefulWidget terpisah.
                          // Controller-nya di-dispose oleh Flutter SETELAH animasi
                          // dialog selesai — tidak ada lagi crash controller disposed.
                          showDialog<void>(
                            context: context,
                            barrierDismissible: true,
                            builder: (_) => const AdminPinDialog(),
                          );
                        }
                      },
                      child: SizedBox(
                        width: 110,
                        height: 110,
                        // decoration: BoxDecoration(
                        //   color: AppColors.surface,
                        //   borderRadius: BorderRadius.circular(22),
                        //   border: Border.all(
                        //     color: AppColors.border,
                        //     width: 1.5,
                        //   ),
                        // ),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Image.asset(
                            'assets/images/logo_smapa.png', // Ganti nama file ini sesuai dengan nama file logo Anda
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Nama sekolah
                    const Text(
                      'Sma Negeri 4 Jember',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 15,
                        letterSpacing: 1,
                      ),
                    ),

                    const SizedBox(height: 48),

                    // ----------------------------------------------------------
                    // LABEL
                    // ----------------------------------------------------------
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Token Ujian',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // ----------------------------------------------------------
                    // TEXT FIELD — Input token ujian
                    // PRD: hint "Masukkan Token Ujian", teks putih, border abu-abu
                    // ----------------------------------------------------------
                    TextField(
                      controller: _tokenController,
                      focusNode: _tokenFocusNode,
                      enabled: !isLoading,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        letterSpacing: 1.5,
                      ),
                      textAlign: TextAlign.center,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) =>
                          isLoading ? null : _handleSubmitToken(),
                      decoration: const InputDecoration(
                        hintText: 'Masukkan Token Ujian',
                        prefixIcon: Icon(
                          Icons.vpn_key_rounded,
                          color: AppColors.textHint,
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ----------------------------------------------------------
                    // TOMBOL "Mulai Ujian"
                    // PRD: ElevatedButton, warna biru, lebar penuh
                    // ----------------------------------------------------------
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : _handleSubmitToken,
                        child: isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: AppColors.textPrimary,
                                ),
                              )
                            : const Text(
                                'Mulai Ujian',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 40),

                    // Label versi — minimalis, tidak mencolok
                    const Text(
                      'SMABRO v1.0 — SMAN 4 Jember',
                      style: TextStyle(color: AppColors.textHint, fontSize: 11),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// =============================================================================
// ADMIN PIN DIALOG — Separate StatefulWidget
// =============================================================================
//
// Menggunakan StatefulWidget terpisah (bukan StatefulBuilder + async gap) agar:
//   1. _pinController di-manage oleh Flutter lifecycle (initState/dispose)
//   2. dispose() terjadi SETELAH animasi pop selesai — tidak ada crash
//      "TextEditingController used after being disposed"
//   3. setState() aman karena mounted check terintegrasi dengan lifecycle widget
//
// PRD KRITIS: Navigasi ke /admin HANYA terjadi jika verifyAdminPin() = true.
// DILARANG mengakses SharedPreferences atau ApiClient langsung dari widget ini.
// =============================================================================

/// Dialog input PIN admin — dipanggil setelah hidden gesture 7-tap terpicu.
class AdminPinDialog extends StatefulWidget {
  const AdminPinDialog({super.key});

  @override
  State<AdminPinDialog> createState() => _AdminPinDialogState();
}

class _AdminPinDialogState extends State<AdminPinDialog> {
  // ---------------------------------------------------------------------------
  // STATE
  // ---------------------------------------------------------------------------

  late final TextEditingController _pinController;
  bool _isVerifying = false;

  // ---------------------------------------------------------------------------
  // LIFECYCLE
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _pinController = TextEditingController();
  }

  @override
  void dispose() {
    // Flutter memanggil dispose() SETELAH animasi pop dialog selesai sepenuhnya.
    // Tidak ada async gap antara pop() dan dispose() yang bisa cause crash.
    _pinController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // METHODS
  // ---------------------------------------------------------------------------

  /// Memverifikasi PIN dan menangani navigasi / snackbar.
  /// PRD KRITIS: DILARANG log PIN plain text.
  Future<void> _handleVerify() async {
    if (_isVerifying) return;
    setState(() => _isVerifying = true);

    // Ekstrak navigator dan messenger sebelum async gap (safe context use)
    final vm = context.read<LoginViewModel>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    bool isValid = false;
    String? errorMsg;

    try {
      isValid = await vm.verifyAdminPin(_pinController.text);
    } catch (e) {
      errorMsg = 'Terjadi kesalahan: ${e.runtimeType}';
    }

    // mounted check wajib setelah setiap await
    if (!mounted) return;

    if (errorMsg != null) {
      // Exception: biarkan dialog tetap terbuka agar user bisa retry
      setState(() => _isVerifying = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text(errorMsg),
          backgroundColor: AppColors.snackError,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    if (isValid) {
      // PIN BENAR: pop dialog, lalu navigasi ke /admin
      // setState TIDAK dipanggil setelah pop agar tidak trigger rebuild
      // pada widget dalam proses unmount.
      navigator.pop();
      navigator.pushNamed(AppRoutes.admin);
    } else {
      // PIN SALAH: reset loading, tampilkan snackbar, dialog tetap terbuka
      setState(() => _isVerifying = false);
      messenger.showSnackBar(
        SnackBar(
          content: const Text('PIN salah.'),
          backgroundColor: AppColors.snackError,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: const Text(
        'Akses Admin',
        style: TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Masukkan PIN pengawas:',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _pinController,
            obscureText: true,
            keyboardType: TextInputType.number,
            autofocus: true,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: const InputDecoration(
              hintText: 'PIN Admin',
              prefixIcon: Icon(Icons.lock_outline, color: AppColors.textHint),
            ),
            onSubmitted: (_) => _handleVerify(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'Batal',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
        ElevatedButton(
          onPressed: _isVerifying ? null : _handleVerify,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            minimumSize: Size.zero,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          ),
          child: _isVerifying
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.textPrimary,
                  ),
                )
              : const Text('Masuk'),
        ),
      ],
    );
  }
}

// =============================================================================
// _LoginSupervisorPinDialog — Dedicated StatefulWidget untuk PIN Pengawas di LoginScreen
// =============================================================================
// Identik secara fungsional dengan _SupervisorPinDialog di exam_screen.dart.
// Dipisahkan karena keduanya berada di file yang berbeda (private class).
// =============================================================================
class _LoginSupervisorPinDialog extends StatefulWidget {
  const _LoginSupervisorPinDialog({
    required this.onSuccess,
    required this.onWrongPin,
  });

  final VoidCallback onSuccess;
  final VoidCallback onWrongPin;

  @override
  State<_LoginSupervisorPinDialog> createState() =>
      _LoginSupervisorPinDialogState();
}

class _LoginSupervisorPinDialogState extends State<_LoginSupervisorPinDialog> {
  late final TextEditingController _pin;
  bool _isPinVisible = false;
  bool _isVerifying = false;

  @override
  void initState() {
    super.initState();
    _pin = TextEditingController();
  }

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final pin = _pin.text.trim();
    if (pin.isEmpty || _isVerifying) return;

    setState(() => _isVerifying = true);

    final inputHash = CryptoHelper.hashPin(pin);
    final storedHash = LocalStorageService().getSupervisorPinHash();
    final isValid = storedHash != null && inputHash == storedHash;

    if (!mounted) return;
    setState(() => _isVerifying = false);

    if (isValid) {
      Navigator.of(context).pop();
      widget.onSuccess();
    } else {
      widget.onWrongPin();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: const Row(
        children: [
          Icon(
            Icons.admin_panel_settings_rounded,
            color: Colors.redAccent,
            size: 22,
          ),
          SizedBox(width: 8),
          Text(
            'Verifikasi Pengawas',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      content: TextField(
        controller: _pin,
        obscureText: !_isPinVisible,
        keyboardType: TextInputType.number,
        autofocus: true,
        onSubmitted: (_) => _verify(),
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'PIN Pengawas Ruangan',
          hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
          suffixIcon: IconButton(
            icon: Icon(
              _isPinVisible
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              color: Colors.white38,
              size: 20,
            ),
            onPressed: () => setState(() => _isPinVisible = !_isPinVisible),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal', style: TextStyle(color: Colors.white54)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.redAccent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: _isVerifying ? null : _verify,
          child: _isVerifying
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text(
                  'Verifikasi',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
        ),
      ],
    );
  }
}
