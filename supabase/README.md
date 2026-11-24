# Setup Supabase CIHUY

Project baru: `https://pqxfzajzlzkmpchzlpwz.supabase.co`.
URL ini bukan secret. Flutter kini menyediakan login Google serta sesi/profil/baseline Supabase; lihat [panduan login Android](../frontend_cihuy/GOOGLE_LOGIN.md). Sinkronisasi catatan/target dan migrasi backend belum dilakukan. Backend saat ini masih memakai Firebase Auth + SQLite.

## 1. Buat tabel

Di dashboard **project baru** buka SQL Editor > New query. Salin seluruh isi `migrations/202611050001_initial_cihuy.sql`, lalu Run sebagai role postgres. Jalankan sekali. Hasil akhir menampilkan sembilan tabel dengan `rls_enabled = true`.

Skrip berjalan dalam transaksi dan tidak menghapus data/tabel lama. Jika nama tabel/schema sudah ada, skrip berhenti; jangan menambahkan DROP atau mengabaikan error untuk memaksanya. Jika terjadi error, simpan pesannya untuk diperiksa sebelum lanjut.

| ERD / fitur | Tabel |
|---|---|
| User (data profil) | profiles |
| Kebiasaan_Konsumsi | consumption_habits |
| Target_Harian | daily_targets |
| Catatan_Konsumsi | consumption_records |
| Catatan_Craving | craving_records |
| Pengaturan pengingat | notification_preferences |
| Token perangkat FCM | notification_devices |
| Penanda pengiriman | notification_deliveries |
| Konten motivasi tambahan | motivational_quotes |

Email, password dan identitas Google dikelola `auth.users`. Trigger membuat profil dan preferensi saat akun baru dibuat; data awal kebiasaan diisi saat onboarding. Tidak ada password_hash di tabel aplikasi. Foto akun Supabase disimpan di bucket private `photo-profil`; `profiles.avatar_url` menyimpan path relatif. Jalankan `photo_profil_storage.sql` untuk policy; panduan ada di `frontend_cihuy/PROFILE_PHOTO.md`.

## 2. Uji skema

Jalankan `tests/schema_smoke_test.sql` pada query baru sebagai postgres. Script menggunakan dua akun dummy dalam satu transaksi dan mengakhirinya dengan ROLLBACK. Tidak mengirim email atau push. Hasil yang diharapkan adalah satu baris `PASS: ... Fixtures rolled back.`. Jika error, jalankan `ROLLBACK;` bila sesi masih berada dalam transaksi gagal dan kirim error lengkap. Hanya jalankan di project baru/pengembangan.

Tes menguji trigger akun, isolasi akun dengan role authenticated, penolakan spoof user/habit, hak akses backend-only, validasi zona/jumlah, rentang target, 5/5, 6/5, koreksi 6 ke 5, dan unique claim pengiriman. Ini bukan pengujian login Google atau pengiriman FCM nyata. Migrasi dan tes belum dijalankan terhadap Supabase oleh agen; PostgreSQL lokal juga tidak tersedia saat penyiapan.

## 3. Aturan integrasi

