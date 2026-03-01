// =============================================================================
// File     : token.js
// Fungsi   : Route POST /api/validate — validasi token ujian dari aplikasi Flutter.
//             Response JSON WAJIB sesuai kontrak PRD Section 5.3 (persis 100%).
//             Diproteksi dengan rate limiter 5 req/menit/IP.
// Tanggal  : 27 Februari 2026
// PRD Ref  : Section 5.2, Section 5.3
// KRITIS   : Format JSON response WAJIB { success, exam_active, server_time, message }.
//             Perubahan format sekecil apapun akan menyebabkan crash di Flutter
//             TokenResponse.fromJson().
// =============================================================================

const express = require('express');
const router = express.Router();
const db = require('../database/db');
const { tokenValidateLimiter } = require('../middleware/rateLimit');

// =============================================================================
// POST /api/validate
// Diproteksi rate limiter: maks 5 request per IP per menit.
// =============================================================================
router.post('/api/validate', tokenValidateLimiter, (req, res) => {
    // -------------------------------------------------------------------------
    // 1. Ambil token dari request body
    // -------------------------------------------------------------------------
    const { token } = req.body;

    // Validasi: token wajib ada dan bertipe string
    if (!token || typeof token !== 'string' || token.trim() === '') {
        return res.status(400).json({
            success: false,
            exam_active: false,
            server_time: new Date().toISOString(),
            message: 'Field "token" wajib diisi.',
        });
    }

    const trimmedToken = token.trim();

    // -------------------------------------------------------------------------
    // 2. Query database — cari token (synchronous, aman untuk better-sqlite3)
    // -------------------------------------------------------------------------
    try {
        const row = db
            .prepare('SELECT token, exam_active FROM tokens WHERE token = ?')
            .get(trimmedToken);

        const serverTime = new Date().toISOString();

        if (!row) {
            // Token tidak ditemukan di database
            console.log(`[VALIDATE] Token tidak ditemukan: ${trimmedToken.slice(0, 4)}***`);
            return res.status(200).json({
                success: false,
                exam_active: false,
                server_time: serverTime,
                message: 'Token tidak ditemukan',
            });
        }

        const isExamActive = row.exam_active === 1;

        if (!isExamActive) {
            // Token valid tapi ujian belum diaktifkan oleh pengawas
            console.log(`[VALIDATE] Token valid tapi ujian belum aktif: ${trimmedToken.slice(0, 4)}***`);
            return res.status(200).json({
                success: true,
                exam_active: false,
                server_time: serverTime,
                message: 'Ujian belum dimulai',
            });
        }

        // Token valid dan ujian aktif — izinkan masuk ke Moodle
        // Ambil konfigurasi global (moodle_url, admin_pin, exit_pin) dari app_config
        const config = db
            .prepare('SELECT moodle_url, admin_pin, exit_pin FROM app_config LIMIT 1')
            .get();

        console.log(`[VALIDATE] Token valid & aktif: ${trimmedToken.slice(0, 4)}***`);
        return res.status(200).json({
            success: true,
            exam_active: true,
            server_time: serverTime,
            message: 'Token valid',
            moodle_url: config?.moodle_url ?? null,
            admin_pin: config?.admin_pin ?? null,
            exit_pin: config?.exit_pin ?? null,
        });

    } catch (err) {
        // Error database — jangan crash server, tangani dengan anggun
        console.error('[VALIDATE] Database error:', err.message);
        return res.status(500).json({
            success: false,
            exam_active: false,
            server_time: new Date().toISOString(),
            message: 'Kesalahan server internal. Hubungi administrator.',
        });
    }
});

// =============================================================================
// POST /api/verify-exit
// Verifikasi Exit PIN secara real-time dari database.
// Tidak diproteksi rate limiter ketat — hanya dipakai saat sesion ujian aktif.
// Body: { "pin": "<nilai_pin>" }
// Response: { "success": true, "valid": true|false }
// =============================================================================
router.post('/api/verify-exit', (req, res) => {
    const { pin } = req.body;

    if (!pin || typeof pin !== 'string') {
        return res.status(400).json({ success: false, valid: false, message: 'Field "pin" wajib diisi.' });
    }

    try {
        const row = db.prepare('SELECT exit_pin FROM app_config LIMIT 1').get();

        if (!row || !row.exit_pin) {
            // Jika belum ada konfigurasi, tolak akses (aman by default)
            console.warn('[VERIFY-EXIT] app_config belum ada exit_pin.');
            return res.json({ success: true, valid: false });
        }

        const valid = pin.trim() === row.exit_pin.trim();
        console.log(`[VERIFY-EXIT] Percobaan PIN: ${valid ? 'VALID' : 'INVALID'}`);
        return res.json({ success: true, valid });

    } catch (err) {
        console.error('[VERIFY-EXIT] Database error:', err.message);
        return res.status(500).json({ success: false, valid: false, message: 'Kesalahan server.' });
    }
});

module.exports = router;
