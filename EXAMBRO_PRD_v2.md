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
4. **WebView Render:** State berpindah ke `ExamScreen`. Controller Moodle WebView diload fullscreen memanggil URL Moodle yang diterima dari API. Interaksi WebView terkunci (pop-up diblokir, navigasi diintersep oleh `NavigationDelegate`).
5. **Session End:** Verifikasi *Exit PIN* via dialog memanggil POST `/api/verify-exit` (Validasi Live/Fallback hash lokal) yang kemudian me-reset cookie, clear clipboard cache, dan me-return siswa ke Login.

---

## 3. Core Features Breakdown (Frontend & Backend)

### **Backend Core Features**
- **Manajemen Token (CRUD):** Kemampuan mengelola akses siswa melalui tabel `tokens`. Validasi ini memeriksa integritas token beserta flag aktif `exam_active` untuk menentukan izin masuk siswa.
- **Konfigurasi Global (Satu Pintu):** Modul App Config di backend menyimpan URL Moodle (Target Server Exam), Admin PIN, dan Exit PIN secara tersentral. 
- **Custom Login Cookie Auth:** Sistem panel admin (`/admin`) dilindungi oleh otentikasi berbasis HTTP-Only cookies (`exambro_admin_auth`). Murni tanpa dependency tambahan layaknya JWT yang bersifat stateless, mempermudah revokasi akses.
- **Rate-limiter:** API membatasi akses klien secara adaptif (Maks 5 request per IP per menit) khusus di rute `/api/validate` untuk mitigasi serangan DDOS mini dari siswa.

### **Frontend Core Features**
- **Halaman Login Dinamis:** Memproses input token siswa dan menangani berbagai fallback status dari API (`successNavigate`, `examNotActive`, `tokenInvalid`, `networkError`, `rateLimited`) dan disajikan secara *user-friendly* via SnackBar.
- **Custom Header Ujian:** Menggantikan status bar native OS. Memiliki indikator jam *real-time*, status baterai presisi, kontrol relasi navigasi (Back, Forward, Refresh WebView), serta pemicu dialog keluar. Dibangun di dalam `ExamHeaderBar` (Stateful Widget) independen agar *reboot/re-render* waktu tidak men-trigger build ulang Moodle WebView yang berat.
- **Fallback Storage:** Jika terjadi *network drop* pada akses Live Server Verification, aplikasi secara pasif mendukung validasi PIN secara offline melalui pencocokan kriptografi lokal (*local hash verification*).

---

## 4. Security Implementations (The Fortress)

Aplikasi ini dipersenjatai dengan fitur *lockdown* dan mitigasi manipulasi yang terintegrasi di berbagai lapisan OS dan framework:

### **Native Android Security**
- **Anti-Split Screen:** Memanfaatkan flag di `AndroidManifest.xml` (`android:resizeableActivity="false"`). Siswa dilarang keras membuka aplikasi contekan pendamping di sebelah *screen* ujian.
- **Anti-Screenshot / Screen Record:** Deklarasi *native protection* melalui pemanggilan fungsi Kotlin (`window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)`) pada siklus `onCreate` di `MainActivity.kt`. Hal ini mengamankan *preview app* dari mode *Recent Apps*, *Screen casting/Miracast*, maupun pengambilam *Screenshot* OS.
- **Cleartext Traffic Rule:** Pengaktifan `usesCleartextTraffic="true"` untuk memastikan aplikasi dapat mengakses server sekolah secara lancar via HTTP murni (tanpa SSL) di jaringan *Intranet LAN* tertutup.

