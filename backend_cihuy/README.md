# Notifikasi CIHUY

Backend baru, terpisah dari `frontend_cihuy`. Node.js 24+, SQLite (bawaan Node), Firebase Admin/FCM. API tidak menyimpan catatan konsumsi atau mengirim informasi kesehatan. Login lokal Flutter tetap tersedia; akun push dihubungkan secara eksplisit ke Firebase Auth. ID lokal, email dari request, dan akun fallback/hardcoded **bukan** otorisasi server.

## Konfigurasi

1. Buat Firebase project, daftarkan Android `com.brikal.cihuy`, aktifkan Firebase Authentication Email/Password dan Cloud Messaging API. Buat akun Firebase pengujian dengan email yang sama dengan akun lokal aplikasi. Menghubungkan push tidak otomatis memigrasikan akun/password lokal.
2. Salin `.env.example` menjadi `.env`. Isi `GOOGLE_CLOUD_PROJECT`. Untuk pengembangan, simpan service-account JSON di **luar repository**, isi `GOOGLE_APPLICATION_CREDENTIALS` dengan path absolutnya. Untuk deployment gunakan Application Default Credentials/workload identity. Berikan izin minimum mengirim FCM dan memverifikasi pengguna (termasuk pemeriksaan token dicabut).
3. Buat secret acak panjang (contoh `node -e "console.log(require('node:crypto').randomBytes(32).toString('hex'))"`) lalu isi `SCHEDULER_SECRET`. Secret ini hanya di backend/scheduler. Jangan masukkan ke APK, Firebase client config, URL, log, atau Git.
4. Jalankan dari folder backend:

```powershell
npm ci
Copy-Item .env.example .env
# Edit .env, kemudian:
npm start
```

File `.npmrc` mengecualikan dependensi opsional Firestore/Storage yang tidak dipakai. Instalasi runtime hanya memakai Firebase Admin Auth/Messaging; jalankan `npm audit --omit=optional` untuk memeriksa dependensi yang terpasang.

API default mendengarkan `127.0.0.1:8080`. Publikasikan melalui reverse proxy HTTPS dengan sertifikat sah, batas request, serta akses filesystem SQLite hanya untuk akun service. Flutter sengaja menolak HTTP. Untuk pengujian perangkat, gunakan endpoint HTTPS pengembangan yang meneruskan ke API lokal. Jangan membuka port SQLite atau folder data. Backup data backend sesuai kebijakan privasi; token perangkat adalah data yang harus dilindungi.

Tanpa project/credential yang valid, `/health` tetap tersedia dengan `configured:false` dan API notifikasi mengembalikan 503; aplikasi lokal tetap dapat dipakai. Setelah konfigurasi berubah, restart backend.

## Flutter

Salin `frontend_cihuy/firebase.example.json` menjadi `firebase.local.json`, lalu isi identifier client Firebase:

| Field | Sumber |
|---|---|
| `NOTIFICATION_API_URL` | Origin HTTPS backend, tanpa path tambahan |
| `FIREBASE_API_KEY` | `google-services.json`: `client[].api_key[].current_key` |
| `FIREBASE_APP_ID` | `client[].client_info.mobilesdk_app_id` untuk `com.brikal.cihuy` |
| `FIREBASE_MESSAGING_SENDER_ID` | `project_info.project_number` |
| `FIREBASE_PROJECT_ID` | `project_info.project_id` |

Identifier client ini bukan service-account secret. Firebase diinisialisasi melalui `FirebaseOptions`; tidak perlu memasukkan service-account JSON atau scheduler secret ke Flutter.

