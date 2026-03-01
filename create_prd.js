const {
  Document, Packer, Paragraph, TextRun, Table, TableRow, TableCell,
  HeadingLevel, AlignmentType, BorderStyle, WidthType, ShadingType,
  LevelFormat, PageNumber, PageBreak, Header, Footer, Tab
} = require('docx');
const fs = require('fs');

const borderThin = { style: BorderStyle.SINGLE, size: 1, color: "CCCCCC" };
const borders = { top: borderThin, bottom: borderThin, left: borderThin, right: borderThin };
const headerBorder = { style: BorderStyle.SINGLE, size: 2, color: "1A56C4" };
const headerBorders = { top: headerBorder, bottom: headerBorder, left: headerBorder, right: headerBorder };

function h1(text) {
  return new Paragraph({
    heading: HeadingLevel.HEADING_1,
    spacing: { before: 400, after: 200 },
    children: [new TextRun({ text, bold: true, size: 36, color: "1A56C4", font: "Arial" })]
  });
}
function h2(text) {
  return new Paragraph({
    heading: HeadingLevel.HEADING_2,
    spacing: { before: 280, after: 120 },
    children: [new TextRun({ text, bold: true, size: 28, color: "1A56C4", font: "Arial" })]
  });
}
function h3(text) {
  return new Paragraph({
    heading: HeadingLevel.HEADING_3,
    spacing: { before: 200, after: 100 },
    children: [new TextRun({ text, bold: true, size: 24, color: "2E4A8C", font: "Arial" })]
  });
}
function p(text, opts = {}) {
  return new Paragraph({
    spacing: { before: 80, after: 80 },
    children: [new TextRun({ text, font: "Arial", size: 22, ...opts })]
  });
}
function bullet(text, level = 0) {
  return new Paragraph({
    numbering: { reference: "bullets", level },
    spacing: { before: 60, after: 60 },
    children: [new TextRun({ text, font: "Arial", size: 22 })]
  });
}
function numbered(text, level = 0) {
  return new Paragraph({
    numbering: { reference: "numbers", level },
    spacing: { before: 60, after: 60 },
    children: [new TextRun({ text, font: "Arial", size: 22 })]
  });
}
function code(text) {
  return new Paragraph({
    spacing: { before: 60, after: 60 },
    indent: { left: 720 },
    children: [new TextRun({ text, font: "Courier New", size: 18, color: "C7254E" })]
  });
}
function separator() {
  return new Paragraph({
    spacing: { before: 200, after: 200 },
    border: { bottom: { style: BorderStyle.SINGLE, size: 4, color: "DDDDDD" } },
    children: []
  });
}
function note(text) {
  return new Paragraph({
    spacing: { before: 100, after: 100 },
    indent: { left: 360 },
    children: [
      new TextRun({ text: "⚠️ CATATAN: ", bold: true, font: "Arial", size: 20, color: "E05A00" }),
      new TextRun({ text, font: "Arial", size: 20, color: "555555", italics: true })
    ]
  });
}
function critical(text) {
  return new Paragraph({
    spacing: { before: 100, after: 100 },
    indent: { left: 360 },
    children: [
      new TextRun({ text: "🔴 KRITIS: ", bold: true, font: "Arial", size: 20, color: "CC0000" }),
      new TextRun({ text, font: "Arial", size: 20, color: "CC0000" })
    ]
  });
}
function makeTable(headers, rows, colWidths) {
  const totalWidth = colWidths.reduce((a, b) => a + b, 0);
  return new Table({
    width: { size: totalWidth, type: WidthType.DXA },
    columnWidths: colWidths,
    rows: [
      new TableRow({
        tableHeader: true,
        children: headers.map((h, i) => new TableCell({
          borders: headerBorders,
          width: { size: colWidths[i], type: WidthType.DXA },
          shading: { fill: "1A56C4", type: ShadingType.CLEAR },
          margins: { top: 80, bottom: 80, left: 120, right: 120 },
          children: [new Paragraph({ children: [new TextRun({ text: h, bold: true, color: "FFFFFF", font: "Arial", size: 20 })] })]
        }))
      }),
      ...rows.map((row, ri) => new TableRow({
        children: row.map((cell, ci) => new TableCell({
          borders,
          width: { size: colWidths[ci], type: WidthType.DXA },
          shading: { fill: ri % 2 === 0 ? "F8FAFF" : "FFFFFF", type: ShadingType.CLEAR },
          margins: { top: 80, bottom: 80, left: 120, right: 120 },
          children: [new Paragraph({ children: [new TextRun({ text: cell, font: "Arial", size: 20 })] })]
        }))
      }))
    ]
  });
}

