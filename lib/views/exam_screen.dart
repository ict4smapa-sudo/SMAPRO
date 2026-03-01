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

import '../services/local_storage_service.dart';
import '../utils/colors.dart';
import '../utils/crypto_helper.dart';
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

class _ExamScreenState extends State<ExamScreen> with WidgetsBindingObserver {
  // Flag untuk menghindari snackbar duplikat
  bool _snackBarShowing = false;

  // Hitungan pelanggaran dari 3-Strike Policy.
  // 0 = bersih, 1-2 = peringatan, >=3 = layar merah/banned.
  int _violationCount = 0;

  // Guard / debounce flag untuk mencegah double-counting.
  // true saat pelanggaran sudah dicatat dalam satu siklus inactive→paused;
  // di-reset ke false saat resumed (kembali ke ujian).
  bool _isHandlingViolation = false;

  // ---------------------------------------------------------------------------
  // LIFECYCLE
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    // Daftarkan observer untuk memantau lifecycle app (Violation Trap)
    WidgetsBinding.instance.addObserver(this);
    // Immersive Mode: sembunyikan StatusBar & NavigationBar.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    // Wakelock: cegah layar mati selama sesi ujian berlangsung.
    WakelockPlus.enable();
    // Anti-Copy-Paste: kosongkan clipboard saat layar ujian dibuka.
    Clipboard.setData(const ClipboardData(text: ''));
    // Persistent Violation: baca counter dari storage (synchronous).
    // Jika siswa sudah pernah melanggar sebelum force-close, count terbaca.
    _violationCount = LocalStorageService().getViolationCount();
    // Native Overlay Blocker — daftarkan listener untuk sinyal onWindowFocusLost
    // yang dikirim oleh MainActivity.onWindowFocusChanged saat Floating App
    // merebut fokus tanpa mengubah AppLifecycleState ke paused/inactive.
    const MethodChannel('id.sman4jember.exambro/kiosk').setMethodCallHandler((
      call,
    ) async {
      debugPrint(
        'EXAMBRO_DEBUG: Flutter menerima sinyal Native -> ${call.method}',
      );
      if (call.method == 'onWindowFocusLost') {
        _triggerViolationEvent();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ExamViewModel>().initWebView();
    });
  }

