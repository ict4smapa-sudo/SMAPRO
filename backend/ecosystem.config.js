// =============================================================================
// File     : ecosystem.config.js
// Fungsi   : Konfigurasi PM2 untuk manajemen proses backend Exambro.
//             Auto-restart, monitoring, dan log management.
// Tanggal  : 27 Februari 2026
// PRD Ref  : Section 2.2, Section 3.2
// Perintah : pm2 start ecosystem.config.js
//             pm2 stop exambro-backend
//             pm2 logs exambro-backend
// =============================================================================

module.exports = {
  apps: [
    {
      // Nama proses — digunakan saat menjalankan perintah pm2 stop/restart/logs
      name: 'exambro-backend',

      // Entry point aplikasi Express
      script: 'app.js',

      // Working directory — path absolut ke folder backend di server
      // Sesuaikan dengan path aktual di Ubuntu Server saat deploy.
      cwd: './',

      // Jumlah instance: 'max' → sesuai jumlah core CPU (load balancing),
      // atau set ke 1 jika ingin single instance sederhana.
      instances: 1,

      // Auto-restart jika proses crash
      autorestart: true,

      // Watch file changes (nonaktifkan di production untuk performa)
      watch: false,

      // Batas memory sebelum pm2 restart proses secara otomatis
      max_memory_restart: '256M',

      // Variabel environment (dapat juga dibaca dari .env via dotenv di app.js)
      env: {
        NODE_ENV: 'production',
      },

      env_development: {
        NODE_ENV: 'development',
      },

      // Konfigurasi log
      log_date_format: 'YYYY-MM-DD HH:mm:ss',
      error_file: './logs/error.log',
      out_file: './logs/out.log',
      merge_logs: true,
    },
  ],
};
