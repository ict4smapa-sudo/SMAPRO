// =============================================================================
// File     : db.js
// Fungsi   : Inisialisasi koneksi SQLite via better-sqlite3.
//             Mengeksekusi PRAGMA journal_mode=WAL untuk performa tinggi
//             pada jaringan LAN dengan 800+ perangkat simultan (PRD KRITIS).
//             Membuat tabel jika belum ada dengan schema dari schema.sql.
// Tanggal  : 27 Februari 2026
// PRD Ref  : Section 5.1, Section 11.2 (WAL mode)
// =============================================================================

const Database = require('better-sqlite3');
const fs = require('fs');
const path = require('path');
require('dotenv').config();

// Resolve path database dari .env (default: ./database/exambro.db)
const dbPath = process.env.DB_PATH || path.join(__dirname, 'exambro.db');

// Pastikan direktori database ada sebelum membuka file DB
const dbDir = path.dirname(dbPath);
if (!fs.existsSync(dbDir)) {
    fs.mkdirSync(dbDir, { recursive: true });
}

// Buka koneksi database — better-sqlite3 bersifat synchronous (cocok untuk Node.js single-thread)
const db = new Database(dbPath, {
    // Verbose logging hanya di development (jangan di production)
    verbose: process.env.NODE_ENV === 'development' ? console.log : null,
});

// =============================================================================
// PRAGMA WAL MODE — PRD KRITIS (Section 11.2)
// Write-Ahead Logging memungkinkan multiple readers berjalan bersamaan
// tanpa blocking satu sama lain. WAJIB untuk LAN 800+ perangkat simultan.
// =============================================================================
db.pragma('journal_mode = WAL');

// Optimalkan performa: set synchronous ke NORMAL (aman untuk WAL mode)
db.pragma('synchronous = NORMAL');

// Cache size: 64MB untuk mengurangi disk I/O pada banyak request bersamaan
db.pragma('cache_size = -65536');

// Aktifkan foreign key constraint (best practice meskipun belum digunakan)
db.pragma('foreign_keys = ON');

console.log(`[DB] Database terhubung: ${dbPath}`);
console.log(`[DB] journal_mode = ${db.pragma('journal_mode', { simple: true })}`);

// =============================================================================
// INISIALISASI SCHEMA — Baca dan eksekusi schema.sql
// Menggunakan IF NOT EXISTS sehingga aman dijalankan berulang kali.
// =============================================================================
const schemaPath = path.join(__dirname, 'schema.sql');
if (fs.existsSync(schemaPath)) {
    const schemaSql = fs.readFileSync(schemaPath, 'utf-8');
    db.exec(schemaSql);
    console.log('[DB] Schema berhasil diinisialisasi (IF NOT EXISTS).');
} else {
    console.error('[DB] ERROR: schema.sql tidak ditemukan di', schemaPath);
    process.exit(1); // Hentikan server jika schema tidak ada
}

// =============================================================================
// MIGRASI KOLOM supervisor_pin — Safe ALTER TABLE
// Menambahkan kolom supervisor_pin jika belum ada (database lama / upgrade).
// try-catch wajib karena SQLite akan throw error jika kolom sudah ada.
// =============================================================================
try {
    db.exec("ALTER TABLE app_config ADD COLUMN supervisor_pin TEXT DEFAULT '123456';");
    console.log('[DB] Kolom supervisor_pin berhasil ditambahkan ke app_config.');
} catch (_) {
    // Kolom sudah ada — skip migrasi (kondisi normal saat server restart)
}

// =============================================================================
// INISIALISASI DEFAULT app_config — Centralized Configuration
// Jika tabel app_config baru saja dibuat (kosong), masukkan satu baris default.
// Default: moodle_url = alamat Moodle SMAN 4 Jember, semua PIN = '123456'.
// Admin dapat mengubah ketiganya via Web Panel (/admin → Konfigurasi Global).
// =============================================================================
const configCount = db.prepare('SELECT COUNT(*) as c FROM app_config').get();
if (configCount.c === 0) {
    db.prepare(
        'INSERT INTO app_config (moodle_url, admin_pin, exit_pin, supervisor_pin) VALUES (?, ?, ?, ?)'
    ).run('http://182.253.41.180/login/index.php', '123456', '123456', '123456');
    console.log('[DB] app_config default seeded (moodle_url, admin_pin, exit_pin, supervisor_pin = 123456).');
} else {
    console.log('[DB] app_config sudah ada, skip seeding.');
}

module.exports = db;
