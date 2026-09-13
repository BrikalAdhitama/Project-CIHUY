# CIHUY — Control It, Hold Yourself

Aplikasi Android berbasis Flutter untuk membantu pengguna mencatat konsumsi rokok/vape, menghadapi craving, dan memantau target harian.

Saat ini repository berisi **frontend dengan data mock**. Backend dan penyimpanan permanen akan ditambahkan pada tahap berikutnya.

## Struktur

- `frontend_cihuy/`: aplikasi Flutter, aset, pengujian, dan konfigurasi Android.
- Backend akan ditambahkan ke `backend_cihuy/` setelah siap. Folder lokal tersebut sementara diabaikan Git.

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
