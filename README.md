# Project-CIHUY

**CIHUY — Control It, Hold Yourself**

Aplikasi Android berbasis Flutter untuk membantu pengguna mencatat konsumsi rokok per batang atau per bungkus, menghadapi craving, dan memantau target harian.

Repository berisi aplikasi Flutter dan backend notifikasi terpisah. Tracking tetap mengikuti penyimpanan frontend yang ada; backend notifikasi tidak menyimpan catatan konsumsi.

## Struktur

- `frontend_cihuy/`: aplikasi Flutter, aset, pengujian, dan konfigurasi Android.
- `backend_cihuy/`: API notifikasi Node.js, Firebase Auth/FCM, SQLite, scheduler, dan pengujian.

## Menjalankan frontend

Diperlukan Flutter yang kompatibel dengan Dart 3.10.4, Android SDK, dan perangkat Android atau emulator.

```sh
cd frontend_cihuy
flutter pub get
flutter run
```

Untuk pemeriksaan kode dan pengujian:

```sh
flutter analyze
flutter test
```

Lihat [dokumentasi frontend](frontend_cihuy/README.md) dan [catatan verifikasi](frontend_cihuy/VERIFICATION.md) untuk fitur, aturan progres, serta batas mode mock.

## Menjalankan backend notifikasi

Diperlukan Node.js 24+. Lihat [panduan notifikasi](backend_cihuy/README.md) untuk konfigurasi Firebase, `.env`, HTTPS, pengujian perangkat, dan penjadwalan setiap menit.

```sh
cd backend_cihuy
npm ci
# Salin .env.example menjadi .env lalu isi konfigurasi backend.
npm start
# Jalankan per menit melalui scheduler, di proses terpisah:
npm run dispatch
```

Pengingat lokal tetap tersedia tanpa kredensial Firebase. Atur melalui Profil > Notifikasi. Secret pengiriman hanya disimpan di backend.
