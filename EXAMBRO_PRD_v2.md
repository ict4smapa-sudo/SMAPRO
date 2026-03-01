# EXAMBRO_PRD_v2 (Product Requirements Document)
**Exambro SMAN 4 Jember System Audit & Reverse PRD**
*Dokumen State Terkini & Rekomendasi Arsitektur*

---

## 1. Project Overview & Objective

**Aplikasi Exambro SMAN 4 Jember** adalah *Mobile Exam Browser* yang dibangun menggunakan arsitektur modern (Flutter + Node.js Backend). Aplikasi ini berfungsi sebagai wrapper (kios mode) khusus dan aman untuk mengarahkan siswa menuju *LMS Moodle lokal* ujian tanpa celah kecurangan.

**Objektif Utama:** Memberikan lingkungan ujian digital (ujian CBT) yang *lockdown* dan tersentralisasi bagi siswa SMAN 4 Jember, memastikan integritas ujian dari percobaan penyontekan melalui perangkat gawai. 

**Arsitektur 'Satu Pintu' (Centralized Configuration):** 
Seluruh konfigurasi inti seperti *Moodle URL*, *Admin PIN*, dan *Exit PIN* dikendalikan penuh dari satu pintu (Database Backend SQLite lokal). Pendekatan ini memudahkan panitia ujian karena ketika ada perubahan alamat IP server CBT atau reset PIN pengawas, siswa tidak perlu memperbarui aplikasi di gawai mereka; konfigurasi langsung disinkronkan dan tersalurkan saat validasi token API.

---

## 2. Tech Stack & Architecture

### **Frontend (Mobile App)**
- **Framework:** Flutter SDK `^3.11.0`
- **State Management:** `provider ^6.1.1` (Arsitektur MVVM - Model View ViewModel diterapkan ketat untuk pemisahan logika dari antarmuka).
- **Library Kunci:**
  - `webview_flutter ^4.4.4` (Renderer utama Moodle secara fullscreen).
  - `wakelock_plus ^1.4.0` (Pengelola *screen state* — mencegah layar perangkat *sleep/doze* selama ujian).
  - `battery_plus ^6.0.3` (Indikator level dan status baterai di header ujian realtime).
  - `shared_preferences ^2.2.2` (Local storage untuk konfigurasi fallback: Server IP, Auth Token URL, & hash admin PIN).
  - `http ^1.1.0` (Modul komunikasi klien ke server).
  - `crypto ^3.0.3` (Hashing SHA-256 untuk keamanan transmisi/simpan PIN).

### **Backend (Local Server API)**
- **Runtime:** Node.js (via `app.js` entrypoint dan PM2 `ecosystem.config.js`).
- **Framework:** Express `^5.2.1`
- **Database:** `better-sqlite3` dengan SQLite `(WAL Mode)`.
- **Modul Tambahan:** `express-rate-limit ^8.2.1` (untuk proteksi brute force).

### **Alur Komunikasi (Data Flow & WebView Rendering)**
1. **Inisialisasi & Startup:** Flutter App membaca konfigurasi fallback dari `shared_preferences` pada Splash Screen.
2. **Validasi Token (API Gateway):** 
   * Siswa memasukkan Token di `LoginScreen`. Aplikasi mengirimkan POST request ke `/api/validate`.
   * Node.js mencocokkan di tabel `tokens`. Jika valid dan `exam_active=1`, backend membalas HTTP 200 beserta konfigurasi Moodle URL dan PIN admin & exit dari tabel `app_config`.
