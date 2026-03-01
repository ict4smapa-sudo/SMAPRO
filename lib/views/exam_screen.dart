// =============================================================================
// File        : exam_screen.dart
// Fungsi Utama: Halaman ujian fullscreen (route: '/exam').
//               WebView Moodle tanpa AppBar/NavigationBar.
//               FAB exit di pojok kanan bawah — verifikasi PIN SHA-256.
// Tanggal     : 27 Februari 2026
// PRD Section : Section 4.4
// MVVM RULE   : Semua logika business ada di ExamViewModel.
//               DILARANG mengakses WebViewController langsung tanpa ViewModel.
// BATASAN P6  : FLAG_SECURE & kiosk_mode → Prioritas 8.
//               iOS Guided Access           → Prioritas 9.
// =============================================================================

import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../utils/colors.dart';
import '../utils/routes.dart';
import '../viewmodels/exam_viewmodel.dart';
import '../viewmodels/login_viewmodel.dart';

/// Exam Screen — mode ujian fullscreen.
///
/// Satu-satunya cara keluar adalah melalui FAB exit → verifikasi PIN admin.
/// Navigasi di WebView dibatasi oleh NavigationDelegate di ExamViewModel.
class ExamScreen extends StatefulWidget {
  const ExamScreen({super.key});

  @override
  State<ExamScreen> createState() => _ExamScreenState();
}

class _ExamScreenState extends State<ExamScreen> {
  // Flag untuk menghindari snackbar duplikat
  bool _snackBarShowing = false;

