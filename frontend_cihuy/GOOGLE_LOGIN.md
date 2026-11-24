# Login Google CIHUY (Android)

Konfigurasi lokal: `supabase.local.json`, diabaikan Git. Isi `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`, dan `GOOGLE_WEB_CLIENT_ID`. Gunakan ID OAuth **Web**, bukan ID OAuth Android, client secret, atau Supabase secret key. Secret backend tidak diperlukan untuk login ini.

Jalankan dari folder `frontend_cihuy`:

```powershell
flutter pub get
flutter run --dart-define-from-file=supabase.local.json
```

Build Android juga membaca `supabase.local.json` secara otomatis bila nilai tersebut belum diberikan lewat command line, sehingga `flutter run` biasa tetap dapat memakai Google Sign-In pada mesin ini. Cara eksplisit di atas tetap disarankan agar konfigurasi tidak bergantung pada perilaku Gradle. Jika FCM juga sudah dikonfigurasi, tambahkan `--dart-define-from-file=firebase.local.json`. Setelah nilai berubah, hentikan aplikasi lalu jalankan ulang; hot reload tidak mengganti dart defines.

Pesan **“Login Google belum tersedia pada versi aplikasi ini”** berarti build tidak memiliki ketiga nilai konfigurasi di atas. Periksa `supabase.local.json` dan jalankan ulang dengan perintah di atas.

## Prasyarat Google/Supabase

- Project Supabase sudah memiliki migrasi `supabase/migrations/202611050001_initial_cihuy.sql` beserta trigger profil; jalankan smoke test-nya.
- Provider **Google** aktif di Supabase Authentication. Isi Client ID dan Client Secret dari OAuth client **Web** yang sama; secret hanya disimpan di dashboard Supabase.
- Di Google Cloud, buat OAuth client **Web application** dan tambahkan authorized redirect URI `https://<project-ref>.supabase.co/auth/v1/callback`.
- Buat OAuth client **Android** dengan package `com.brikal.cihuy` dan SHA-1 sertifikat build yang dipakai. Sertifikat debug komputer ini: `79:82:D7:BA:03:7B:99:F1:B1:EB:EB:88:1F:C6:AD:83:D7:80:94:15`. Sertifikat upload lokal: `43:56:3E:7B:D7:66:01:06:5E:AA:D7:5D:D8:16:02:41:13:B3:22:4F`. Untuk instalasi dari Play, daftarkan juga SHA-1 **app signing certificate Play**; sertifikat ini bisa berbeda dari upload key. Client Android untuk package lama tidak otomatis berlaku untuk package baru. Konfigurasi Google Cloud belum diperbarui melalui perubahan kode ini.
- Jika Google Auth Platform masih Testing, email penguji masuk daftar **Test users**. Gunakan perangkat/emulator dengan Google Play Services.
- Google Sign-In memakai pemilih akun native dan pertukaran ID token ke Supabase; alur ini tidak memerlukan callback browser/deep link Android. Sesi Supabase disimpan melalui Flutter Secure Storage, bukan berkas konfigurasi.
- Jangan menaruh client secret, service-role key, atau secret Supabase di aplikasi. `GOOGLE_WEB_CLIENT_ID` dan publishable key memang boleh ada di client.

## Uji di perangkat

1. Buka aplikasi, tekan **Lanjutkan dengan Google**, pilih akun. Pengguna baru masuk onboarding; profil dan baseline tersimpan ke Supabase.
2. Batalkan pemilih akun: tetap di login tanpa membuat akun lokal/demo.
3. Tutup lalu buka aplikasi: sesi dan profil akun yang sama dipulihkan (memerlukan koneksi untuk validasi/pembacaan profil).
4. Edit nama/alasan, tutup dan buka lagi; nilai tetap tersimpan. Putuskan koneksi ketika menyimpan: formulir menampilkan kegagalan dan tidak mengklaim berhasil.
5. Logout lalu login dengan akun Google berbeda: profil dan data sesi akun sebelumnya tidak terbawa.

## Batas tahap ini

Login Google, profil, alasan, baseline, status onboarding dan sesi sudah terhubung ke Supabase. Foto profil akun Google sudah terhubung ke Storage setelah policy pada `supabase/photo_profil_storage.sql` diterapkan; lihat `PROFILE_PHOTO.md`. Catatan konsumsi/craving dan target masih mengikuti penyimpanan sementara aplikasi; belum disinkronkan ke tabel baru. Pendaftaran email/password dan kode pemulihan lama masih **lokal**, belum memakai Supabase/OTP. Hapus akun cloud belum tersedia; UI tidak menawarkan penghapusan lokal seolah-olah menghapus akun Supabase. Kata sandi akun Google dikelola Google.

Pengingat lokal tetap dapat digunakan. Akun Google tidak ditawarkan login Firebase kedua; pengiriman push untuk akun Supabase menunggu integrasi backend. Backend yang ada masih Firebase Auth + SQLite. Tidak ada kredensial pengiriman atau Supabase secret key dalam Flutter.

Jika tombol Google tidak tampil, periksa ketiga field konfigurasi dan perintah dart-define. Untuk error sesudah memilih akun, periksa package/SHA-1, Web Client ID, provider Google, akun penguji dan koneksi. Konfigurasi publik tidak membuktikan keberhasilan login: tes perangkat masih diperlukan.

Referensi: [Google Sign-In Android](https://pub.dev/packages/google_sign_in_android), [Supabase signInWithIdToken](https://supabase.com/docs/reference/dart/auth-signinwithidtoken), [Secure session storage](https://pub.dev/packages/supabase_flutter#custom-localstorage).

## Hasil verifikasi implementasi

- Seluruh suite Flutter lulus, termasuk tes UI login/registrasi dan dialog pemulihan.
- `flutter analyze --no-pub`: tidak ada masalah.
- `flutter build apk --debug`: berhasil, dan konfigurasi Supabase/OAuth terbaca dari `supabase.local.json` pada build Android.
- Endpoint pengaturan Auth project dapat dihubungi dan provider Google aktif; tidak membuat akun atau membaca catatan pengguna.
- Login Google end-to-end pada perangkat fisik/emulator dengan akun Google tetap perlu diuji manual karena memerlukan pemilih akun dan Google Play Services.