3. **Konfigurasi Lokal Sinkron:** Flutter App menyimpan Moodle URL dan PIN tersinkron ke `LocalStorageService` untuk mencegah putusnya sesi saat offline sesaat.
4. **Native Hardware Control:** Menghindari *dependency* eksternal yang rentan batas API, aplikasi memanggil platform channel `id.sman4jember.exambro/kiosk` untuk mengunci OS (*App Pinning* / Guided Access) dan OS diseting *Wakelock* sebelum transisi ke UI.
5. **WebView Render:** State berpindah ke `ExamScreen`. Controller Moodle WebView diload fullscreen memanggil URL Moodle yang diterima dari API. Interaksi WebView terkunci (pop-up diblokir, navigasi diintersep oleh `NavigationDelegate`).
6. **Session End & Strict Isolation:** Verifikasi *Exit PIN* via dialog memanggil POST `/api/verify-exit` (Validasi Live/Fallback hash lokal). Setelah *success*, aplikasi menghentikan Kiosk Mode, lalu menjalankan pembersihan 4 Lapis Penuh secara *await* (Cookies Moodle, HTTP Cache, LocalStorage Native, dan Storage JavaScript) untuk jaminan *zero-leak session* sebelum me-return siswa ke Login.

---

## 3. Core Features Breakdown (Frontend & Backend)

### **Backend Core Features**
- **Manajemen Token (CRUD):** Kemampuan mengelola akses siswa melalui tabel `tokens`. Validasi ini memeriksa integritas token beserta flag aktif `exam_active` untuk menentukan izin masuk siswa.
- **Konfigurasi Global (Satu Pintu):** Modul App Config di backend menyimpan URL Moodle (Target Server Exam), Admin PIN, dan Exit PIN secara tersentral. 
- **Custom Login Cookie Auth:** Sistem panel admin (`/admin`) dilindungi oleh otentikasi berbasis HTTP-Only cookies (`exambro_admin_auth`). Murni tanpa dependency tambahan layaknya JWT yang bersifat stateless, mempermudah revokasi akses.
- **Rate-limiter:** API membatasi akses klien secara adaptif (Maks 5 request per IP per menit) khusus di rute `/api/validate` untuk mitigasi serangan DDOS mini dari siswa.

### **Frontend Core Features**
- **Halaman Login Dinamis:** Memproses input token siswa dan menangani berbagai fallback status dari API (`successNavigate`, `examNotActive`, `tokenInvalid`, `networkError`, `rateLimited`) dan disajikan secara *user-friendly* via SnackBar.
- **Custom Header Ujian & Micro-State Management:** Menggantikan status bar native OS. Memiliki indikator jam *real-time*, status baterai presisi, dan kontrol navigasi. Melalui arsitektur *Micro-State* terkini, rebuild keseluruhan UI dicegah dengan pemanfaatan `ValueNotifier` dan `ValueListenableBuilder`. Ini memastikan hanya piksel teks jam dan baterai yang terre-paint setiap detiknya, menghemat drastis siklus CPU/RAM pada gawai *low-end*.
- **Graceful Error Handling:** Intersepsi kegagalan navigasi secara diam-diam. Jika Moodle Controller menembakkan error `-2` (DNS Down) atau `-6` (Server Mati), aplikasi memblokir UI *"Web Page not Available"* bawaan browser dan memberikan feedback elegan *"Koneksi terputus. Silakan tekan tombol Refresh"* berbentuk SnackBar.
- **Fallback Storage:** Jika terjadi *network drop* pada akses Live Server Verification, aplikasi secara pasif mendukung validasi PIN secara offline melalui pencocokan kriptografi lokal (*local hash verification*).

---

## 4. Security Implementations (The Fortress)

Aplikasi ini dipersenjatai dengan fitur *lockdown* dan mitigasi manipulasi yang terintegrasi di berbagai lapisan OS dan framework:

### **Native OS Security (Android & iOS)**
- **Native App Pinning (Android):** Kontrol `Kiosk Mode` diimplementasikan murni via jembatan panggilan Kotlin API terendah (`startLockTask()` & `stopLockTask()`) melalui channel `id.sman4jember.exambro/kiosk`. Siswa tidak bisa menekan tombol `Home`, `Recent`, atau `System Back` untuk mensuspend layar utama Moodle.
- **Guided Access Awareness (iOS):** Deteksi mode ujian perangkat Apple terintegrasi kuat ke dalam Swift `UIAccessibility.isGuidedAccessEnabled` MethodChannel. Siswa iOS diwajibkan menyalakan sakelar akses panduan sebelum layar merender server UNBK.
- **Screen Wakelock:** Modul yang bekerja sebagai wakil OS mencegah `Sleep`/`Doze` mode atau penggelapan layar. Ini krusial agar memori Chrome `WebView` tidak tertidur dan mengakibatkan terputusnya koneksi Web Socket ke *Node.js Backend* saat ada ujian esai panjang.
- **Anti-Screenshot / Screen Record:** Deklarasi *native protection* melalui pemanggilan fungsi Kotlin (`window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)`) pada siklus `onCreate` di `MainActivity.kt`. Hal ini mengamankan *preview app* dari mode *Recent Apps*, *Screen casting/Miracast*, maupun pengambilam *Screenshot* OS.
- **Cleartext Traffic Rule (Android):** Pengaktifan `usesCleartextTraffic="true"` untuk memastikan aplikasi dapat mengakses server sekolah secara lancar via HTTP murni (tanpa SSL) di jaringan *Intranet LAN* tertutup.

