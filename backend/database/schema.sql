-- =============================================================================
-- File     : schema.sql
-- Fungsi   : DDL (Data Definition Language) untuk database SQLite Exambro.
--             Dieksekusi satu kali saat server pertama kali dijalankan.
-- Tanggal  : 27 Februari 2026
-- PRD Ref  : Section 5.1
-- =============================================================================

-- Tabel tokens: menyimpan token ujian yang valid beserta status aktifnya.
-- Setiap token unik — tidak ada duplikasi token dalam satu sesi ujian.
CREATE TABLE IF NOT EXISTS tokens (
  id          INTEGER  PRIMARY KEY AUTOINCREMENT,
  token       TEXT     UNIQUE NOT NULL,
  exam_active INTEGER  DEFAULT 0,    -- 0 = false (ujian belum aktif), 1 = true (aktif)
  created_at  DATETIME DEFAULT CURRENT_TIMESTAMP,
  expires_at  DATETIME                            -- NULL = tidak ada expiry
);

-- Tabel admin_config: key-value store lama (dipertahankan untuk backward compat).
CREATE TABLE IF NOT EXISTS admin_config (
  key   TEXT PRIMARY KEY,
  value TEXT
);

-- Tabel app_config: konfigurasi global aplikasi (Satu Pintu via Backend).
-- Menyimpan URL Moodle, PIN Masuk (Admin), dan PIN Keluar Ujian.
-- Selalu hanya 1 baris (id=1). Default diinisialisasi di db.js.
CREATE TABLE IF NOT EXISTS app_config (
  id         INTEGER PRIMARY KEY,
  moodle_url TEXT    NOT NULL DEFAULT 'http://182.253.41.180/login/index.php',
  admin_pin  TEXT    NOT NULL DEFAULT '123456',
  exit_pin   TEXT    NOT NULL DEFAULT '123456'
);
