// =============================================================================
// File     : app.js
// Fungsi   : Entry point server Express Exambro SMAN 4 Jember.
//             Merangkai semua middleware dan route menjadi satu aplikasi.
// Tanggal  : 27 Februari 2026
// PRD Ref  : Section 3.2, Section 5
// Jalankan : node app.js  |  npm start  |  pm2 start ecosystem.config.js
// =============================================================================

// Load variabel environment dari .env sebelum require modul lain
require('dotenv').config();

const express = require('express');
const path = require('path');

// Inisialisasi database — eksekusi PRAGMA WAL dan schema.sql saat startup
require('./database/db');

// Import routes
const tokenRoutes = require('./routes/token');
const adminRoutes = require('./routes/admin');

// =============================================================================
// EXPRESS APP
// =============================================================================
const app = express();

// Middleware global: parsing JSON body dan URL-encoded form
app.use(express.json());
app.use(express.urlencoded({ extended: false }));

// =============================================================================
// STATIC FILES — Assets Flutter (SSOT Logo)
// Ekspos folder assets/ dari root proyek agar bisa diakses via /assets/...
// Digunakan oleh login.html dan admin.html untuk menampilkan logo sekolah.
// =============================================================================
app.use('/assets', express.static(path.join(__dirname, '../assets')));

// Log setiap request yang masuk (ringkas, untuk monitoring di PM2 logs)
app.use((req, res, next) => {
    const ts = new Date().toISOString().replace('T', ' ').slice(0, 19);
    console.log(`[${ts}] ${req.method} ${req.path} — IP: ${req.ip}`);
    next();
});

// =============================================================================
// ROUTES
// =============================================================================

// Token validation route — prefix '/' → endpoint: POST /api/validate
// Rate limiter diterapkan di dalam routes/token.js
app.use('/', tokenRoutes);

// =============================================================================
// AUTH ROUTES — Login & Logout (Cookie-based Auth)
// Tidak memerlukan middleware — rute publik yang menghasilkan/menghapus cookie.
// /api/validate TIDAK termasuk di sini → tetap bebas diakses siswa.
// =============================================================================

// GET /login — Sajikan halaman login HTML
app.get('/login', (req, res) => {
    res.sendFile(path.join(__dirname, 'views/login.html'));
});

// POST /login — Verifikasi password, set session cookie jika benar
app.post('/login', (req, res) => {
    const { password } = req.body;
    const adminPassword = process.env.ADMIN_PASSWORD || 'admin';

    if (password === adminPassword) {
        // Set cookie HttpOnly selama 24 jam (Max-Age = 86400 detik)
        res.setHeader(
            'Set-Cookie',
            'exambro_admin_auth=true; HttpOnly; Path=/; Max-Age=86400'
        );
        return res.redirect('/admin');
    }

    // Password salah — redirect ke login dengan query error
    return res.redirect('/login?error=1');
});

// GET /logout — Hapus cookie lalu redirect ke halaman login
app.get('/logout', (req, res) => {
    res.setHeader(
        'Set-Cookie',
        'exambro_admin_auth=; HttpOnly; Path=/; Max-Age=0'
    );
    return res.redirect('/login');
});

// Admin panel routes — prefix '/' → endpoints: GET /admin, POST /admin/token/*
// Cookie-based Auth middleware diterapkan di dalam routes/admin.js
app.use('/', adminRoutes);

// =============================================================================
// HEALTH CHECK — digunakan oleh PM2 / monitoring untuk verifikasi server UP
// =============================================================================
app.get('/health', (req, res) => {
    res.status(200).json({
        status: 'ok',
        app: 'Exambro SMAN 4 Jember Backend',
        version: '2.0.0',
        timestamp: new Date().toISOString(),
    });
});

// =============================================================================
// 404 HANDLER — Route tidak ditemukan
// =============================================================================
app.use((req, res) => {
    res.status(404).json({ message: 'Endpoint tidak ditemukan.' });
});

// =============================================================================
// GLOBAL ERROR HANDLER — Tangkap semua unhandled error dari route handlers
// Mencegah server Node.js crash karena uncaught exception.
// =============================================================================
// eslint-disable-next-line no-unused-vars
app.use((err, req, res, next) => {
    console.error('[SERVER_ERROR]', err.stack || err.message);
    res.status(500).json({
        success: false,
        message: 'Kesalahan server internal. Hubungi administrator.',
    });
});

// =============================================================================
// START SERVER
// =============================================================================
const PORT = process.env.PORT || 3000;

app.listen(PORT, '0.0.0.0', () => {
    console.log('='.repeat(60));
    console.log(` Exambro Backend v2.0 — SMAN 4 Jember`);
    console.log(` Server berjalan di: http://0.0.0.0:${PORT}`);
    console.log(` Admin panel      : http://0.0.0.0:${PORT}/admin`);
    console.log(` Health check     : http://0.0.0.0:${PORT}/health`);
    console.log(` NODE_ENV         : ${process.env.NODE_ENV || 'development'}`);
    console.log('='.repeat(60));
});