- Setiap akun hanya dapat membaca/mengubah profil dan catatannya sendiri. Mode anonymous tidak mendapat akses tabel CIHUY. Pembuatan/hapus akun tetap melalui Supabase Auth; aplikasi tidak boleh menyimpan service-role/secret key.
- Rokok memakai `cigarette`/batang, vape memakai `vape`/hisapan; jenis kebiasaan tidak dapat diubah setelah dibuat. Nonaktifkan kebiasaan lewat `is_active` jika ingin menyimpan riwayatnya. Penghapusan kebiasaan menghapus target/catatan terkait melalui FK cascade.
- Target memakai rentang `[starts_on, ends_on)`, sesuai model Flutter. Saat target baru berlaku, tutup target lama dan masukkan versi baru dalam satu transaksi melalui backend/RPC yang akan dibuat saat integrasi. Tidak boleh mengubah semua riwayat menjadi batas terbaru. Rentang tumpang tindih ditolak database.
- Simpan waktu kejadian sebagai timestamptz. Hitung tanggal harian memakai zona pengguna, bukan tanggal UTC. Total, status harian, grafik dan streak harus berasal dari catatan yang sama; tidak ada kolom `relapse` atau total agregat yang disimpan terpisah. `total > daily_limit` berarti melampaui batas; sama dengan batas belum melampaui.
- Nilai konsumsi harus integer positif; batas dan baseline nonnegatif. Batas kewajaran input sesuai jenis kebiasaan tetap perlu ditentukan pada validasi produk; SQL ini tidak mengklaim mencegah seluruh angka yang tidak realistis.
- Backend wajib memverifikasi token Supabase dan menentukan user_id dari identitas tersebut. Tabel perangkat/delivery tidak dapat diakses langsung oleh Flutter, walaupun memakai publishable key dan login.
- Klaim pengiriman memakai unique `(user_id, device_id, kind, habit_kind, local_date)`. Backend harus insert sebelum mengirim dan melewati konflik. Gunakan ID instalasi stabil saat rotasi token. Kegagalan ambigu tidak boleh dicoba ulang tanpa strategi deduplikasi. SQL sendiri tidak menjalankan scheduler atau mengirim push. Peringatan batas lokal yang ada belum diubah.
- Preferensi jadwal per akun; token dapat mencakup beberapa perangkat. Jangan masukkan jumlah konsumsi, target atau craving ke teks push. Kutipan motivasi dikelola backend/admin dan dibaca pengguna hanya jika aktif.

## 3b. Hapus akun (wajib untuk Play Store)

Kebijakan Google Play mewajibkan aplikasi yang mengizinkan pembuatan akun menyediakan penghapusan akun di dalam aplikasi dan URL web untuk mengajukan penghapusan. Klien hanya memiliki publishable key, jadi penghapusan user auth dijalankan Edge Function `functions/delete-account`.

```powershell
supabase login
supabase link --project-ref pqxfzajzlzkmpchzlpwz
supabase functions deploy delete-account
```

Fungsi ini memverifikasi `Authorization: Bearer <access token>` melalui `auth.getUser()`, menghapus objek di bucket `photo-profil` milik pengguna, lalu menghapus user auth. Baris `profiles`, `consumption_habits`, `daily_targets`, `consumption_records`, `craving_records`, `notification_preferences`, `notification_devices`, dan `notification_deliveries` ikut terhapus melalui FK cascade. Tidak ada ID pengguna yang dibaca dari body request.

Jangan mengisi service role pada Flutter atau menyimpannya di repo; nilainya otomatis tersedia bagi Edge Function. Untuk URL web penghapusan, halaman sederhana yang menyebut alamat email dukungan sudah cukup, tetapi tautannya wajib aktif dan disebutkan di formulir Data Safety.

## 4. Login Google (setelah tabel berhasil)

Aktifkan provider Google pada Supabase Authentication. Callback project ini:

```text
https://pqxfzajzlzkmpchzlpwz.supabase.co/auth/v1/callback
```

Tambahkan callback tersebut di Authorized redirect URIs untuk OAuth client web Google. Masukkan Client ID/Client Secret di pengaturan provider Google **Supabase**, bukan dalam aplikasi Flutter. Aplikasi Flutter memakai native Google Sign-In dan menukar ID token ke Supabase, sehingga tidak memerlukan deep link callback. Daftarkan juga OAuth client Android untuk package `com.brikal.cihuy` dan SHA-1 build. Panduan langkah demi langkah ada di [GOOGLE_LOGIN.md](../frontend_cihuy/GOOGLE_LOGIN.md).

Untuk Flutter ambil **Project URL + publishable key** melalui Connect dan simpan bersama `GOOGLE_WEB_CLIENT_ID` di `frontend_cihuy/supabase.local.json` (diabaikan Git). FCM tetap memakai project Firebase; file `firebase.android.example.xml` berisi konfigurasi Firebase, bukan konfigurasi Supabase.

Referensi: [User management](https://supabase.com/docs/guides/auth/managing-user-data), [Data API grants/RLS](https://supabase.com/docs/guides/api/securing-your-api), [Google login](https://supabase.com/docs/guides/auth/social-sign-in/auth-google), [PostgreSQL range constraints](https://www.postgresql.org/docs/current/rangetypes.html).