### **Flutter / Dart Application Security**
- **7-Tap Hidden Gesture (Admin Panel):** Perlindungan rute Admin App (bisa mengganti URL Moodle cadangan manual). Hanya bisa diakses apabila logo aplikasi SMAN 4 ditekan persis sebanyak 7 kali dalam tempo 3 detik.
- **Hashing SHA-256:** Sandi rahasia seperti PIN Admin dan Exit PIN masuk lewat `MD5/SHA-256 crypto` satu arah. Basis kode Flutter tidak mentoleransi penyimpanan dalam *plain text*.
- **Pembersihan Clipboard (Anti Copy-Paste):** Melalui kelas internal, perintah `Clipboard.setData(const ClipboardData(text: ''));` dieksekusi secara agresif saat membuka laman *Exam Screen* mencegah siswa menjiplak teks materi/jawaban via *copy-paste* eksternal.
- **WebView Lockdown Constraint:** Perilaku WebView sangat terestriksi; tidak adanya *URL address bar* maupun akses ke domain di luar *whitelist* Moodle LMS. Fungsi tombol kembali hardware (*back press*) dicegah secara langsung oleh widget `PopScope(canPop: false)`.

---

## 5. Phase 2 Roadmap (Future Enhancements)

Konfigurasi dan kapabilitas CBT saat ini sudah dinyatakan **Pre-Release State (Stable)**. Seluruh rekomendasi performa Fase 1 (Micro-State, Graceful Fallback, dan iOS Native Bridges) telah diakuisisi penuh di *codebase* utama.
Guna mematangkan daya saing platform dan meningkatkan manajemen terpusat panitia SMAN 4 Jember di masa depan, berikut rancangan 3 target arsitektur spesifik untuk "Iterasi Fase 2":

1. **Root & Jailbreak Detection (Native Integrity)**: 
   Pengecekan modifikasi OS level kerucut (*system/bin/su* pada Android dan Cydia injection pada iOS) yang dieksekusi secara asinkron di saat `SplashScreen`. Jika API `SafetyNet` OS mendapati gawai dimodifikasi, UI secara keras akan memberikan banner pemblokiran ujian permanen bagi perangkat yang tidak valid.

2. **Network State Observer (Real-time Background Telemetry)**: 
   Siswa terkadang gagal unggah lembaran esai akibat Wi-Fi lokal putus. Implementasi observer latensi `connectivity_plus` di latar belakang Flutter, memunculkan "Header Banner Real-Time" apabila latensi ke server Exambro lokal (ICMP Ping Drop) menembus ambang batas (contoh: di atas 2000ms).

3. **Force Update OTA (Over-The-Air) Mechanism**: 
   Mekanisme penegakan homogenitas rilis APK. Backend Express.js dikonfigurasi untuk mengekspos endpoint rute `/api/version`. Login Screen akan mengonsumsi titik ini untuk mengecek parameter `min_required_version`. Apabila nilai v-app tertinggal, aplikasi akan membekukan UI Login secara imperatif dan memaksa siswa menekan *link* unduhan versi terbaru langsung tanpa harus membongkar-pasang aplikasi via manual admin.

---
**Prepared By:** Lead System Architect (AI Assistant)
**Dikeluarkan:** 01 Maret 2026 (Pre-Release Version)