  @override
  void dispose() {
    // Lepaskan observer lifecycle saat keluar.
    WidgetsBinding.instance.removeObserver(this);
    // Kembalikan UI OS ke normal (edge-to-edge) saat ExamScreen di-unmount.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    WakelockPlus.disable();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // VIOLATION TRAP — Lifecycle Observer
  // ---------------------------------------------------------------------------

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint('EXAMBRO_DEBUG: Flutter AppLifecycle berubah menjadi -> $state');
    // Jaring diperluas: tangkap paused (keluar app) DAN inactive
    // (Floating Apps, Split Screen, status bar ditarik, telepon masuk).
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _triggerViolationEvent();
    } else if (state == AppLifecycleState.resumed) {
      // Siswa kembali fokus ke ujian → buka kunci debounce
      _isHandlingViolation = false;

      // Baca count terbaru dari storage (sync, _prefs sudah init).
      final count = LocalStorageService().getViolationCount();
      if (mounted) {
        setState(() => _violationCount = count);
        // Strike 1 & 2 → dialog peringatan; Strike 3 → build gate layar merah.
        if (count == 1 || count == 2) {
          _showWarningDialog(count);
        }
      }
    }
  }

  // ---------------------------------------------------------------------------
  // UI HELPERS — Violation Unlock Dialog
  // ---------------------------------------------------------------------------

  /// Menampilkan [_SupervisorPinDialog] untuk membuka blokir Violation Trap.
  /// Controller lifecycle dikelola sepenuhnya oleh widget dialog — tidak ada
  /// controller yang dibuat atau di-dispose di sini (mencegah crash).
  void _showViolationUnlockDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _SupervisorPinDialog(
        onSuccess: () async {
          // 1. Reset counter ke 0 di persistent storage
          await LocalStorageService().resetViolationCount();
          if (!mounted) return;
          // 2. Reset in-memory counter → rebuild ke UI ujian normal
          setState(() => _violationCount = 0);
          // 3. Aktifkan kembali Immersive Mode
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
        },
        onWrongPin: () =>
            _showSnackBar('PIN salah. Hubungi pengawas.', AppColors.snackError),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // UI HELPERS — Violation Event Trigger (Modular)
  // ---------------------------------------------------------------------------

  /// Satu titik masuk untuk semua sumber pelanggaran:
  ///   — AppLifecycleState.paused / inactive (didChangeAppLifecycleState)
  ///   — onWindowFocusLost dari native Kotlin (Floating Apps tak terdeteksi lifecycle)
  ///
  /// [_isHandlingViolation] bertindak sebagai debounce — mencegah double-count
  /// saat dua sumber menembak secara bersamaan (mis. inactive lalu paused).
  void _triggerViolationEvent() {
    debugPrint(
      'EXAMBRO_DEBUG: _triggerViolationEvent dieksekusi! Count: $_violationCount, isHandling: $_isHandlingViolation',
    );
    if (!mounted || _violationCount >= 3 || _isHandlingViolation) return;
    _isHandlingViolation = true;
    LocalStorageService().incrementViolationCount();
    // Baca nilai terbaru setelah increment (sync — _prefs sudah di-write).
    final count = LocalStorageService().getViolationCount();
    // Guard kedua: cegah setState jika widget sudah dispose saat native channel
    // menembak sinyal di tengah transisi navigasi.
    if (!mounted) return;
    setState(() => _violationCount = count);
    if (count < 3) {
      _showWarningDialog(count);
    }
    // Jika count == 3, build() akan otomatis render layar merah via setState.
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
  // UI HELPERS — Warning Dialog (Peringatan Ke-1 & Ke-2)
  // ---------------------------------------------------------------------------

  /// Menampilkan dialog peringatan keras saat pelanggaran ke-1 dan ke-2.
  /// Dialog tidak bisa di-dismiss dengan mengetuk area luar (barrierDismissible: false).
  /// Pelanggaran ke-3 menampilkan layar merah penuh — tidak melalui fungsi ini.
  void _showWarningDialog(int count) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text(
          'PERINGATAN KECURANGAN!',
          style: TextStyle(
            color: Colors.redAccent,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        content: Text(
          'Anda terdeteksi keluar dari layar ujian.\n\n'
          'Pelanggaran ke: $count dari maksimal 3.\n\n'
          'Jika mencapai 3 kali, ujian Anda akan DIBLOKIR permanen!',
          style: const TextStyle(color: Colors.white70, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'SAYA MENGERTI',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    // -------------------------------------------------------------------------
    // VIOLATION TRAP UI — Sistem Tilang (3-Strike Policy)
    // Tampil saat _violationCount mencapai 3. Layar ini TIDAK bisa di-dismiss
    // tanpa PIN Pengawas yang benar (Supervisor PIN).
    // -------------------------------------------------------------------------
    if (_violationCount >= 3) {
      return PopScope(
        canPop: false,
        child: Scaffold(
          backgroundColor: Colors.red.shade800,
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.warning_rounded,
                      color: Colors.white,
                      size: 80,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'PELANGGARAN TERDETEKSI!',
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
                      'Anda telah keluar dari aplikasi atau mematikan '
                      'layar saat ujian berlangsung.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
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
                          'Buka Blokir (Butuh PIN Pengawas)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        onPressed: () => _showViolationUnlockDialog(context),
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
    // NORMAL EXAM UI
    // -------------------------------------------------------------------------
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

// =============================================================================
// _SupervisorPinDialog — Dedicated StatefulWidget untuk PIN Pengawas
// =============================================================================
//
// Alasan pemisahan ke StatefulWidget tersendiri:
// Mengelola TextEditingController di dalam StatefulWidget memastikan
// controller di-dispose HANYA oleh Flutter framework (di dispose()), bukan
// secara manual di dalam async callback — mencegah crash:
// "TextEditingController was used after being disposed".
//
// Menerima dua callback:
//   [onSuccess]  → dipanggil oleh parent setelah Navigator.pop();
//   [onWrongPin] → dipanggil untuk menampilkan SnackBar error.
// =============================================================================
class _SupervisorPinDialog extends StatefulWidget {
  const _SupervisorPinDialog({
    required this.onSuccess,
    required this.onWrongPin,
  });

  /// Dipanggil di parent setelah dialog di-pop (PIN benar).
  final VoidCallback onSuccess;

  /// Dipanggil di parent saat PIN salah (untuk SnackBar).
  final VoidCallback onWrongPin;

  @override
  State<_SupervisorPinDialog> createState() => _SupervisorPinDialogState();
}

class _SupervisorPinDialogState extends State<_SupervisorPinDialog> {
  // Controller dan FocusNode diinisialisasi di sini — bukan di luar dialog.
  // Flutter memanggil dispose() saat widget di-unmount, tanpa ambiguitas.
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

    // Verifikasi: bandingkan hash input dengan Supervisor PIN hash di storage.
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
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: const Row(
        children: [
          Icon(Icons.shield_outlined, color: AppColors.snackError, size: 22),
          SizedBox(width: 8),
          Text(
            'Verifikasi Pengawas',
            style: TextStyle(
              color: AppColors.textPrimary,
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
        style: const TextStyle(color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: 'PIN Pengawas Ruangan',
          hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 14),
          suffixIcon: IconButton(
            icon: Icon(
              _isPinVisible
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              color: AppColors.textHint,
              size: 20,
            ),
            onPressed: () => setState(() => _isPinVisible = !_isPinVisible),
          ),
        ),
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
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.snackError,
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