  // ---------------------------------------------------------------------------
  // LIFECYCLE
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    // Wakelock: cegah layar mati selama sesi ujian berlangsung.
    WakelockPlus.enable();
    // Anti-Copy-Paste: kosongkan clipboard saat layar ujian dibuka.
    // Mencegah siswa mempaste teks dari luar aplikasi ke dalam WebView.
    Clipboard.setData(const ClipboardData(text: ''));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ExamViewModel>().initWebView();
    });
  }

  @override
  void dispose() {
    // Kembalikan pengaturan layar ke normal saat ExamScreen di-unmount.
    // Dipanggil baik saat exit normal (PIN) maupun edge-case teardown.
    WakelockPlus.disable();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // UI HELPERS — SnackBar
  // ---------------------------------------------------------------------------

  void _showSnackBar(String message, Color backgroundColor) {
    if (!mounted || _snackBarShowing) return;
    _snackBarShowing = true;
    ScaffoldMessenger.of(context)
        .showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: backgroundColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            duration: const Duration(seconds: 3),
          ),
        )
        .closed
        .then((_) => _snackBarShowing = false);
  }

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // PRD: Tombol back hardware Android TIDAK boleh keluar dari Exam Screen
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.background,

        // TIDAK ada AppBar — fullscreen
        // TIDAK ada BottomNavigationBar
        body: Consumer<ExamViewModel>(
          builder: (context, vm, _) {
            // ------------------------------------------------------------------
            // Reaksi terhadap blockedMessage (navigasi diblokir)
            // ------------------------------------------------------------------
            if (vm.blockedMessage != null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _showSnackBar(vm.blockedMessage!, AppColors.snackError);
                vm.clearBlockedMessage();
              });
            }

            // ------------------------------------------------------------------
            // State: konfigurasi belum ada
            // ------------------------------------------------------------------
            if (vm.state == ExamViewState.configMissing) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        color: AppColors.snackError,
                        size: 56,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Konfigurasi server belum ada.\nHubungi pengawas.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            // ------------------------------------------------------------------
            // State: guidedAccessRequired (iOS saja)
            // DILARANG load WebView jika Guided Access belum aktif.
            // ------------------------------------------------------------------
            if (vm.state == ExamViewState.guidedAccessRequired) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 24,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.warning_rounded,
                        color: AppColors.snackError,
                        size: 64,
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Guided Access Belum Aktif!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Akses ujian ditolak.\n\n'
                        'Buka Settings → Accessibility → Guided Access '
                        'di iPhone/iPad Anda, lalu aktifkan dengan '
                        'Triple-Click tombol Power/Home.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Tombol Cek Ulang — reset ke initial lalu coba initWebView lagi
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            // Reset state ke initial agar initWebView bisa berjalan ulang
                            vm.reset().then((_) => vm.initWebView());
                          },
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text(
                            'Cek Ulang',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Tombol Kembali — keluar ke LoginScreen tanpa verifikasi PIN
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(
                              context,
                            ).pushReplacementNamed(AppRoutes.login);
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textSecondary,
                            side: const BorderSide(color: AppColors.border),
                          ),
                          icon: const Icon(Icons.arrow_back_rounded, size: 18),
                          label: const Text('Kembali ke Login'),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            // ------------------------------------------------------------------
            // State: loading (belum controller siap)
            // ------------------------------------------------------------------
            if (vm.state == ExamViewState.initial ||
                vm.state == ExamViewState.loading) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.accent,
                      ),
                      strokeWidth: 2.5,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Menghubungkan ke server ujian...',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              );
            }

            // ------------------------------------------------------------------
            // State: ready — tampilkan Header + WebView
            // ------------------------------------------------------------------
            return SafeArea(
              child: Column(
                children: [
                  ExamHeaderBar(
                    controller: vm.webViewController,
                    onExitPressed: () => showDialog<void>(
                      context: context,
                      barrierDismissible: false,
                      builder: (_) => const ExitPinDialog(),
                    ),
                  ),
                  Expanded(
                    child: WebViewWidget(controller: vm.webViewController!),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// =============================================================================
// EXAM HEADER BAR — Custom Header (Navigasi, Jam, Baterai, Keluar)
// =============================================================================
//
// StatefulWidget terpisah agar Timer & Battery stream tidak memicu rebuild
// pada WebView (Expanded child) — hanya ExamHeaderBar yang re-render.
// =============================================================================

/// Header bar ujian: Navigasi WebView (kiri), Jam + Baterai (tengah), Keluar (kanan).
class ExamHeaderBar extends StatefulWidget {
  const ExamHeaderBar({
    super.key,
    required this.controller,
    required this.onExitPressed,
  });

  final WebViewController? controller;
  final VoidCallback onExitPressed;

  @override
  State<ExamHeaderBar> createState() => _ExamHeaderBarState();
}

class _ExamHeaderBarState extends State<ExamHeaderBar> {
  // ---------------------------------------------------------------------------
  // STATE — Jam & Baterai
  // ---------------------------------------------------------------------------

  final Battery _battery = Battery();
  final ValueNotifier<String> _currentTime = ValueNotifier<String>('');
  final ValueNotifier<int> _batteryLevel = ValueNotifier<int>(100);
  BatteryState _batteryState = BatteryState.full;
  Timer? _timer;
  StreamSubscription<BatteryState>? _batterySub;

  // ---------------------------------------------------------------------------
  // LIFECYCLE
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _currentTime.value = _formatTime(DateTime.now());
    _updateBattery();

    // Update jam setiap 30 detik — tidak ada setState, hanya update value
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      _currentTime.value = _formatTime(DateTime.now());
    });

    // Subscribe ke perubahan status baterai — tidak ada setState
    _batterySub = _battery.onBatteryStateChanged.listen((state) {
      _batteryState = state;
      _updateBattery();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _batterySub?.cancel();
    _currentTime.dispose();
    _batteryLevel.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // HELPERS
  // ---------------------------------------------------------------------------

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Future<void> _updateBattery() async {
    try {
      final level = await _battery.batteryLevel;
      _batteryLevel.value = level;
    } catch (_) {
      // Abaikan error pada emulator (tidak punya baterai fisik)
    }
  }

  IconData _batteryIcon(int level) {
    if (_batteryState == BatteryState.charging ||
        _batteryState == BatteryState.connectedNotCharging) {
      return Icons.battery_charging_full_rounded;
    }
    if (level >= 90) return Icons.battery_full_rounded;
    if (level >= 60) return Icons.battery_5_bar_rounded;
    if (level >= 40) return Icons.battery_4_bar_rounded;
    if (level >= 20) return Icons.battery_2_bar_rounded;
    return Icons.battery_1_bar_rounded;
  }

  Color _batteryColor(int level) {
    if (_batteryState == BatteryState.charging) return Colors.greenAccent;
    if (level <= 15) return AppColors.snackError;
    if (level <= 30) return Colors.orange;
    return AppColors.textSecondary;
  }

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(60),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // ── KIRI: Navigasi WebView ─────────────────────────────────────────
          _NavButton(
            icon: Icons.arrow_back_ios_new_rounded,
            tooltip: 'Kembali',
            onPressed: () => widget.controller?.goBack(),
          ),
          _NavButton(
            icon: Icons.arrow_forward_ios_rounded,
            tooltip: 'Maju',
            onPressed: () => widget.controller?.goForward(),
          ),
          _NavButton(
            icon: Icons.refresh_rounded,
            tooltip: 'Muat Ulang',
            onPressed: () => widget.controller?.reload(),
          ),

          // ── TENGAH: Jam + Baterai ──────────────────────────────────────────
          // Hanya komponen teks jam & angka baterai yang rebuild (bukan seluruh Row).
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Hanya widget Text jam yang di-rebuild oleh ValueNotifier jam
                ValueListenableBuilder<String>(
                  valueListenable: _currentTime,
                  builder: (context, timeString, child) {
                    return Text(
                      timeString,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    );
                  },
                ),
                const SizedBox(width: 14),
                // Hanya Icon + Text baterai yang di-rebuild oleh ValueNotifier level
                ValueListenableBuilder<int>(
                  valueListenable: _batteryLevel,
                  builder: (context, level, child) {
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _batteryIcon(level),
                          color: _batteryColor(level),
                          size: 18,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$level%',
                          style: TextStyle(
                            color: _batteryColor(level),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),

          // ── KANAN: Tombol Keluar ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              onPressed: widget.onExitPressed,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.snackError,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: const BorderSide(color: AppColors.snackError, width: 1),
                ),
              ),
              icon: const Icon(Icons.logout_rounded, size: 16),
              label: const Text(
                'Keluar',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// IconButton navigasi WebView (Back, Forward, Reload) — reusable private widget.
class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 20, color: AppColors.textSecondary),
      tooltip: tooltip,
      onPressed: onPressed,
      splashRadius: 20,
    );
  }
}

// =============================================================================
// EXIT PIN DIALOG — Separate StatefulWidget
// =============================================================================
//
// Menggunakan StatefulWidget terpisah (bukan StatefulBuilder + async gap) agar:
//   1. _pinController di-manage Flutter lifecycle (initState/dispose)
//   2. dispose() dipanggil SETELAH animasi pop dialog selesai sepenuhnya.
//      "TextEditingController was used after being disposed"
//   3. setState() aman karena mounted check terintegrasi dengan lifecycle
//
// PRD KRITIS: Navigasi ke /login HANYA jika verifyAdminPin() = true.
//             await examVm.reset() WAJIB sebelum pushReplacementNamed.
// =============================================================================

/// Dialog verifikasi PIN admin untuk keluar dari sesi ujian.
///
/// barrierDismissible: false — siswa tidak bisa men-dismiss dialog ini
/// tanpa memasukkan PIN yang benar atau menekan Batal.
class ExitPinDialog extends StatefulWidget {
  const ExitPinDialog({super.key});

  @override
  State<ExitPinDialog> createState() => _ExitPinDialogState();
}

class _ExitPinDialogState extends State<ExitPinDialog> {
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
    // Tidak ada async gap antara pop() dan dispose() — tidak ada crash.
    _pinController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // METHODS
  // ---------------------------------------------------------------------------

  /// Verifikasi PIN dan tangani navigasi / snackbar.
  /// PRD KRITIS: DILARANG log PIN plain text.
  Future<void> _handleVerify() async {
    if (_isVerifying) return;
    setState(() => _isVerifying = true);

    // Ekstrak referensi SEBELUM async gap — safe context use
    final loginVm = context.read<LoginViewModel>();
    final examVm = context.read<ExamViewModel>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    bool isValid = false;
    String? errorMsg;

    try {
      isValid = await loginVm.verifyExitPin(_pinController.text);
    } catch (e) {
      errorMsg = 'Terjadi kesalahan: ${e.runtimeType}';
    }

    // mounted check wajib setelah setiap await
    if (!mounted) return;

    if (errorMsg != null) {
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
      // PIN BENAR: pop dialog terlebih dahulu, lalu reset sesi, lalu navigasi.
      // setState TIDAK dipanggil setelah pop agar tidak trigger rebuild pada
      // widget yang sedang dalam proses unmount.
      navigator.pop();

      // Session Isolation — WAJIB await sebelum navigate.
      // Menjamin cookies/cache/JS storage WebView terhapus sebelum LoginScreen dibuat.
      await examVm.reset();

      // pushReplacementNamed — siswa tidak bisa menekan back kembali ke ExamScreen
      navigator.pushReplacementNamed(AppRoutes.login);
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
      title: const Row(
        children: [
          Icon(
            Icons.exit_to_app_rounded,
            color: AppColors.snackWarning,
            size: 22,
          ),
          SizedBox(width: 8),
          Text(
            'Keluar Ujian',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      // SingleChildScrollView mencegah RenderFlex overflow saat keyboard muncul
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Masukkan PIN pengawas untuk mengakhiri ujian:',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
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
      ),
      actions: [
        TextButton(
          onPressed: _isVerifying ? null : () => Navigator.of(context).pop(),
          child: const Text(
            'Batal',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
        ElevatedButton(
          onPressed: _isVerifying ? null : _handleVerify,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.snackError,
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
              : const Text('Keluar Ujian'),
        ),
      ],
    );
  }
}