**Konfigurasi Android saat proses aplikasi belum berjalan:** salin `frontend_cihuy/firebase.android.example.xml` ke `frontend_cihuy/android/app/src/main/res/values/firebase_local.xml`. Isi `google_app_id`, `google_api_key`, `gcm_defaultSenderId`, dan `project_id` dengan nilai yang sama persis dengan `FIREBASE_APP_ID`, `FIREBASE_API_KEY`, `FIREBASE_MESSAGING_SENDER_ID`, dan `FIREBASE_PROJECT_ID` pada JSON. Build ulang setelah mengisi kedua file. Resource ini memungkinkan FirebaseInitProvider melakukan inisialisasi native sebelum kode Dart dijalankan; konfigurasi Dart saja tidak menyediakan resource native tersebut. Cara resource langsung didukung [dokumentasi Firebase Android](https://firebase.google.com/docs/projects/multiprojects#support_multiple_environments_in_your_android_application), tanpa tambahan plugin Gradle. Kedua file konfigurasi lokal diabaikan Git.

```powershell
cd ..\frontend_cihuy
flutter pub get
flutter run --dart-define-from-file=firebase.local.json
```

Tanpa file konfigurasi, `flutter run` tetap berjalan dan pengingat lokal tersedia. Pada **Profil → Notifikasi**, izinkan notifikasi Android, pilih jadwal, lalu aktifkan. Untuk push, hubungkan akun Firebase dan pilih mode push. Mode lokal dan push untuk pengingat/motivasi saling eksklusif agar satu jadwal tidak dikirim dari keduanya. Zona waktu mengikuti perangkat (IANA); saat berpindah zona, buka aplikasi agar jadwal tersinkronisasi.

## Penjadwalan backend

Jalankan `npm run dispatch` **setiap menit**, memakai cron, Windows Task Scheduler, atau scheduler terkelola. Proses ini mengirim POST terautentikasi ke `/internal/dispatch` memakai `SCHEDULER_SECRET`. Misalnya cron:

```cron
* * * * * cd /srv/cihuy/backend_cihuy && /usr/bin/npm run dispatch >> /var/log/cihuy-scheduler.log 2>&1
```

`DISPATCH_URL` default loopback; gunakan HTTPS jika scheduler berada di mesin berbeda. Endpoint internal juga sebaiknya dibatasi jaringan. Satu volume SQLite persisten harus dipakai API/worker yang sama; jangan menjalankan replika dengan database independen.

Pengiriman sesuai menit waktu lokal pengguna, tanpa mengejar jadwal yang terlewat. Unique claim SQLite mencakup UID, perangkat, jenis, dan tanggal lokal; pengubahan jadwal, worker bersamaan, restart, atau DST tidak mengirim ulang jenis yang sama pada tanggal itu. Claim ditulis **sebelum** menghubungi FCM. Kegagalan/hasil ambigu tidak dicoba ulang otomatis: ini mencegah kirim ganda tetapi dapat kehilangan satu pengiriman bila proses mati. FCM/OS tidak menjamin exactly-once. Token invalid dibuang; perangkat yang tidak tersinkronisasi selama 30 hari dilewati.

## API dan keamanan

- `PUT /v1/device`: Firebase ID token yang masih valid/dicabut diperiksa server. Mendaftarkan/merotasi token perangkat dan jadwal **milik UID token itu saja**.
- `DELETE /v1/device/:id`: hanya perangkat milik UID terautentikasi.
- `POST /v1/test`: hanya mengirim ke perangkat aktif pengguna sendiri, maksimum sekali/menit. Seluruh API pengguna dibatasi 60 request/menit/UID.
- `POST /internal/dispatch`: hanya scheduler secret; aplikasi tidak mengetahui secret ini.
- Payload FCM data-only: UID, jenis pengingat, delivery ID. Tidak ada jumlah konsumsi, target, craving, nama, atau email. Aplikasi memeriksa akun aktif dan preferensi sebelum menampilkan teks umum. Tidak menerima konten/tujuan navigasi arbitrer dari server.
- Logout/pergantian akun menonaktifkan penerimaan lokal, membatalkan pengingat, mencoba menghapus perangkat server dan token FCM. Jika offline, kegagalan server ditampilkan; handler tetap menolak pesan akun lama. Pesan yang sudah tampil sebelum logout dibersihkan.

## Batas harian terlampaui

Pemicu lokal setelah perubahan catatan hari ini; memakai `ProgressCalculator` dan target historis yang sama dengan kalender. **5/5 tidak memicu, 6/5 memicu sekali** per hari/jenis/akun. Tambahan berikutnya dan koreksi turun lalu naik tidak mengulang. Penanda disimpan di preferences sehingga bertahan setelah restart. Rokok/vape terpisah. Memuat riwayat/restart saat sudah di atas target tidak memicu; perubahan catatan historis tidak memicu. Pengguna dapat mematikan opsi ini. Ketukan membuka kalender tanggal kejadian; teks layar kunci tetap umum. Fitur ini tidak mengirim data konsumsi ke backend.

## Pengujian

```powershell
# backend
npm test
# frontend
flutter test test/notification_test.dart
flutter analyze --no-pub
flutter test --no-pub
```

Pada Android fisik dengan Google Play Services:

1. Jalankan tanpa konfigurasi: login lokal dan pengingat lokal harus tetap berfungsi. Tolak izin lalu aktifkan melalui Pengaturan Android dan coba lagi.
2. Atur pengingat beberapa menit ke depan; uji foreground, background, layar terkunci, reboot, dan aplikasi ditutup normal. Ketukan progres membuka Kalender, motivasi membuka Beranda.
3. Konfigurasikan Firebase/backend, hubungkan akun, aktifkan push, tekan **Kirim notifikasi uji**. Ulangi saat background dan aplikasi ditutup. Trigger scheduler dua kali pada menit yang sama: lihat satu claim pada tabel `deliveries`.
4. Uji logout, pergantian akun, token invalid/rotasi, mode lokal/push, dan opt-out. Push pengguna lain tidak boleh tampil.
5. Target 5: simpan total 5 (tanpa notif), naikkan 6 (sekali), lalu 7 (tidak lagi), koreksi 5 lalu 6 (tidak lagi). Ulangi dengan vape dan hari berikutnya. Data tracking masih mengikuti penyimpanan frontend yang sudah ada.

Pengingat lokal memakai alarm tidak eksak, tanpa izin exact-alarm. Android Doze/penghemat baterai dapat menunda pengiriman. Data-only FCM dipilih agar akun aktif dapat diperiksa sebelum tampilan; OS dapat menunda/menolak eksekusi background. **Force-stop Android memerlukan aplikasi dibuka kembali.** Fitur saat ini ditargetkan untuk Android karena proyek belum menyediakan iOS; belum ada konfigurasi APNs/iOS. Pengujian mock/unit bukan bukti push nyata terkirim; credential dan perangkat diperlukan untuk verifikasi tersebut.

Referensi: [FCM Flutter](https://firebase.google.com/docs/cloud-messaging/flutter/receive-messages), [Firebase Admin](https://firebase.google.com/docs/cloud-messaging/send/admin-sdk), [notifikasi lokal](https://pub.dev/packages/flutter_local_notifications/versions/19.5.0).

