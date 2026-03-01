// =============================================================================
// File     : admin.js
// Fungsi   : Route GET /admin (web panel HTML) dan CRUD token ujian.
//             Semua route diproteksi dengan middleware Basic Auth.
// Tanggal  : 27 Februari 2026
// PRD Ref  : Section 5.2
// Endpoints:
//   GET  /admin               — Halaman web admin panel (HTML)
//   POST /admin/token/add     — Tambah token baru
//   POST /admin/token/toggle  — Aktifkan/nonaktifkan token (exam_active)
//   POST /admin/token/delete  — Hapus token
// =============================================================================

const express = require('express');
const router = express.Router();
const path = require('path');
const db = require('../database/db');

// =============================================================================
// COOKIE-BASED AUTH MIDDLEWARE — Ganti Basic Auth Browser Popup
// Cek keberadaan cookie 'exambro_admin_auth=true' yang di-set saat POST /login.
// Jika tidak ada → redirect ke /login (Custom Login Page).
// Rute /api/validate TIDAK melewati middleware ini.
// =============================================================================
const adminAuthMiddleware = (req, res, next) => {
    const cookies = req.headers.cookie || '';
    // Regex memastikan exact match pada key dan value cookie.
    // Mencegah bypass via substring seperti 'fake_exambro_admin_auth=true'.
    const match = cookies.match(/(^|;)\s*exambro_admin_auth\s*=\s*true\s*(;|$)/);
    if (match) {
        return next();
    }
    return res.redirect('/login');
};

// Terapkan cookie auth ke semua route dalam file ini
router.use(adminAuthMiddleware);

// =============================================================================
// GET /admin — Sajikan halaman web admin panel
// =============================================================================
router.get('/admin', (req, res) => {
    res.sendFile(path.join(__dirname, '../views/admin.html'));
});

// =============================================================================
// POST /admin/token/add — Tambah token baru ke database
// Body: { token: "TOKEN_STRING" }
// =============================================================================
router.post('/admin/token/add', (req, res) => {
    const { token } = req.body;

    if (!token || typeof token !== 'string' || token.trim() === '') {
        return res.status(400).json({ success: false, message: 'Token tidak boleh kosong.' });
    }

    const trimmedToken = token.trim(); // Case-sensitive: tidak ada konversi uppercase

    try {
        const stmt = db.prepare(
            'INSERT INTO tokens (token, exam_active) VALUES (?, 0)'
        );
        stmt.run(trimmedToken);

        console.log(`[ADMIN] Token ditambahkan: ${trimmedToken}`);
        return res.status(201).json({
            success: true,
            message: `Token "${trimmedToken}" berhasil ditambahkan.`,
        });
    } catch (err) {
        // UNIQUE constraint gagal → token sudah ada
        if (err.code === 'SQLITE_CONSTRAINT_UNIQUE' || err.message.includes('UNIQUE')) {
            return res.status(409).json({
                success: false,
                message: `Token "${trimmedToken}" sudah ada di database.`,
            });
        }
        console.error('[ADMIN] Error tambah token:', err.message);
        return res.status(500).json({ success: false, message: 'Kesalahan server internal.' });
    }
});

// =============================================================================
// POST /admin/token/toggle — Toggle exam_active (0→1 atau 1→0)
// Body: { token: "TOKEN_STRING" }
// =============================================================================
router.post('/admin/token/toggle', (req, res) => {
    const { token } = req.body;

    if (!token) {
        return res.status(400).json({ success: false, message: 'Token wajib diisi.' });
    }

    try {
        // Toggle: jika saat ini 0 → set 1, jika 1 → set 0
        const stmt = db.prepare(
            'UPDATE tokens SET exam_active = CASE WHEN exam_active = 0 THEN 1 ELSE 0 END WHERE token = ?'
        );
        const result = stmt.run(token.trim());

        if (result.changes === 0) {
            return res.status(404).json({ success: false, message: 'Token tidak ditemukan.' });
        }

        // Ambil status baru untuk dikembalikan ke client
        const updated = db.prepare('SELECT exam_active FROM tokens WHERE token = ?')
            .get(token.trim());

        const newStatus = updated.exam_active === 1 ? 'AKTIF' : 'NON-AKTIF';
        console.log(`[ADMIN] Token di-toggle: ${token.trim()} → ${newStatus}`);

        return res.status(200).json({
            success: true,
            message: `Token berhasil diubah ke ${newStatus}.`,
            exam_active: updated.exam_active === 1,
        });
    } catch (err) {
        console.error('[ADMIN] Error toggle token:', err.message);
        return res.status(500).json({ success: false, message: 'Kesalahan server internal.' });
    }
});

