# Verifikasi CIHUY

Lingkungan: Flutter 3.38.5, Dart 3.10.4, Android SDK 36, emulator Medium Phone API 36.0 (`emulator-5554`, 1080×2400, density 420).

- `flutter pub get`: berhasil.
- `dart format lib test`: berhasil.
- `flutter analyze`: **No issues found**.
- Unit/widget test: **105 lulus, 1 gagal yang sudah ada sebelumnya** (`test/session_restore_test.dart`, kegagalan hilangnya data demo saat masuk akun). Cakupan mencakup regresi tombol catat, foto profil/crop, posisi landscape, rentang grafik, serta satuan batang/bungkus.
- `flutter build apk --debug`: berhasil, APK terpasang dan aplikasi terbuka pada emulator.
- `dart run flutter_launcher_icons`: berhasil menghasilkan ikon Android biasa dan adaptive dari `assets/icon-app.png`. Aset yang sama dipakai pada halaman akun/onboarding, dan verifikasi diulang setelah pemasangannya.

## Cakupan otomatis

`test/progress_test.dart` memeriksa agregasi beberapa catatan, 5/5 vs 6/5, koreksi historis, notifikasi state, periode target historis, deactivation, pencegahan target retroaktif, perhitungan data vape lama yang tetap terpisah, target gabungan, hari ini/future, streak/best streak, timer berbasis waktu kejadian/background, CRUD konsumsi/craving, validasi, batas tengah malam, target nol, data kosong, seed, akun simulasi, dan pergantian bulan/tahun.

`test/pack_unit_test.dart` memeriksa bahwa hanya rokok yang ditawarkan untuk catatan baru, label "Vape (lama)" pada data lama, konversi bungkus ke batang (2 bungkus = 24 batang), pilihan satuan yang mereset jumlah ke 1, serta preferensi isi per bungkus yang tersimpan dan dipulihkan.

`test/widget_test.dart` memeriksa tiga tab, state tanggal, kembali Android, merah pada kalender/grafik/detail, outline merah, status merah tetap terlihat saat tanggal lain dipilih, edit lewat formulir dari 6 ke 5, penanda hari ini tidak menutupi merah, jumlah positif, pemicu lainnya, tidak ada konsumsi otomatis dari craving, pembatalan modal, onboarding, serta keyboard 300 px pada lebar 360 dan 430 logical pixels.

`test/profile_photo_test.dart` memeriksa pilih foto, cancel, kegagalan galeri, hapus kembali ke inisial, foto bertahan saat edit nama/alasan dan berganti tab, reset akun, hasil picker tertunda setelah ganti akun, pembuangan hasil pemilihan lintas sesi, serta menu foto pada landscape 844×390. Pengujian memakai picker pengganti dan gambar lokal, tanpa membuka galeri pribadi.

`test/profile_photo_picker_test.dart` memeriksa decoding gambar nyata, rasio 2048×1024 menjadi 1024×512, pembatalan galeri/crop, dan gambar rusak. Cropper diganti stub saat pengujian; interaksi crop native tidak dijalankan oleh tes tersebut. Lima SVG turut dimuat saat tes widget navigasi, beranda, formulir, dan profil.

## Pemeriksaan visual pada emulator

Ketujuh screenshot referensi terlihat dalam percakapan. Screenshot hasil aplikasi disimpan sebagai:

1. `artifacts/screenshots/01-beranda.png`
2. `artifacts/screenshots/02-pilih-catatan.png`
3. `artifacts/screenshots/03-catat-konsumsi.png`
4. `artifacts/screenshots/04-catat-craving.png`
5. `artifacts/screenshots/05-kalender.png`
6. `artifacts/screenshots/06-batas-terlampaui.png`
7. `artifacts/screenshots/07-profil.png`

Pemeriksaan nyata mencakup navigasi tiga tab, pembukaan/pembatalan kedua formulir, tombol kembali Android, tanggal 7 (grafik 1–7, outline merah, badge 6/5), dan tampilan profil. Pemeriksaan visual pertama menemukan tombol catat menimpa sebagian kartu target; posisi tombol diperbaiki dengan footer yang memiliki ruang layout sendiri.

Screenshot tambahan `08-target-tanpa-tumpang-tindih.png` memperlihatkan kartu target setelah digulir, dengan tombol catat di luar area konten. `09-keyboard-konsumsi.png` memperlihatkan keyboard Android asli saat mengetik. Field catatan/cara mengatasi memiliki jarak gulir tambahan untuk menyisakan ruang tombol simpan.

`10-ikon-android.png` memverifikasi ikon baru pada informasi aplikasi Android setelah APK dengan logo pengguna dipasang. Emulator tanpa jendela yang dipakai selama verifikasi ditutup setelah pemeriksaan selesai.

## Pembaruan 13 September 2026

Penempatan aset: `user-heart.svg` pada **Craving ditahan**, `user.svg` pada **Profil**, dan `smoking.svg` pada pilihan/riwayat/target Rokok. Label rangkuman menjadi **Total konsumsi**. Setelah perubahan ikon dan crop foto, analisis statis bersih, 39 tes lulus, dan APK debug berhasil dibangun.

APK terbaru berhasil dipasang (`adb install -r`: Success) dan dibuka pada perangkat Android fisik model 2406APNFAG yang terhubung melalui USB. Pemilihan foto dari galeri pribadi di perangkat diserahkan kepada pengguna; hasil otomatis di atas memakai picker pengganti. Screenshot emulator terdahulu belum mencakup ikon SVG dan fitur foto yang baru.

Build awal plugin Android mengalami kegagalan cache incremental Kotlin karena sumber plugin berada di C: dan proyek di D:, lalu berhasil lewat compiler fallback. `android/gradle.properties` kini menetapkan `kotlin.incremental=false` sesuai [dokumentasi Kotlin](https://kotlinlang.org/docs/gradle-compilation-and-caches.html); build ulang berhasil tanpa kegagalan cache tersebut. Perubahan ini mematikan optimasi kompilasi Kotlin, tidak memengaruhi perilaku runtime.

Tidak ada integrasi backend atau pengiriman email/notifikasi yang diuji karena seluruh alur tersebut berupa simulasi.
