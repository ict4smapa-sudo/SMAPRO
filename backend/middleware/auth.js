// =============================================================================
// File     : auth.js
// Fungsi   : Middleware Basic Auth untuk melindungi endpoint /admin web panel.
//             Membaca password dari process.env.ADMIN_PASSWORD (via .env).
// Tanggal  : 27 Februari 2026
// PRD Ref  : Section 5.2, Section 3.2
// =============================================================================

/**
 * Middleware Basic Auth sederhana untuk melindungi semua route /admin.
 *
 * Format header Authorization yang diharapkan:
 *   Authorization: Basic <base64(username:password)>
 *
 * Username diabaikan — hanya password yang dicocokkan dengan ADMIN_PASSWORD.
 * Jika header tidak ada atau password salah → HTTP 401 + WWW-Authenticate header.
 */
function basicAuth(req, res, next) {
    const authHeader = req.headers['authorization'] || '';

    if (!authHeader.startsWith('Basic ')) {
        // Tidak ada header Authorization atau bukan Basic
        return _unauthorizedResponse(res);
    }

    // Decode base64 → "username:password"
    const base64 = authHeader.slice(6); // hapus prefix "Basic "
    const decoded = Buffer.from(base64, 'base64').toString('utf-8');
    const colonIndex = decoded.indexOf(':');

    if (colonIndex === -1) {
        return _unauthorizedResponse(res);
    }

    // Ambil password (bagian setelah titik dua pertama)
    const password = decoded.slice(colonIndex + 1);
    const expectedPassword = process.env.ADMIN_PASSWORD;

    if (!expectedPassword || password !== expectedPassword) {
        console.warn(`[AUTH] Percobaan akses admin gagal dari IP: ${req.ip}`);
        return _unauthorizedResponse(res);
    }

    // Auth berhasil → lanjut ke handler berikutnya
    next();
}

/**
 * Mengembalikan response HTTP 401 dengan WWW-Authenticate header
 * agar browser menampilkan dialog login native.
 */
function _unauthorizedResponse(res) {
    res.setHeader('WWW-Authenticate', 'Basic realm="Exambro Admin Panel"');
    return res.status(401).json({ message: 'Unauthorized — Akses admin memerlukan autentikasi.' });
}

module.exports = { basicAuth };