// =============================================================================
// POST /admin/token/delete — Hapus token dari database
// Body: { token: "TOKEN_STRING" }
// =============================================================================
router.post('/admin/token/delete', (req, res) => {
    const { token } = req.body;

    if (!token) {
        return res.status(400).json({ success: false, message: 'Token wajib diisi.' });
    }

    try {
        const stmt = db.prepare('DELETE FROM tokens WHERE token = ?');
        const result = stmt.run(token.trim());

        if (result.changes === 0) {
            return res.status(404).json({ success: false, message: 'Token tidak ditemukan.' });
        }

        console.log(`[ADMIN] Token dihapus: ${token.trim()}`);
        return res.status(200).json({
            success: true,
            message: `Token "${token.trim()}" berhasil dihapus.`,
        });
    } catch (err) {
        console.error('[ADMIN] Error hapus token:', err.message);
        return res.status(500).json({ success: false, message: 'Kesalahan server internal.' });
    }
});

// =============================================================================
// GET /admin/tokens — Ambil semua token (untuk refresh tabel di HTML)
// =============================================================================
router.get('/admin/tokens', (req, res) => {
    try {
        const tokens = db.prepare(
            'SELECT id, token, exam_active, created_at FROM tokens ORDER BY created_at DESC'
        ).all();

        return res.status(200).json({ success: true, tokens });
    } catch (err) {
        console.error('[ADMIN] Error ambil tokens:', err.message);
        return res.status(500).json({ success: false, message: 'Kesalahan server internal.' });
    }
});

// =============================================================================
// GET /admin/config — Ambil konfigurasi global (moodle_url, admin_pin, exit_pin)
// =============================================================================
router.get('/admin/config', (req, res) => {
    try {
        const config = db
            .prepare('SELECT moodle_url, admin_pin, exit_pin FROM app_config LIMIT 1')
            .get();

        if (!config) {
            return res.status(404).json({ success: false, message: 'Konfigurasi belum ada.' });
        }

        return res.status(200).json({ success: true, config });
    } catch (err) {
        console.error('[ADMIN] Error ambil config:', err.message);
        return res.status(500).json({ success: false, message: 'Kesalahan server internal.' });
    }
});

// =============================================================================
// POST /admin/config — Simpan konfigurasi global
// Body: { moodle_url, admin_pin, exit_pin } — semua opsional (hanya yang ada yang diupdate)
// =============================================================================
router.post('/admin/config', (req, res) => {
    const { moodle_url, admin_pin, exit_pin } = req.body;

    // Validasi minimal: setidaknya satu field harus ada
    if (!moodle_url && !admin_pin && !exit_pin) {
        return res.status(400).json({ success: false, message: 'Tidak ada field yang dikirim.' });
    }

    try {
        // Pastikan baris default sudah ada (jika belum ada karena DB baru)
        const count = db.prepare('SELECT COUNT(*) as c FROM app_config').get();
        if (count.c === 0) {
            db.prepare(
                'INSERT INTO app_config (moodle_url, admin_pin, exit_pin) VALUES (?,?,?)'
            ).run(
                moodle_url || 'http://182.253.41.180/login/index.php',
                admin_pin || '123456',
                exit_pin || '123456'
            );
        } else {
            // Update baris yang ada (selalu id=1 / LIMIT 1)
            const setClauses = [];
            const params = [];

            if (moodle_url !== undefined) { setClauses.push('moodle_url = ?'); params.push(moodle_url.trim()); }
            if (admin_pin !== undefined) { setClauses.push('admin_pin = ?'); params.push(admin_pin.trim()); }
            if (exit_pin !== undefined) { setClauses.push('exit_pin = ?'); params.push(exit_pin.trim()); }

            db.prepare(`UPDATE app_config SET ${setClauses.join(', ')} WHERE id = 1`)
                .run(...params);
        }

        console.log('[ADMIN] app_config diperbarui.');
        return res.status(200).json({ success: true, message: 'Konfigurasi berhasil disimpan.' });
    } catch (err) {
        console.error('[ADMIN] Error simpan config:', err.message);
        return res.status(500).json({ success: false, message: 'Kesalahan server internal.' });
    }
});

module.exports = router;
