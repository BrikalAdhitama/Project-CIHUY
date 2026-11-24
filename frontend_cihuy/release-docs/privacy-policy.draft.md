# DRAFT — Kebijakan Privasi CIHUY

Belum untuk dipublikasikan: lengkapi seluruh isian dalam tanda kurung siku dan cocokkan dengan layanan produksi.

Pengelola: CIHUY. Kontak privasi: 11231017@student.itk.ac.id. Berlaku sejak: [TANGGAL PUBLIKASI].

CIHUY (Control It, Hold Yourself) membantu pengguna mencatat konsumsi rokok, keinginan merokok, dan target harian.

## Data dan tujuan

Email, identitas akun, nama, alasan berhenti merokok, konsumsi awal, status onboarding, serta foto profil yang dipilih diproses untuk menyediakan autentikasi dan profil. Supabase menyediakan autentikasi, database profil, serta penyimpanan foto. Jika memilih masuk dengan Google, autentikasi juga diproses oleh Google.

Catatan konsumsi, craving, dan target harian disimpan pada perangkat per akun. Versi saat ini belum menyinkronkan catatan tersebut ke cloud. Catatan dapat hilang jika data aplikasi dihapus atau aplikasi dicopot. Ekspor menyalin laporan ke papan klip atas tindakan pengguna; salinan di luar aplikasi dikelola pengguna.

Izin notifikasi digunakan untuk pengingat. Foto dipilih pengguna melalui pemilih foto untuk profil. [KONFIRMASI: apakah push Firebase akan diaktifkan pada paket rilis? Jika aktif, jelaskan token perangkat, data autentikasi tambahan, pengaturan/jadwal, penyedia backend, tujuan, dan retensinya.]

## Penyedia layanan dan keamanan

Data yang diperlukan diteruskan ke penyedia layanan di atas untuk menjalankan fiturnya. Komunikasi layanan menggunakan HTTPS; sesi autentikasi disimpan melalui penyimpanan aman perangkat. [LENGKAPI lokasi pemrosesan/penyimpanan serta praktik log, analytics, dan backup yang benar-benar diterapkan.]

## Penyimpanan dan penghapusan

Pengguna dapat menghapus akun melalui Pengaturan > Hapus akun, atau meminta penghapusan melalui [URL PERMINTAAN HAPUS AKUN]. Penghapusan akun mencakup akun autentikasi, profil, dan foto di layanan aplikasi. Alur penghapusan dalam aplikasi juga membersihkan catatan lokal pada perangkat yang digunakan. Catatan pada perangkat lain dan salinan ekspor harus dihapus terpisah oleh pengguna.

Pengaturan > Hapus semua data mengosongkan catatan dan target pada perangkat tanpa menghapus akun. [ISI batas waktu pemrosesan permintaan web, verifikasi kepemilikan, masa retensi log/backup, serta pengecualian retensi jika ada. Jangan menjanjikan waktu penghapusan yang belum dapat dipenuhi.]

## Kontak dan perubahan

Pertanyaan atau permintaan terkait data dapat dikirim ke 11231017@student.itk.ac.id. Perubahan kebijakan akan diumumkan melalui [MEKANISME YANG DIGUNAKAN].
