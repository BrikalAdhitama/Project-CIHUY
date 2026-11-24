# Template email autentikasi CIHUY

Enam template HTML siap disalin ke Supabase Dashboard. Warna mengikuti
`frontend_cihuy/lib/utils/app_theme.dart`. Setiap HTML berdiri sendiri,
memakai tabel dan CSS inline, tanpa gambar eksternal, JavaScript, atau font unduhan.

## Pasang di Supabase

1. Buka proyek yang digunakan aplikasi, lalu **Authentication > Emails > Templates**.
2. Pastikan Custom SMTP telah disimpan. Simpan kredensial SMTP hanya pada pengaturan Supabase.
3. Buka template sesuai tabel di bawah.
4. Isi **Subject** sesuai tabel, kemudian ganti seluruh isi **Body/Source** dengan isi file HTML terkait (tanpa pembungkus Markdown).
5. Periksa **Preview**, lalu klik **Save changes/Save**. Ulangi untuk enam template.
6. Pastikan **Confirm email** aktif di **Authentication > Sign In / Providers** untuk registrasi manual.

| Menu Supabase | Subject | File | Isi utama |
| --- | --- | --- | --- |
| Confirm sign up | Kode verifikasi pendaftaran CIHUY | [confirm-signup.html](confirm-signup.html) | Kode OTP |
| Invite user | Undangan bergabung ke CIHUY | [invite-user.html](invite-user.html) | Tautan konfirmasi |
| Magic link or OTP | Kode masuk ke akun CIHUY | [magic-link-or-otp.html](magic-link-or-otp.html) | Kode OTP |
| Change email address | Konfirmasi perubahan email CIHUY | [change-email-address.html](change-email-address.html) | Tautan konfirmasi |
| Reset password | Atur ulang kata sandi CIHUY | [reset-password.html](reset-password.html) | Tautan konfirmasi |
| Reauthentication | Kode konfirmasi keamanan CIHUY | [reauthentication.html](reauthentication.html) | Kode OTP |

Subject juga tersedia pada [subjects.json](subjects.json). File JSON tersebut
merupakan daftar referensi, bukan payload Management API atau konfigurasi yang otomatis diimpor.

## OTP dan masa berlaku

- **Confirm sign up** memakai `{{ .Token }}` untuk verifikasi registrasi email/password.
- **Magic link or OTP** memakai `{{ .Token }}` untuk permintaan login tanpa password, apabila fitur itu diimplementasikan.
- **Reauthentication** memakai `{{ .Token }}` untuk konfirmasi ulang identitas pada tindakan akun.
- Atur **Email OTP length** menjadi **6** sesuai rencana antarmuka aplikasi.
- Masa berlaku tetap mengikuti **Email OTP Expiration** di pengaturan provider Email.
  Nilai 300 berarti 5 menit; 600 berarti 10 menit.
- Template tidak menyebut angka menit agar tidak menampilkan durasi keliru saat pengaturan berubah.
- Supabase yang menghasilkan dan memvalidasi kode. Jangan mengganti `{{ .Token }}` dengan angka tetap.
- Mengedit template tidak mengaktifkan permintaan OTP pada setiap login dengan password atau Google.

## Template yang memakai tautan

**Invite user**, **Change email address**, dan **Reset password** memakai
`{{ .ConfirmationURL }}` bawaan Supabase. **Change email address** juga memakai
`{{ .NewEmail }}` dan teks yang sesuai untuk Secure email change, termasuk bila
konfirmasi diperlukan dari alamat lama serta alamat baru.

Sebelum memakai ketiga alur tersebut, konfigurasi **Authentication > URL Configuration**:
Site URL, redirect URL yang diizinkan, dan penanganan callback/deep link di aplikasi
harus cocok. Reset password perlu layar untuk memasukkan kata sandi baru setelah
sesi pemulihan diterima. Undangan perlu alur penerimaan undangan.
Jangan menganggap fitur-fitur itu selesai hanya karena emailnya sudah dipasang.

## Status integrasi dan pemeriksaan

File-file ini hanya menyiapkan isi email. Tidak ada perubahan dashboard otomatis,
pengiriman email percobaan, atau perubahan autentikasi Flutter dalam pekerjaan ini.

Saat template dibuat, registrasi manual aplikasi masih menggunakan
`LocalAuthRepository` (penyimpanan perangkat). Integrasi berikutnya harus menghubungkan
registrasi ke Supabase `signUp`, menampilkan layar OTP, memverifikasi token,
mengirim ulang konfirmasi, serta memakai login email/password Supabase.
Alur pemulihan dan callback tautan juga perlu diimplementasikan sebelum dipakai.

Pemeriksaan di dashboard dan saat integrasi:

1. Preview keenam template; pastikan label, subject, dan tombol sesuai dengan jenis email.
2. Setelah alur registrasi Supabase tersedia, gunakan alamat email uji yang kamu kendalikan.
3. Pastikan email registrasi berisi kode asli, bukan teks literal `{{ .Token }}`.
4. Pastikan sesi baru tersedia setelah verifikasi; uji kode salah, kedaluwarsa,
   kode yang sudah dipakai, dan batas pengiriman ulang.
5. Periksa inbox serta spam. Jika pengiriman gagal, lihat Auth logs dan konfigurasi SMTP.
6. Uji tautan undangan, perubahan email, dan reset password hanya setelah callback
   aplikasi serta redirect URL siap.

Referensi: [Supabase Email Templates](https://supabase.com/docs/guides/auth/auth-email-templates),
[Redirect URLs](https://supabase.com/docs/guides/auth/redirect-urls),
[Custom SMTP](https://supabase.com/docs/guides/auth/auth-smtp).
