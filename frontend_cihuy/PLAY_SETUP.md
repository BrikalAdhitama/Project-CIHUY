# Setup rilis CIHUY

Setup kode tersedia. Upload key baru sudah dibuat untuk aplikasi baru ini. Package menggunakan `com.brikal.cihuy` (ditampilkan tersedia pada formulir Play Console); nama tampilan pengelola `CIHUY`. Email dukungan: `11231017@student.itk.ac.id`. Pembuatan AAB final menunggu URL kebijakan privasi dan URL permintaan hapus akun yang benar. Tidak ada AAB baru yang dibuat dalam setup ini.

## 1. Signing

Pada workspace ini, `android/upload-keystore.jks` dan `android/key.properties` sudah dibuat. Tidak perlu menjalankan ulang generator. Sertifikat publik dapat dibagikan dari `release-docs/upload-certificate.pem`; ini bukan private key.

Untuk aplikasi **baru** yang belum pernah diunggah, jalankan dari folder frontend:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tool/setup-upload-key.ps1 -CreateNewKey
```

Skrip membuat `android/upload-keystore.jks` dan `android/key.properties`, dengan password acak yang tidak dicetak. Keduanya diabaikan Git. Skrip menolak menimpa berkas yang sudah ada. Cadangkan keduanya di password manager/penyimpanan aman di luar repository sebelum upload pertama.

Untuk aplikasi yang sudah pernah diunggah, gunakan upload key yang terdaftar di Play Console dan isi `android/key.properties` mengikuti contoh. Jangan membuat pengganti secara sembarang. `storeFile` relatif terhadap `android/app/`; keystore pada `android/upload-keystore.jks` memakai `../upload-keystore.jks`.

Gradle kini menolak release tanpa konfigurasi signing lengkap; fallback debug sudah dihapus. Tidak perlu signing release untuk menjalankan debug.

## 2. Identitas dan tautan publik

Isi `release.local.json` (diabaikan Git) mengikuti `release.example.json`:

- `DEVELOPER_NAME`: nama pengelola sebenarnya.
- `SUPPORT_EMAIL`: sudah diisi `11231017@student.itk.ac.id` sesuai pilihan pengguna.
- `PRIVACY_POLICY_URL`: URL HTTPS kebijakan privasi yang dapat dibuka publik.
- `ACCOUNT_DELETION_URL`: URL HTTPS untuk meminta penghapusan akun tanpa memasang aplikasi.

Ringkasan privasi dapat dibuka dari login dan Pengaturan. Tombol ke situs dan kontak muncul jika konfigurasinya diisi. Ringkasan aplikasi tidak menggantikan kebijakan privasi lengkap. Draft naskah ada di `release-docs/`; lengkapi dan publikasikan dahulu. Jangan memakai URL contoh atau halaman yang hanya berisi placeholder.

## 3. Pemeriksaan

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tool/check-play-config.ps1
flutter --no-version-check analyze --no-pub
flutter --no-version-check test --no-pub
```

Skrip konfigurasi hanya memeriksa berkas/nilai lokal, tidak menghubungi layanan dan tidak membuktikan keystore/password cocok atau URL telah aktif. Skrip tidak mencetak password/key.

Verifikasi deployment fungsi `delete-account` dan migrasi/policy Supabase dengan akun uji. Verifikasi email/OTP, Google Sign-In, reset password, hapus akun, notifikasi lokal, dan catatan setelah restart. Push Firebase belum dikonfigurasi melalui berkas lokal; setup ini tidak mengaktifkan push server.

## 4. Build setelah seluruh prasyarat siap

```powershell
flutter build appbundle --release --dart-define-from-file=supabase.local.json --dart-define-from-file=release.local.json
```

Output nantinya: `build/app/outputs/bundle/release/app-release.aab`. Jangan gunakan AAB lama 17 November yang masih ditandatangani Android Debug. Gunakan versionCode yang belum pernah diunggah; saat ini versi source `1.0.0+1`.

Setelah Play App Signing aktif, daftarkan SHA-1 **app signing certificate Play** untuk OAuth Android `com.brikal.cihuy`. Upload key lokal dan app signing key Play dapat berbeda. Uji Google Sign-In dari instalasi track Play, bukan hanya APK lokal.

Package lama `com.cihuy.app` sudah digunakan menurut Play Console. `applicationId`, namespace, dan MainActivity kini memakai `com.brikal.cihuy`. Daftarkan OAuth client Android untuk package baru di Google Cloud; konfigurasi cloud belum diubah oleh setup lokal. Web Client ID Supabase tidak perlu diganti hanya karena package Android berubah jika tetap memakai project/provider yang sama. Jika Firebase push akan digunakan, daftarkan aplikasi Android baru dengan package ini. Keystore upload yang sudah dibuat tetap digunakan. Instalasi package baru adalah aplikasi terpisah dari package lama; data lokal versi lama tidak dipindahkan otomatis.

Lengkapi Data safety, Health apps declaration, akses reviewer, target audience, content rating, deklarasi iklan, dan store listing. Verifikasi AAB baru serta kompatibilitas 16 KB; hasil audit artefak lama tidak menggantikan pemeriksaan paket baru.

## Perubahan kode dalam setup

- Release tidak lagi memakai debug signing sebagai fallback.
- Penghapusan akun cloud membersihkan owner storage `supabase:<id>` setelah antrean save selesai, dan kegagalan cleanup lokal ditampilkan.
- Tombol hapus akun tersedia untuk akun cloud.
- Teks data lokal, logout, dan penghapusan disesuaikan dengan implementasi.
- Tes demo mengikuti alur keluar dari demo sebelum login; guard login saat sudah masuk tetap dipertahankan.
- Ditambahkan regresi pembersihan storage cloud dan save yang masih berlangsung.
- Lint kurung kurawal dibersihkan.

`PLAY_RELEASE_REVIEW.md` adalah catatan audit sebelum perbaikan, bukan status akhir implementasi.

## Hasil verifikasi setup — 19 November 2026

- `flutter --no-version-check analyze --no-pub`: tidak ada masalah.
- `flutter --no-version-check test --no-pub --reporter expanded`: 126 tes lulus.
- Keystore berhasil dibuka dengan password yang dihasilkan dan sertifikat publik berhasil diekspor. Subject: `CN=CIHUY Upload`, RSA 2048 bit.
- SHA-1 upload certificate: `43:56:3E:7B:D7:66:01:06:5E:AA:D7:5D:D8:16:02:41:13:B3:22:4F`. Ini bukan otomatis SHA-1 app signing certificate Play.
- `git check-ignore` mengonfirmasi keystore, key.properties, dan release.local.json diabaikan Git.
- Email dukungan sudah diisi; pemeriksaan konfigurasi tinggal menunggu dua URL publik.
- Task Gradle `:app:validateReleaseConfiguration` berhasil dikompilasi dan dijalankan; berhenti sesuai rancangan pada data kontak yang belum lengkap. Tidak membuat APK/AAB. Gradle masih mengeluarkan peringatan migrasi Kotlin/AGP untuk versi mendatang.
- Alur cloud/perangkat nyata dan publikasi halaman belum diverifikasi dalam setup ini.
- Setelah perubahan package ke `com.brikal.cihuy`, task Gradle `:app:compileDebugKotlin :app:processDebugMainManifest --offline` lulus (exit 0). Merged manifest debug memakai package baru dan target API 36. Pemeriksaan ini tidak membuat APK/AAB dan tidak memverifikasi login Google pada cloud.
