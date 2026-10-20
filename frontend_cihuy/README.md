# CIHUY — Control It, Hold Yourself

Frontend Flutter Android dengan antarmuka Indonesia untuk mencatat konsumsi rokok/vape dan craving, mengatur target harian, serta melihat progres. Seluruh data masih berupa mock; backend akan dikembangkan terpisah.

## Menjalankan

Jalankan dari direktori ini dengan Flutter 3.38.5 / Dart 3.10.4 atau versi kompatibel dan Android SDK:

```powershell
cd frontend_cihuy
flutter pub get
flutter devices
flutter run -d <id-perangkat-android>
```

Untuk emulator yang tersedia pada komputer ini, jalankan `flutter emulators --launch Medium_Phone_API_36.0` terlebih dahulu, lalu `flutter run -d emulator-5554` setelah emulator siap.

Jika pemeriksaan versi SDK melalui internet tertahan, gunakan `flutter --no-version-check run -d <id-perangkat-android>`. Aplikasi sendiri tidak memerlukan internet. Package Android: `com.cihuy.app`; label aplikasi: **CIHUY**.

```powershell
dart format lib test
flutter analyze
flutter test
flutter build apk --debug
```

APK: `build/app/outputs/flutter-apk/app-debug.apk`.

## Yang tersedia

- Beranda: timer berdasarkan waktu konsumsi terbaru, current/best streak, rangkuman tujuh hari, motivasi, riwayat tanggal, target hari ini, dan tombol catat.
- Sheet pemilih catatan, tambah/edit konsumsi, serta tambah/edit craving dengan pemicu bebas dan hasil penanganan.
- Kalender Min–Sab, pemilihan bulan/tanggal, grafik tujuh hari yang berakhir pada tanggal pilihan, detail konsumsi/craving, lihat/edit/hapus dengan konfirmasi, serta detail progres.
- Profil, ganti/hapus foto dari galeri, edit nama/alasan, target aktif/terjadwal dan riwayat versi, nonaktifkan target, serta autentikasi lokal, pemulihan kata sandi dengan kode pemulihan, onboarding, keluar, dan hapus akun.
- Tiga tab mempertahankan state. Tombol kembali menutup modal/rute terlebih dahulu, kemudian kembali dari Kalender/Profil ke Beranda.

## Data demo dan aturan progres

Aplikasi baru membuka layar login. Pilih **Jelajahi demo dengan data terisi** untuk mengulang skenario demo, atau gunakan **Profil → Mode demo → Coba pengguna baru** saat sedang melihat demo. Pilihan tersebut meminta konfirmasi sebelum mengganti data sesi.

Autentikasi berjalan offline tanpa server, Firebase, Supabase, REST API, atau permintaan jaringan. Daftar akun disimpan lokal sebagai JSON melalui `shared_preferences`; password disimpan sebagai hash PBKDF2-HMAC-SHA256 dengan salt acak per akun, bukan plaintext. ID sesi disimpan melalui `flutter_secure_storage`. Status onboarding, nama, email, alasan, dan kode pemulihan (hanya hash) disimpan per akun. Kode pemulihan ditampilkan satu kali setelah registrasi dan setelah reset; kode lama diinvalidasi saat reset.

Data tracking demo dan catatan prototipe masih disimpan dalam memory dan hilang saat proses aplikasi dimulai ulang. Akun lokal bukan autentikasi production-ready: keamanan perangkat, backup, rate limiting, dan pemulihan lintas perangkat belum tersedia. Dependency pengembangan/debug Flutter dapat memakai internet saat setup dan debugging.

Seed dibuat sekali saat sesi/skenario dimulai dan memakai tanggal relatif terhadap hari ini. Pada 12 September, tanggal 7 berisi enam entri rokok masing-masing satu batang, dengan batas historis lima batang. Pada tanggal lain, skenario ini mengikuti hari kelima sebelum hari ini.