const doc = new Document({
  numbering: {
    config: [
      { reference: "bullets", levels: [
        { level: 0, format: LevelFormat.BULLET, text: "•", alignment: AlignmentType.LEFT, style: { paragraph: { indent: { left: 720, hanging: 360 } } } },
        { level: 1, format: LevelFormat.BULLET, text: "◦", alignment: AlignmentType.LEFT, style: { paragraph: { indent: { left: 1080, hanging: 360 } } } },
      ]},
      { reference: "numbers", levels: [
        { level: 0, format: LevelFormat.DECIMAL, text: "%1.", alignment: AlignmentType.LEFT, style: { paragraph: { indent: { left: 720, hanging: 360 } } } },
        { level: 1, format: LevelFormat.DECIMAL, text: "%1.%2.", alignment: AlignmentType.LEFT, style: { paragraph: { indent: { left: 1080, hanging: 360 } } } },
      ]},
    ]
  },
  styles: {
    default: { document: { run: { font: "Arial", size: 22, color: "222222" } } },
    paragraphStyles: [
      { id: "Heading1", name: "Heading 1", basedOn: "Normal", next: "Normal", quickFormat: true,
        run: { size: 36, bold: true, font: "Arial", color: "1A56C4" },
        paragraph: { spacing: { before: 400, after: 200 }, outlineLevel: 0 } },
      { id: "Heading2", name: "Heading 2", basedOn: "Normal", next: "Normal", quickFormat: true,
        run: { size: 28, bold: true, font: "Arial", color: "1A56C4" },
        paragraph: { spacing: { before: 280, after: 120 }, outlineLevel: 1 } },
      { id: "Heading3", name: "Heading 3", basedOn: "Normal", next: "Normal", quickFormat: true,
        run: { size: 24, bold: true, font: "Arial", color: "2E4A8C" },
        paragraph: { spacing: { before: 200, after: 100 }, outlineLevel: 2 } },
    ]
  },
  sections: [{
    properties: {
      page: {
        size: { width: 11906, height: 16838 },
        margin: { top: 1440, right: 1440, bottom: 1440, left: 1440 }
      }
    },
    headers: {
      default: new Header({
        children: [
          new Paragraph({
            border: { bottom: { style: BorderStyle.SINGLE, size: 4, color: "1A56C4", space: 1 } },
            children: [
              new TextRun({ text: "EXAMBRO SMAN 4 JEMBER — Product Requirements Document v2.0", font: "Arial", size: 18, color: "1A56C4", bold: true }),
              new TextRun({ text: "    |    CONFIDENTIAL — INTERNAL USE ONLY", font: "Arial", size: 18, color: "999999" })
            ]
          })
        ]
      })
    },
    footers: {
      default: new Footer({
        children: [
          new Paragraph({
            border: { top: { style: BorderStyle.SINGLE, size: 4, color: "DDDDDD", space: 1 } },
            children: [
              new TextRun({ text: "SMAN 4 Jember | Tim Pengembang Exambro 2025", font: "Arial", size: 16, color: "999999" }),
              new TextRun({ children: [new Tab(), new Tab(), new Tab(), new Tab(), new Tab(), new Tab(), new Tab()], font: "Arial", size: 16 }),
              new TextRun({ text: "Hal. ", font: "Arial", size: 16, color: "999999" }),
              new TextRun({ children: [PageNumber.CURRENT], font: "Arial", size: 16, color: "999999" }),
            ]
          })
        ]
      })
    },
    children: [
      // ===== COVER =====
      new Paragraph({ spacing: { before: 1200, after: 200 }, alignment: AlignmentType.CENTER,
        children: [new TextRun({ text: "📱", size: 120 })] }),
      new Paragraph({ alignment: AlignmentType.CENTER, spacing: { before: 0, after: 160 },
        children: [new TextRun({ text: "EXAMBRO", font: "Arial", size: 72, bold: true, color: "1A56C4" })] }),
      new Paragraph({ alignment: AlignmentType.CENTER, spacing: { before: 0, after: 80 },
        children: [new TextRun({ text: "SMAN 4 JEMBER", font: "Arial", size: 36, bold: true, color: "2E4A8C" })] }),
      new Paragraph({ alignment: AlignmentType.CENTER, spacing: { before: 0, after: 400 },
        children: [new TextRun({ text: "Product Requirements Document (PRD)", font: "Arial", size: 28, color: "666666", italics: true })] }),
      makeTable(
        ["Field", "Detail"],
        [
          ["Versi", "2.0 – Production Grade"],
          ["Tanggal", "27 Februari 2025"],
          ["Status", "FINAL – Berlaku Mutlak"],
          ["Framework", "Flutter (Dart) + Node.js Backend"],
          ["Platform Target", "Android & iOS"],
          ["Lingkungan", "Jaringan Lokal Sekolah (Offline/LAN)"],
          ["IDE Pengembangan", "Antigravity IDE (Claude Sonnet 4.6)"],
          ["Arsitektur", "MVVM (Model-View-ViewModel)"],
        ],
        [3000, 6026]
      ),
      new Paragraph({ spacing: { before: 600, after: 0 },
        children: [new TextRun({ text: "⚠️ PERHATIAN UNTUK AI AGENT (ANTIGRAVITY / CLAUDE):", font: "Arial", size: 22, bold: true, color: "CC0000" })] }),
      new Paragraph({ spacing: { before: 80, after: 80 },
        children: [new TextRun({ text: "Dokumen ini adalah spesifikasi MUTLAK dan FINAL. AI DILARANG menambah fitur, mengubah struktur halaman, menggunakan library di luar daftar, atau melakukan improvisasi apapun tanpa instruksi eksplisit. Setiap penyimpangan dianggap BUG dan harus segera diperbaiki.", font: "Arial", size: 20, color: "CC0000" })] }),

      new Paragraph({ children: [new PageBreak()] }),

      // ===== SECTION 1: OVERVIEW =====
      h1("1. GAMBARAN UMUM PROYEK"),
      h2("1.1. Deskripsi Aplikasi"),
      p("Exambro SMAN 4 Jember adalah mobile exam browser berbasis Flutter yang berfungsi sebagai wrapper aman menuju LMS Moodle lokal. Aplikasi ini menggantikan aplikasi Riyu Exambro dari Play Store dengan solusi custom yang sepenuhnya dapat dikontrol oleh sekolah."),
      h2("1.2. Tujuan Utama"),
      bullet("Menyediakan antarmuka login token ujian yang sederhana dan aman."),
      bullet("Mengunci perangkat (kiosk/lockdown mode) selama ujian berlangsung."),
      bullet("Menghubungkan siswa ke LMS Moodle melalui WebView terisolasi."),
      bullet("Memberikan admin panel tersembunyi untuk konfigurasi server tanpa update aplikasi."),
      bullet("Memastikan isolasi sesi antar siswa (tidak ada bocor akun)."),
      h2("1.3. Lingkup Operasi"),
      bullet("Jaringan lokal sekolah (Intranet/LAN via Wi-Fi)."),
      bullet("Server Moodle berjalan di Ubuntu Server di atas Proxmox."),
      bullet("Target jumlah perangkat simultan: hingga 800+ perangkat."),
      h2("1.4. Batasan Proyek"),
      bullet("Tidak mengelola data Moodle secara langsung (hanya wrapper WebView)."),
      bullet("Tidak mendukung ujian di luar jaringan lokal sekolah (kecuali dikonfigurasi ulang)."),
      bullet("Backend hanya bertanggung jawab validasi token, bukan manajemen soal ujian."),

      separator(),

      // ===== SECTION 2: TECH STACK =====
      h1("2. TECH STACK & SISTEM ARSITEKTUR (WAJIB)"),
      critical("AI DILARANG menggunakan bahasa, framework, atau library di luar spesifikasi ini."),
      h2("2.1. Frontend (Mobile App)"),
      makeTable(
        ["Komponen", "Spesifikasi", "Alasan"],
        [
          ["Bahasa", "Dart", "Bahasa native Flutter, performa optimal"],
          ["Framework", "Flutter (Stable channel terbaru)", "Cross-platform Android & iOS dari satu codebase"],
          ["State Management", "Provider v6.1.1 (pilih satu, konsisten)", "Ringan, resmi didukung Flutter team"],
          ["UI Icons", "Material Icons bawaan Flutter SAJA", "Offline-first, tidak butuh internet"],
          ["Tema", "Dark Mode statis (#121212 / grey[900])", "Mengurangi kelelahan mata siswa"],
          ["Local Storage", "shared_preferences", "Menyimpan URL server dan PIN admin lokal"],
          ["HTTP Client", "http v1.1.0", "Request validasi token ke backend"],
          ["Keamanan Android", "flutter_windowmanager v0.2.0", "FLAG_SECURE blok screenshot"],
          ["Kiosk Android", "kiosk_mode v0.2.0", "App pinning mode"],
          ["iOS Guidance", "guided_access v1.0.0", "Deteksi Guided Access status"],
          ["Hashing PIN", "crypto v3.0.3", "SHA-256 hash untuk PIN admin"],
          ["Formatting", "intl v0.18.1", "Format tanggal/waktu"],
        ],
        [2500, 3200, 3300]
      ),
      new Paragraph({ spacing: { before: 160 }, children: [] }),
      h2("2.2. Backend (API & Admin Panel Lokal)"),
      makeTable(
        ["Komponen", "Spesifikasi", "Alasan"],
        [
          ["Bahasa", "JavaScript (Node.js)", "Ringan, event-driven, cocok untuk I/O tinggi"],
          ["Framework", "Express.js", "Minimal, cepat, mudah di-maintain"],
          ["Database", "SQLite (better-sqlite3)", "Tidak butuh service terpisah, mudah backup"],
          ["Hosting", "Ubuntu Server (di Proxmox)", "Sudah tersedia di infrastruktur sekolah"],
          ["Process Manager", "pm2", "Auto-restart, monitoring, log management"],
        ],
        [2000, 3500, 3500]
      ),
      new Paragraph({ spacing: { before: 160 }, children: [] }),
      h2("2.3. Protokol Komunikasi Frontend ↔ Backend"),
      makeTable(
        ["Parameter", "Nilai"],
        [
          ["Format Data", "JSON (Content-Type: application/json)"],
          ["HTTP Timeout", "10 detik (max)"],
          ["Retry Policy", "Maksimal 1 kali retry otomatis"],
          ["Rate Limiting", "Max 5 attempt/IP/menit → blok 60 detik"],
          ["Enkripsi", "Tidak wajib (LAN lokal), opsional HTTPS jika ada sertifikat self-signed"],
        ],
        [3000, 6000]
      ),

      separator(),

      // ===== SECTION 3: STRUKTUR DIREKTORI =====
      h1("3. STRUKTUR DIREKTORI PROYEK (WAJIB)"),
      h2("3.1. Flutter (Frontend)"),
      code("/lib"),
      code("  /models"),
      code("    token_model.dart          # Model response token dari API"),
      code("    config_model.dart         # Model konfigurasi server lokal"),
      code("  /views"),
      code("    splash_screen.dart        # Halaman awal / loading"),
      code("    login_screen.dart         # Input token ujian"),
      code("    admin_screen.dart         # Konfigurasi server (tersembunyi)"),
      code("    exam_screen.dart          # WebView Moodle fullscreen"),
      code("  /viewmodels"),
      code("    splash_viewmodel.dart     # Logic: cek config, routing awal"),
      code("    login_viewmodel.dart      # Logic: validasi token, API call"),
      code("    admin_viewmodel.dart      # Logic: baca/tulis shared_prefs"),
      code("    exam_viewmodel.dart       # Logic: lockdown, WebView, exit"),
      code("  /services"),
      code("    api_client.dart           # HTTP client singleton"),
      code("    local_storage_service.dart # Wrapper shared_preferences"),
      code("    security_helper.dart      # FLAG_SECURE, kiosk mode calls"),
      code("    webview_helper.dart       # Clear cache, cookies, session"),
      code("  /utils"),
      code("    constants.dart            # Konstanta global (timeout, keys)"),
      code("    colors.dart               # Definisi warna tema dark"),
      code("    routes.dart               # Named routes aplikasi"),
      code("  main.dart                   # Entry point, Provider setup"),
      new Paragraph({ spacing: { before: 120 }, children: [] }),
      note("Setiap ViewModel HANYA berisi logika bisnis. Tidak boleh ada kode UI (Widget) di ViewModel. Setiap Service bersifat stateless atau singleton."),
      h2("3.2. Node.js (Backend)"),
      code("/backend"),
      code("  /routes"),
      code("    token.js          # Route POST /api/validate"),
      code("    admin.js          # Route GET/POST /admin (web panel)"),
      code("  /middleware"),
      code("    rateLimit.js      # Rate limiting per IP"),
      code("    auth.js           # Basic auth untuk /admin web panel"),
      code("  /database"),
      code("    db.js             # Koneksi SQLite dan init tabel"),
      code("    schema.sql        # DDL tabel tokens"),
      code("  /views              # HTML sederhana untuk admin panel"),
      code("    admin.html"),
      code("  app.js              # Entry point Express"),
      code("  package.json"),
      code("  ecosystem.config.js # Konfigurasi pm2"),
      code("  .env               # PORT, ADMIN_PASSWORD, DB_PATH"),

      separator(),

      // ===== SECTION 4: ALUR APLIKASI =====
      h1("4. ALUR APLIKASI & PAGE FLOW (APP FLOW)"),
      h2("4.1. Splash Screen — Route: /"),
      h3("UI"),
      bullet("Logo sekolah di tengah layar, background #121212."),
      bullet("Loading indicator kecil di bawah logo."),
      bullet("TIDAK ada teks versi atau informasi lain di layar siswa."),
      h3("Logic ViewModel (splash_viewmodel.dart)"),
      numbered("Baca shared_preferences: cek apakah server_ip_url sudah terisi."),
      numbered("Jika KOSONG → tampilkan dialog: \"Hubungi pengawas untuk konfigurasi awal.\" → tetap di splash, jangan navigasi."),
      numbered("Jika ADA → tunggu 2 detik (Future.delayed) → navigasi ke /login."),
      critical("Jangan navigasi ke halaman lain selain /login dari Splash Screen."),

      new Paragraph({ spacing: { before: 160 }, children: [] }),
      h2("4.2. Login Screen — Route: /login"),
      h3("UI"),
      bullet("Layout: Center column, dark background."),
      bullet("Logo sekolah di bagian atas (GestureDetector — lihat Hidden Gesture)."),
      bullet("TextField: hint \"Masukkan Token Ujian\", teks putih, border abu-abu."),
      bullet("Tombol \"Mulai Ujian\": ElevatedButton, warna biru, lebar penuh."),
      bullet("TIDAK ada tombol back, TIDAK ada link lain."),
      h3("Hidden Gesture (Akses Admin)"),
      numbered("Bungkus logo sekolah dengan GestureDetector."),
      numbered("Deteksi 7 kali tap dalam 3 detik menggunakan counter + Timer reset."),
      numbered("Setelah 7 tap → tampilkan dialog input PIN admin (bukan langsung navigasi)."),
      numbered("Verifikasi PIN (hash SHA-256) dengan nilai di shared_preferences."),
      numbered("Jika benar → navigasi ke /admin. Jika salah → snackbar \"PIN salah\"."),
      critical("DILARANG langsung navigasi ke /admin tanpa verifikasi PIN."),
      h3("Logic ViewModel (login_viewmodel.dart)"),
      numbered("Validasi: input tidak boleh kosong."),
      numbered("Kirim POST ke URL API (dari shared_preferences) dengan body: {\"token\": \"...\"}"),
      numbered("Tangani response:"),
      bullet("success: true + exam_active: true → jalankan lockdown (lihat 5.1) → navigasi ke /exam.", 1),
      bullet("success: false → snackbar merah \"Token salah / ujian belum dibuka\".", 1),
      bullet("exam_active: false → snackbar kuning \"Ujian belum dimulai oleh pengawas\".", 1),
      bullet("Timeout / network error → snackbar oranye \"Tidak dapat terhubung ke server lokal. Periksa Wi-Fi.\"", 1),
      numbered("Jangan navigasi ke /exam jika ada kondisi error apapun."),

      new Paragraph({ spacing: { before: 160 }, children: [] }),
      h2("4.3. Admin Screen — Route: /admin"),
      h3("Akses"),
      bullet("HANYA melalui hidden gesture 7-tap + verifikasi PIN (lihat 4.2)."),
      bullet("TIDAK ada tombol/link yang mengarah ke sini dari layar siswa."),
      h3("UI"),
      bullet("TextField: \"URL Server Moodle\" (contoh: http://192.168.1.100/moodle)."),
      bullet("TextField: \"URL API Validasi Token\" (contoh: http://192.168.1.100/api/validate)."),
      bullet("TextField: \"Ganti PIN Admin\" (kosongkan jika tidak ingin ganti, placeholder: \"Kosongkan jika tidak ganti\")."),
      bullet("Tombol \"Simpan Konfigurasi\"."),
      bullet("Tombol \"Kembali ke Login\"."),
      h3("Logic ViewModel (admin_viewmodel.dart)"),
      numbered("Saat init: baca semua nilai dari shared_preferences dan isi ke TextField."),
      numbered("Saat simpan: validasi URL harus diawali http:// atau https://."),
      numbered("Simpan URL ke shared_preferences."),
      numbered("Jika field PIN diisi: hash dengan SHA-256 → simpan hash ke shared_preferences, gantikan hash lama."),
      numbered("Tampilkan Snackbar hijau \"Konfigurasi berhasil disimpan\"."),
      critical("Jangan simpan PIN dalam bentuk plain text. Selalu hash dengan SHA-256."),

      new Paragraph({ spacing: { before: 160 }, children: [] }),
      h2("4.4. Exam Screen — Route: /exam"),
      h3("UI"),
      bullet("Fullscreen WebView. TIDAK ada AppBar, TIDAK ada BottomNavigationBar."),
      bullet("FloatingActionButton kecil (icon: Icons.exit_to_app) di pojok kanan bawah untuk keluar."),
      bullet("iOS: Jika Guided Access tidak aktif → tampilkan dialog instruksi, JANGAN load WebView."),
      h3("Logic ViewModel — onInit (exam_viewmodel.dart)"),
      numbered("[Android] Panggil security_helper.dart → FlutterWindowManager.addFlags(FLAG_SECURE)."),
      numbered("[Android] Aktifkan kiosk mode via kiosk_mode package."),
      numbered("[iOS] Deteksi status Guided Access. Jika OFF → tampilkan dialog:\n\"Aktifkan Guided Access sebelum ujian. Buka Settings → Accessibility → Guided Access, lalu aktifkan dan triple-click tombol side/home.\" → blokir WebView."),
      numbered("Load URL Moodle dari local_storage_service.dart ke WebViewController."),
      h3("WebView Configuration (WAJIB SEMUA)"),
      makeTable(
        ["Setting", "Nilai", "Platform"],
        [
          ["javascriptEnabled", "true", "Android & iOS"],
          ["domStorageEnabled", "true", "Android & iOS"],
          ["fileAccess", "false", "Android & iOS"],
          ["setSupportMultipleWindows", "false", "Android"],
          ["long press context menu", "DISABLED", "Android & iOS"],
          ["text selection", "DISABLED", "Android & iOS"],
          ["external browser redirect", "BLOCKED", "Android & iOS"],
          ["file download", "BLOCKED", "Android & iOS"],
          ["new window popup", "BLOCKED", "Android & iOS"],
          ["inlineMediaPlayback", "false", "iOS"],
          ["back-forward gestures", "false (allowsBackForwardNavigationGestures)", "iOS"],
        ],
        [3000, 3000, 3000]
      ),
      new Paragraph({ spacing: { before: 120 }, children: [] }),
      h3("NavigationDelegate (WAJIB)"),
      bullet("Ekstrak domain dari URL Moodle saat load pertama."),
      bullet("Jika redirect ke domain berbeda → NavigationDecision.prevent + snackbar \"Akses dibatasi oleh Exambro\"."),
      bullet("Hanya izinkan navigasi dalam domain Moodle yang sama."),
      h3("Logic — onExit (FAB ditekan)"),
      numbered("Tampilkan dialog input PIN admin."),
      numbered("Verifikasi PIN (hash SHA-256)."),
      numbered("Jika benar:"),
      bullet("Clear cache WebView.", 1),
      bullet("Clear cookies.", 1),
      bullet("Clear local storage & session storage WebView.", 1),
      bullet("Dispose WebViewController.", 1),
      bullet("[Android] Nonaktifkan FLAG_SECURE.", 1),
      bullet("[Android] Matikan kiosk mode.", 1),
      bullet("Navigasi ke /login (bukan pop, tapi pushReplacement).", 1),
      numbered("Jika salah → snackbar \"PIN salah, hubungi pengawas\"."),
      critical("DILARANG me-reuse WebView instance lama. Selalu buat instance baru untuk sesi berikutnya."),

      separator(),

      // ===== SECTION 5: BACKEND SPEC =====
      h1("5. BACKEND SPECIFICATION (NODE.JS)"),
      h2("5.1. Database Schema (SQLite)"),
      code("CREATE TABLE IF NOT EXISTS tokens ("),
      code("  id INTEGER PRIMARY KEY AUTOINCREMENT,"),
      code("  token TEXT UNIQUE NOT NULL,"),
      code("  exam_active INTEGER DEFAULT 0,  -- 0=false, 1=true"),
      code("  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,"),
      code("  expires_at DATETIME"),
      code(");"),
      code(""),
      code("CREATE TABLE IF NOT EXISTS admin_config ("),
      code("  key TEXT PRIMARY KEY,"),
      code("  value TEXT"),
      code(");"),
      code("-- Contoh: INSERT INTO admin_config VALUES ('admin_password', 'admin');"),
      new Paragraph({ spacing: { before: 120 }, children: [] }),
      h2("5.2. API Endpoints"),
      makeTable(
        ["Method", "Endpoint", "Fungsi", "Auth"],
        [
          ["POST", "/api/validate", "Validasi token dari aplikasi Flutter", "Tidak perlu auth"],
          ["GET", "/admin", "Halaman web admin panel", "Basic Auth / session"],
          ["POST", "/admin/token/add", "Tambah token baru", "Basic Auth"],
          ["POST", "/admin/token/toggle", "Aktifkan/nonaktifkan token", "Basic Auth"],
          ["POST", "/admin/token/delete", "Hapus token", "Basic Auth"],
        ],
        [1200, 2500, 3000, 2300]
      ),
      new Paragraph({ spacing: { before: 120 }, children: [] }),
      h2("5.3. Request & Response Contract"),
      h3("POST /api/validate — Request Body"),
      code("{"),
      code("  \"token\": \"string\""),
      code("}"),
      h3("POST /api/validate — Response (Sukses)"),
      code("{"),
      code("  \"success\": true,"),
      code("  \"exam_active\": true,"),
      code("  \"server_time\": \"2025-02-27T10:00:00Z\","),
      code("  \"message\": \"Token valid\""),
      code("}"),
      h3("POST /api/validate — Response (Gagal - Token Salah)"),
      code("{"),
      code("  \"success\": false,"),
      code("  \"exam_active\": false,"),
      code("  \"server_time\": \"2025-02-27T10:00:00Z\","),
      code("  \"message\": \"Token tidak ditemukan\""),
      code("}"),
      h3("POST /api/validate — Response (Gagal - Ujian Belum Aktif)"),
      code("{"),
      code("  \"success\": true,"),
      code("  \"exam_active\": false,"),
      code("  \"server_time\": \"2025-02-27T10:00:00Z\","),
      code("  \"message\": \"Ujian belum dimulai\""),
      code("}"),
      h2("5.4. Rate Limiting"),
      bullet("Maksimal 5 request per IP per menit pada endpoint /api/validate."),
      bullet("Jika terlampaui → response HTTP 429 + pesan \"Terlalu banyak percobaan. Tunggu 60 detik.\""),
      bullet("Gunakan package express-rate-limit."),

      separator(),

      // ===== SECTION 6: KEAMANAN =====
      h1("6. PROTOKOL KEAMANAN & CONSTRAINTS"),
      h2("6.1. Session Isolation (SUPER WAJIB)"),
      critical("Ini adalah sumber bug paling umum pada exam browser buatan sendiri."),
      p("Setiap kali siswa keluar dari Exam Screen (via FAB, force close, atau navigasi apapun), WAJIB dieksekusi:"),
      numbered("ClearCache() pada WebViewController."),
      numbered("ClearCookies() via CookieManager."),
      numbered("Clear localStorage & sessionStorage via evaluateJavascript: window.localStorage.clear(); window.sessionStorage.clear();"),
      numbered("Dispose WebViewController sepenuhnya."),
      numbered("Buat WebViewController instance BARU untuk sesi siswa berikutnya."),
      critical("DILARANG me-reuse WebViewController yang sudah digunakan."),
      h2("6.2. Platform Security Constraints"),
      h3("Android — Full Lockdown"),
      bullet("Aktifkan FLAG_SECURE via flutter_windowmanager (blok screenshot & screen recording)."),
      bullet("Aktifkan App Pinning via kiosk_mode package."),
      bullet("Blokir split screen jika API memungkinkan."),
      h3("iOS — Limited (TIDAK BISA FULL LOCKDOWN)"),
      bullet("iOS TIDAK mengizinkan aplikasi pihak ketiga mengunci tombol Home atau swipe secara penuh."),
      bullet("WAJIB mendeteksi status Guided Access sebelum load WebView."),
      bullet("Jika Guided Access OFF → blokir akses Moodle + tampilkan instruksi."),
      bullet("Jika Guided Access ON → lanjutkan ke WebView."),
      critical("AI DILARANG membuat 'full kiosk iOS' — itu tidak mungkin dan akan menyebabkan crash atau penolakan App Store."),
      h2("6.3. Network Resilience"),
      bullet("HTTP timeout: 10 detik untuk semua request."),
      bullet("Retry: maksimal 1 kali otomatis setelah timeout."),
      bullet("Pesan error ramah (tidak boleh crash atau infinite loading):"),
      code("\"Tidak dapat terhubung ke Server Lokal. Periksa koneksi Wi-Fi ujian.\""),
      h2("6.4. Performance Requirements (800+ Device)"),
      makeTable(
        ["Metrik", "Target"],
        [
          ["Cold Start", "< 3 detik"],
          ["Memory Usage", "< 250 MB per instance"],
          ["WebView Instance", "Hanya 1 aktif dalam satu waktu"],
          ["Controller Dispose", "WAJIB di-dispose saat exit exam dan route change"],
          ["Memory Leak", "NOL toleransi — semua controller harus di-dispose"],
        ],
        [4000, 5000]
      ),
      new Paragraph({ spacing: { before: 120 }, children: [] }),
      h2("6.5. Logging"),
      bullet("Debug build: simpan log lokal ke device storage (ring buffer, max 1000 entri)."),
      bullet("Yang dicatat: waktu buka exam, hasil validasi token, error jaringan, waktu keluar exam."),
      bullet("Release build: hanya log error fatal."),
      bullet("TIDAK boleh ada log yang berisi token dalam bentuk plain text."),

      separator(),

      // ===== SECTION 7: PUBSPEC =====
      h1("7. DEPENDENCIES (PUBSPEC.YAML)"),
      code("dependencies:"),
      code("  flutter:"),
      code("    sdk: flutter"),
      code("  provider: ^6.1.1"),
      code("  shared_preferences: ^2.2.2"),
      code("  webview_flutter: ^4.4.4"),
      code("  http: ^1.1.0"),
      code("  flutter_windowmanager: ^0.2.0"),
      code("  kiosk_mode: ^0.2.0"),
      code("  guided_access: ^1.0.0   # iOS Guided Access detection"),
      code("  crypto: ^3.0.3          # SHA-256 hashing untuk PIN"),
      code("  intl: ^0.18.1"),
      code(""),
      code("dev_dependencies:"),
      code("  flutter_test:"),
      code("    sdk: flutter"),
      code("  flutter_lints: ^3.0.0"),
      note("Cek versi terbaru dari setiap package di pub.dev sebelum memulai. Gunakan 'flutter pub get' setelah menambahkan dependencies."),

      separator(),

      // ===== SECTION 8: PRIORITAS IMPLEMENTASI =====
      h1("8. URUTAN IMPLEMENTASI (WAJIB DIIKUTI)"),
      p("Setiap langkah harus diuji dan berfungsi sebelum melanjutkan ke langkah berikutnya."),
      makeTable(
        ["Prioritas", "Tugas", "Keterangan"],
        [
          ["1", "Setup proyek Flutter + struktur direktori", "Buat semua folder dan file kosong sesuai Section 3.1"],
          ["2", "Splash Screen + routing dasar", "Named routes, Provider setup, shared_prefs check"],
          ["3", "Login Screen + hidden gesture", "TextField, tombol, 7-tap counter, dialog PIN"],
          ["4", "Admin Screen + PIN + shared_prefs", "Form URL, validasi format, hash PIN, simpan"],
          ["5", "Backend Node.js (SQLite + Express)", "Endpoint /api/validate, rate limit, admin panel web"],
          ["6", "Exam Screen dasar (WebView tanpa lockdown)", "Load URL Moodle, NavigationDelegate domain check"],
          ["7", "Session isolation", "Clear cache/cookies/storage saat exit, dispose controller"],
          ["8", "Android lockdown", "FLAG_SECURE + kiosk mode"],
          ["9", "iOS Guided Access detection", "Deteksi status, dialog instruksi jika OFF"],
          ["10", "WebView hardening", "Disable long press, text select, block download"],
          ["11", "Network resilience & error handling", "Timeout, retry, fallback UI"],
          ["12", "Logging", "Debug log ke lokal storage"],
        ],
        [1200, 3500, 4300]
      ),

      separator(),

      // ===== SECTION 9: SETUP SEBELUM PROMPT =====
      h1("9. LANGKAH WAJIB SEBELUM MENGIRIM PROMPT KE ANTIGRAVITY"),
      h2("9.1. Instalasi Flutter & Dart"),
      numbered("Download Flutter SDK dari flutter.dev/docs/get-started/install."),
      numbered("Ekstrak ke folder yang mudah diakses (contoh: C:\\flutter atau ~/flutter)."),
      numbered("Tambahkan path Flutter ke environment variable PATH."),
      numbered("Jalankan: flutter doctor → pastikan semua checkmark hijau."),
      numbered("Install Android Studio (untuk Android SDK dan emulator)."),
      numbered("Install Xcode (macOS only, untuk build iOS)."),
      h2("9.2. Instalasi Node.js & Tools Backend"),
      numbered("Download Node.js LTS dari nodejs.org."),
      numbered("Instal pm2 secara global: npm install -g pm2"),
      numbered("Instal better-sqlite3 dan express di folder backend: npm install express better-sqlite3 express-rate-limit dotenv"),
      h2("9.3. Persiapan di Antigravity IDE"),
      numbered("Buka Antigravity IDE dan buat project baru atau workspace kosong."),
      numbered("Pastikan Claude Sonnet 4.6 dipilih sebagai model AI agent."),
      numbered("Upload atau paste seluruh isi dokumen PRD ini ke context agent."),
      numbered("Beri instruksi awal: \"Baca seluruh PRD ini terlebih dahulu sebelum menulis satu baris kode pun. Konfirmasi pemahaman Anda terhadap setiap section sebelum memulai.\""),
      numbered("Mulai dari Prioritas 1 (setup proyek) satu per satu, jangan loncat."),
      h2("9.4. Checklist Sebelum Prompt Dikirim"),
      bullet("[ ] Flutter SDK terinstall dan flutter doctor bersih."),
      bullet("[ ] Android Studio terinstall dan Android emulator siap."),
      bullet("[ ] Node.js LTS terinstall."),
      bullet("[ ] pm2 terinstall global."),
      bullet("[ ] Dokumen PRD ini sudah diupload ke Antigravity."),
      bullet("[ ] IP Address server lokal sudah diketahui (contoh: 192.168.1.100)."),
      bullet("[ ] Server Moodle lokal sudah berjalan dan dapat diakses dari browser."),
      bullet("[ ] Wi-Fi sekolah sudah aktif dan perangkat terhubung ke jaringan lokal."),

      separator(),

      // ===== SECTION 10: PROMPT SIAP PAKAI =====
      h1("10. PROMPT SIAP PAKAI UNTUK ANTIGRAVITY IDE"),
      h2("10.1. Prompt Inisialisasi Awal (Copy-paste Pertama Kali)"),
      note("Copy seluruh blok di bawah dan paste sebagai pesan pertama ke Antigravity:"),
      new Paragraph({ spacing: { before: 120, after: 80 },
        shading: { fill: "F0F4FF", type: ShadingType.CLEAR },
        border: { top: borderThin, bottom: borderThin, left: { style: BorderStyle.SINGLE, size: 8, color: "1A56C4" }, right: borderThin },
        children: [new TextRun({ text: "Saya sedang membangun aplikasi Exambro SMAN 4 Jember. Sebelum menulis kode, baca dan pahami seluruh PRD yang telah saya lampirkan. Setelah membaca, konfirmasi pemahaman Anda dengan meringkas: (1) tech stack yang akan digunakan, (2) halaman-halaman yang ada, (3) urutan implementasi. Jangan mulai coding sebelum saya berikan instruksi selanjutnya.", font: "Arial", size: 20, italics: true, color: "333333" })]
      }),
      new Paragraph({ spacing: { before: 120 }, children: [] }),
      h2("10.2. Prompt Mulai Implementasi (Per Langkah)"),
      note("Kirim satu per satu sesuai urutan prioritas:"),
      new Paragraph({ spacing: { before: 80 },
        children: [new TextRun({ text: "Langkah 1 — Setup Proyek:", font: "Arial", size: 22, bold: true, color: "1A56C4" })] }),
      new Paragraph({
        shading: { fill: "F0F4FF", type: ShadingType.CLEAR },
        border: { top: borderThin, bottom: borderThin, left: { style: BorderStyle.SINGLE, size: 8, color: "1A56C4" }, right: borderThin },
        spacing: { before: 40, after: 120 },
        children: [new TextRun({ text: "Mulai implementasi Langkah 1: buat proyek Flutter baru bernama 'exambro_sman4jember', buat seluruh struktur direktori sesuai PRD Section 3.1, buat semua file Dart dengan komentar header (nama file, fungsi, tanggal). Jangan isi logika dulu, hanya scaffold/boilerplate. Konfirmasi setiap file yang dibuat.", font: "Arial", size: 20, italics: true, color: "333333" })]
      }),
      new Paragraph({ spacing: { before: 80 },
        children: [new TextRun({ text: "Langkah 5 — Backend:", font: "Arial", size: 22, bold: true, color: "1A56C4" })] }),
      new Paragraph({
        shading: { fill: "F0F4FF", type: ShadingType.CLEAR },
        border: { top: borderThin, bottom: borderThin, left: { style: BorderStyle.SINGLE, size: 8, color: "1A56C4" }, right: borderThin },
        spacing: { before: 40, after: 120 },
        children: [new TextRun({ text: "Implementasi backend Node.js sesuai PRD Section 5. Buat: (1) app.js entry point, (2) routes/token.js dengan endpoint POST /api/validate dan rate limiting 5x/menit, (3) database/db.js dengan schema SQLite sesuai PRD, (4) routes/admin.js dengan admin panel HTML sederhana, (5) ecosystem.config.js untuk pm2. Gunakan better-sqlite3. Sertakan komentar di setiap fungsi. JANGAN menambahkan fitur di luar spesifikasi PRD.", font: "Arial", size: 20, italics: true, color: "333333" })]
      }),
      h2("10.3. Prompt Debugging (Jika Ada Bug)"),
      new Paragraph({
        shading: { fill: "FFF8F0", type: ShadingType.CLEAR },
        border: { top: borderThin, bottom: borderThin, left: { style: BorderStyle.SINGLE, size: 8, color: "E05A00" }, right: borderThin },
        spacing: { before: 40, after: 120 },
        children: [new TextRun({ text: "Ada bug pada [nama file/halaman]: [deskripsi bug]. Perbaiki HANYA bug ini tanpa mengubah logika, struktur, atau halaman lain yang tidak berhubungan. Konfirmasi baris kode mana yang diubah dan alasannya. Pastikan tetap konsisten dengan PRD dan halaman lain.", font: "Arial", size: 20, italics: true, color: "333333" })]
      }),

      separator(),

      // ===== SECTION 11: KRITIK & SARAN =====
      h1("11. EVALUASI RANCANGAN & SARAN PERBAIKAN"),
      h2("11.1. Yang Sudah Sangat Baik"),
      bullet("Arsitektur MVVM sudah tepat untuk project Flutter skala produksi."),
      bullet("Pilihan SQLite untuk backend token sangat rasional — ringan dan tidak butuh service tambahan."),
      bullet("Pemisahan keamanan Android (full lockdown) dan iOS (Guided Access) sudah benar secara teknis."),
      bullet("Session isolation protocol sudah komprehensif."),
      bullet("Hidden gesture + PIN admin adalah lapisan keamanan yang baik."),
      bullet("Penggunaan Provider untuk state management adalah pilihan konservatif yang stabil."),
      h2("11.2. Potensi Masalah & Saran Perbaikan"),
      makeTable(
        ["Item", "Potensi Masalah", "Saran"],
        [
          ["guided_access package", "Package ini mungkin belum tersedia di pub.dev atau perlu Platform Channel sendiri", "Cek pub.dev dulu. Jika tidak ada, buat Platform Channel iOS sendiri menggunakan UIAccessibility.isGuidedAccessEnabled"],
          ["kiosk_mode package", "Dukungan Android API level mungkin bermasalah di Android 10+", "Test di emulator Android 10, 12, dan 13. Siapkan fallback manual App Pinning jika package gagal"],
          ["flutter_windowmanager", "Perlu AndroidManifest.xml permission tambahan", "Tambahkan permission secara eksplisit di AndroidManifest.xml: SYSTEM_ALERT_WINDOW (jika diperlukan)"],
          ["WebView cache clear iOS", "CookieManager berbeda antara Android dan iOS di webview_flutter", "Gunakan WebViewCookieManager yang platform-aware atau cek dokumentasi webview_flutter versi terbaru"],
          ["Rate limiting di LAN", "Pada jaringan LAN, IP mungkin di-share (NAT), membuat rate limiting per IP tidak efektif", "Tambahkan device identifier (UUID) di request body sebagai tambahan identifier"],
          ["Backend pm2 crash", "Jika server restart, token yang sedang aktif mungkin terpengaruh tergantung implementasi", "SQLite persistent storage sudah menangani ini, pastikan WAL mode aktif: PRAGMA journal_mode=WAL"],
          ["Versi package berubah", "Versi di pubspec mungkin sudah outdated saat implementasi", "Cek pub.dev untuk versi terbaru sebelum mulai. Jangan pin ke versi lama tanpa alasan"],
        ],
        [1800, 3000, 4200]
      ),
      new Paragraph({ spacing: { before: 120 }, children: [] }),
      h2("11.3. Fitur yang Bisa Ditambah di Versi Berikutnya (v3.0)"),
      bullet("Halaman status ujian real-time (berapa siswa sudah submit)."),
      bullet("QR Code scanner sebagai input token (menggantikan manual ketik)."),
      bullet("Multi-token per sesi (token berbeda per kelas/ruangan)."),
      bullet("Expiry token otomatis berdasarkan waktu ujian."),
      bullet("Notifikasi sisa waktu ujian dari server ke aplikasi."),
      note("Fitur-fitur ini TIDAK boleh diimplementasikan dalam v2.0. Catat saja untuk backlog."),

      separator(),

      // ===== SECTION 12: ATURAN MUTLAK AI =====
      h1("12. ATURAN MUTLAK UNTUK AI AGENT (ANTIGRAVITY)"),
      new Paragraph({ spacing: { before: 80, after: 80 }, shading: { fill: "FFF0F0", type: ShadingType.CLEAR },
        border: { top: { style: BorderStyle.SINGLE, size: 6, color: "CC0000" }, bottom: { style: BorderStyle.SINGLE, size: 6, color: "CC0000" }, left: { style: BorderStyle.SINGLE, size: 6, color: "CC0000" }, right: { style: BorderStyle.SINGLE, size: 6, color: "CC0000" } },
        children: [new TextRun({ text: "DILARANG (LARANGAN KERAS)", font: "Arial", size: 24, bold: true, color: "CC0000" })] }),
      bullet("DILARANG menambah fitur di luar spesifikasi PRD ini."),
      bullet("DILARANG mengubah struktur halaman yang sudah ditentukan."),
      bullet("DILARANG menggunakan library/package di luar daftar dependencies."),
      bullet("DILARANG mengganti arsitektur MVVM dengan pola lain."),
      bullet("DILARANG membuat 'full kiosk iOS' yang tidak mungkin secara teknis."),
      bullet("DILARANG me-reuse WebView instance antar sesi siswa."),
      bullet("DILARANG menyimpan PIN admin dalam plain text."),
      bullet("DILARANG melanjutkan ke langkah berikutnya jika langkah sebelumnya belum selesai dan diuji."),
      new Paragraph({ spacing: { before: 120 }, children: [] }),
      new Paragraph({ spacing: { before: 80, after: 80 }, shading: { fill: "F0FFF0", type: ShadingType.CLEAR },
        border: { top: { style: BorderStyle.SINGLE, size: 6, color: "1A8C3D" }, bottom: { style: BorderStyle.SINGLE, size: 6, color: "1A8C3D" }, left: { style: BorderStyle.SINGLE, size: 6, color: "1A8C3D" }, right: { style: BorderStyle.SINGLE, size: 6, color: "1A8C3D" } },
        children: [new TextRun({ text: "WAJIB (KEWAJIBAN KERAS)", font: "Arial", size: 24, bold: true, color: "1A8C3D" })] }),
      bullet("WAJIB mengikuti arsitektur MVVM — setiap halaman punya ViewModel terpisah."),
      bullet("WAJIB memberi komentar pada setiap fungsi dan blok kode kompleks."),
      bullet("WAJIB menyertakan header dokumentasi di setiap file (nama file, fungsi, tanggal dibuat)."),
      bullet("WAJIB menangani semua error dan edge case sesuai spesifikasi."),
      bullet("WAJIB meminta konfirmasi jika ada ambiguitas sebelum mengimplementasikan."),
      bullet("WAJIB melaporkan setiap file yang dibuat/diubah beserta alasannya."),
      bullet("WAJIB mengikuti urutan prioritas implementasi di Section 8."),
      bullet("WAJIB mengkonfirmasi pemahaman PRD sebelum memulai coding."),

      separator(),

      // ===== PENUTUP =====
      new Paragraph({ alignment: AlignmentType.CENTER, spacing: { before: 400, after: 200 },
        children: [new TextRun({ text: "— END OF DOCUMENT —", font: "Arial", size: 20, color: "999999", italics: true })] }),
      new Paragraph({ alignment: AlignmentType.CENTER,
        children: [new TextRun({ text: "PRD Exambro SMAN 4 Jember v2.0 | FINAL | 27 Februari 2025", font: "Arial", size: 18, color: "AAAAAA" })] }),
      new Paragraph({ alignment: AlignmentType.CENTER, spacing: { before: 80 },
        children: [new TextRun({ text: "Dokumen ini hanya boleh diubah dengan persetujuan tim pengembang sekolah.", font: "Arial", size: 18, color: "AAAAAA", italics: true })] }),
    ]
  }]
});

Packer.toBuffer(doc).then(buffer => {
  fs.writeFileSync('/home/claude/exambro_prd_v2.docx', buffer);
  console.log('PRD created successfully!');
}).catch(err => {
  console.error('Error:', err);
  process.exit(1);
});
