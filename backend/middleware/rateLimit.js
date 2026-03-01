// =============================================================================
// File     : rateLimit.js
// Fungsi   : Middleware rate limiting untuk endpoint POST /api/validate.
//             Maksimal 5 request per IP per menit. HTTP 429 jika terlampaui.
// Tanggal  : 27 Februari 2026
// PRD Ref  : Section 2.3, Section 5.4
// =============================================================================

const rateLimit = require('express-rate-limit');

/**
 * Rate limiter untuk endpoint /api/validate.
 * PRD: Maksimal 5 request per IP per menit → blok 60 detik.
 * Jika terlampaui → HTTP 429 + JSON { message: "Terlalu banyak percobaan..." }
 */
const tokenValidateLimiter = rateLimit({
    // Window waktu: 1 menit (60.000 ms)
    windowMs: 60 * 1000,

    // Maksimal 5 request per IP dalam window tersebut
    max: 5,

    // Standarisasi header rate limit (RateLimit-* bukan X-RateLimit-*)
    standardHeaders: true,
    legacyHeaders: false,

    // Handler kustom saat limit terlampaui
    handler: (req, res) => {
        console.warn(`[RATE_LIMIT] IP ${req.ip} melampaui batas di ${req.path}`);
        res.status(429).json({
            message: 'Terlalu banyak percobaan. Tunggu 60 detik.',
        });
    },

    // Skip jika request berasal dari localhost (untuk testing lokal pengembang)
    skip: (req) => req.ip === '127.0.0.1' || req.ip === '::1',
});

module.exports = { tokenValidateLimiter };