- Total harian menjumlahkan semua konsumsi pada tanggal kejadian. `total > batas` berarti melampaui batas; `5/5` masih memenuhi batas.
- Target berlaku sejak `startsOn` sampai sebelum `endsOn`. Edit menyimpan versi baru mulai hari ini atau tanggal mendatang; periode masa lalu tidak ditimpa. Nonaktifkan dari UI berlaku mulai besok (atau tanggal mulai target yang masih terjadwal).
- Rokok dan vape tidak dijumlahkan menjadi satu ukuran. Jika keduanya memiliki target, keduanya harus terpenuhi untuk keberhasilan harian.
- Hari ini yang belum selesai dan hari mendatang tidak dihitung berhasil. Hari ini yang sudah melampaui batas memutus current streak. Best streak tetap menghitung pencapaian sebelumnya.
- Koreksi/hapus catatan menghitung ulang seluruh progres. Membuka riwayat tidak mengubah timer atau streak.
- Timer berasal dari waktu kejadian konsumsi terbaru; jika kosong, dari waktu mulai berhenti. Timer memakai jam aktual sehingga tetap akurat setelah background. Craving tidak mereset timer. Hasil “Akhirnya konsumsi” hanya menawarkan formulir konsumsi terpisah, tanpa catatan otomatis.

## Perbedaan yang disengaja dari screenshot

- Bingkai ponsel, Dynamic Island, dan latar mockup tidak dibuat. Android memakai area sistemnya sendiri.
- Angka dihitung konsisten: demo awal memiliki **27 batang**, **7 craving**, **34 total entri**, **5 hari berhasil**, dan **current/best streak 4**. Angka “27 total catatan” dan “current streak 1” pada screenshot tidak dipaksakan.
- Status melebihi target memakai latar/teks merah serta **outline merah** saat dipilih, sesuai instruksi tambahan. Batang grafik merah berdasarkan data, termasuk saat tidak dipilih.
- Grafik memiliki angka dan satuan agar skala terbaca. Kalender/detail tambahan tetap bisa discroll.
- Tombol catat mendapat ruang tersendiri di atas navigasi agar tidak menimpa target. Sheet menyertakan tombol simpan dalam area scroll di atas keyboard.
- Ikon Kalender, Profil/nama, Craving ditahan, berhenti merokok, dan Rokok menggunakan lima SVG dari pengguna; ikon lainnya menggunakan Material Icons. Logo pada halaman akun dan ikon launcher Android menggunakan `assets/icon-app.png`; ikon launcher juga memiliki varian adaptive Android.
- Rangkuman Mingguan memakai label **Total konsumsi**. Jumlah rokok dan vape tetap dihitung terpisah.

## Foto profil

Buka **Profil → ketuk avatar → Pilih dari galeri**, lalu sesuaikan potongan foto pada layar crop. Setelah dikonfirmasi, foto mengganti inisial dan tetap ada saat berpindah tab atau mengedit nama. Pilihan **Hapus foto** mengembalikan inisial. Membatalkan galeri/crop atau gagal membaca foto mempertahankan foto sebelumnya.

Foto hanya berada dalam memory selama sesi mock: mulai ulang proses aplikasi, muat ulang demo, pengguna baru, atau hapus akun menghapus foto dari profil. Tidak ada unggahan ke server. Gambar dibatasi 1024×1024 sambil mempertahankan rasio, divalidasi, dan dibaca sebagai PNG. Pemilih galeri memakai [image_picker](https://pub.dev/packages/image_picker). Saat proses Android dimulai ulang, hasil pemilihan yang terputus dibuang agar tidak masuk ke akun demo baru; pengguna perlu memilih ulang. Tidak menambahkan izin kamera atau akses penyimpanan menyeluruh. SVG lokal ditampilkan dengan [flutter_svg](https://pub.dev/packages/flutter_svg).

## Mengganti logo

Ganti `assets/icon-app.png` lalu jalankan `dart run flutter_launcher_icons` dan build ulang. File asli dipertahankan; generator membuat ukuran launcher Android di `android/app/src/main/res/`. Konfigurasi berada di `pubspec.yaml`, mengikuti [dokumentasi flutter_launcher_icons](https://pub.dev/packages/flutter_launcher_icons).

## Struktur

`main.dart` menginisialisasi format tanggal lokal; `app.dart` mengatur tema, Provider dan navigasi. Model immutable berada di `models/`, data memory dan perhitungan murni di `services/`, state/CRUD di `providers/`, halaman di `screens/`, komponen/form reusable di `widgets/`, serta tema dan tanggal di `utils/`.

Lihat `VERIFICATION.md` untuk hasil pemeriksaan. Screenshot aplikasi pada emulator tersimpan di `artifacts/screenshots/`.