### **Flutter / Dart Application Security**
- **7-Tap Hidden Gesture (Admin Panel):** Perlindungan rute Admin App (bisa mengganti URL Moodle cadangan manual). Hanya bisa diakses apabila logo aplikasi SMAN 4 ditekan persis sebanyak 7 kali dalam tempo 3 detik.
- **Hashing SHA-256:** Sandi rahasia seperti PIN Admin dan Exit PIN masuk lewat `MD5/SHA-256 crypto` satu arah. Basis kode Flutter tidak mentoleransi penyimpanan dalam *plain text*.
- **Pembersihan Clipboard (Anti Copy-Paste):** Melalui kelas internal, perintah `Clipboard.setData(const ClipboardData(text: ''));` dieksekusi secara agresif saat membuka laman *Exam Screen* mencegah siswa menjiplak teks materi/jawaban via *copy-paste* eksternal.
- **WebView Lockdown Constraint:** Perilaku WebView sangat terestriksi; tidak adanya *URL address bar* maupun akses ke domain di luar *whitelist* Moodle LMS. Fungsi tombol kembali hardware (*back press*) dicegah secara langsung oleh widget `PopScope(canPop: false)`.

---

## 5. System Audit & Optimization Recommendations

Setelah melakukan pemeriksaan *code review* mendalam terhadap *state* dan arsitektur aplikasi (versi 2.0.0+1), berikut adalah rekomendasi tajam guna eskalasi performa dan tata kelola memori:

### **Rekomendasi Optimasi di Sisi Flutter (Dart)**
1. **Efisiensi Rebuild UI (Pemisahan State Notifier di level micro):** 
   Meskipun Timer jam dan baterai sudah diekstrak ke dalam widget `ExamHeaderBar`, penggunaan state lokal dinamis via `setState` setiap 30 detik tetap merender ulang keseluruhan header navigation button. **Saran:** Gunakan `ValueNotifier<String>` (untuk Waktu) dan `ValueNotifier<int>` (untuk level Baterai). Sisipkan `ValueListenableBuilder` khusus hanya pada elemen Text saja, menurunkan durasi *paint UI tree* secara drastis saat ujian berjalan.
2. **Manajemen Memori Reclaimer WebView (OOM Prevention):** 
   Memuat *instance LMS Moodle* dengan ragam aset (image, JS, form soal) di gawai low-end bisa memicu *Out of Memory (OOM)*. **Saran:** Terapkan pembersihan chache manual di `ExamViewModel`. Lakukan injeksi metode `WebViewController.clearCache()` jika sensor internal Flutter mendeteksi respon sistem OS yang tertahan, mengurangi insiden *app forces closes* di pertengahan ujian.
3. **Pengelolaan Isolasi Dart (Connection Keep-Alive Pooling):** 
   Klien Flutter saat ini memutus paksa koneksi (teardown) ke IP Node.js lokal setelah hit `/api/validate`. **Saran:** Pada paket `http`, pergunakan `http.Client()` berbasis *Connection Pooling* singleton persisten untuk menekan beban overhead *TCP Handshake* yang repetitif bila 800 gawai siswa online di titik hotspot yang sama secara simultan.

### **Rekomendasi Optimasi di Sisi Native (Kotlin / Android)**
1. **Pengelolaan Daur Hidup Memori WebView (Native Suspension):** 
   Render Engine Chromium bawaan Android bisa membebani RAM walau aplikasi berada dalam status pasif (*on-stop/backgrounded* akibat ada notifikasi atau panggilan sistem prioritas). **Saran:** Override fungsi siklus hidup `onPause()` dan `onResume()` di `MainActivity.kt`. Saat gawai diminimize, inisiasikan injeksi interupsi native: `webView.onPause()` dan `webView.pauseTimers()`, lalu lanjutkan via `webView.resumeTimers()` saat kembali ke UI aktif. Ini akan mendinginkan CPU (battery friendly) dan membekukan proses JS engine di belakang layar.
2. **Efisiensi Battery Broadcast Receiver Native:**
   Plugin `battery_plus` meregistrasikan sensor melalui native Android *BroadcastReceiver* untuk melacak sisa waktu energi. Sensor ini secara persisten akan di *trigger* setiap berubah persen walau tidak tertampil. **Saran:** Kurangi tingkat *polling* sensor pada Native layer. Alih-alih merespons *realtime percentage trigger*, OS cukup diberitahu sinkronisasi hanya jika perubahan menembus varian 5% delta (`ACTION_BATTERY_CHANGED` difilter) - mengefektifkan radio receiver perangkat.

---
**Prepared By:** Senior System Architect (AI Assistant)
**Dikeluarkan:** 01 Maret 2026 (Update Revisi V2)
