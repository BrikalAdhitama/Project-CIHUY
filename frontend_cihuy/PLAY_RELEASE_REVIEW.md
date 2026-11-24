# Audit sebelum upload Google Play

Tanggal: 19 November 2026 (Asia/Makassar).

> Pembaruan setup: upload keystore baru sudah dibuat; fallback debug dihapus;
> bug kunci catatan hapus akun dan alur tes demo sudah diperbaiki; akses
> privasi serta tombol hapus akun cloud tersedia. Lihat [PLAY_SETUP.md](PLAY_SETUP.md)
> untuk status dan langkah terkini. Temuan di bawah dipertahankan sebagai
> rekaman audit sebelum perbaikan. Kontak dan halaman publik masih perlu dilengkapi.
> Package rilis kini `com.brikal.cihuy`; referensi `com.cihuy.app` di audit
> berikut menjelaskan source/artefak lama yang diperiksa saat itu.

**Status: belum siap untuk paket upload final.** Audit dilakukan pada working tree saat ini, termasuk perubahan yang belum di-commit. Tidak ada kode aplikasi yang diubah atau paket baru yang dibuat. Artefak lama hanya dibaca; hasil pemeriksaannya tidak membuktikan bahwa source terbaru berhasil dibangun.

## Temuan yang harus diselesaikan

### 1. AAB yang ada ditandatangani debug key

- `android/key.properties` belum tersedia.
- `android/app/build.gradle.kts:124–131` memakai signing debug ketika konfigurasi release belum lengkap.
- Pemeriksaan `keytool -printcert -jarfile build/app/outputs/bundle/release/app-release.aab` menghasilkan `CN=Android Debug, O=Android, C=US`.
- Artefak tersebut bertanggal 17 November 2026, ukuran 64.486.708 byte, dan tidak layak dipakai sebagai paket upload Play.

Tindakan: siapkan upload keystore, konfigurasi release signing, dan hentikan build distribusi jika konfigurasi signing tidak lengkap. Simpan serta cadangkan keystore/password secara aman di luar Git. Untuk Google Sign-In dari instalasi Play, daftarkan package `com.cihuy.app` dan SHA-1 **app signing certificate milik Play**, bukan hanya sertifikat debug atau upload key. Status OAuth di Google Cloud belum diperiksa.

Referensi: [Android app signing](https://developer.android.com/studio/publish/app-signing).

### 2. Kebijakan privasi dan jalur penghapusan via web belum ditemukan

Pencarian source dan layar autentikasi, Pengaturan, serta Tentang tidak menemukan halaman/tautan kebijakan privasi. Repository juga belum menyediakan halaman publik untuk meminta penghapusan akun. Keberadaan situs terpisah di luar repository belum diketahui.

Tindakan: sediakan URL kebijakan privasi publik dan aksesnya dari aplikasi; sediakan URL permintaan penghapusan akun yang dapat digunakan tanpa memasang aplikasi. Jelaskan pengelola/kontak, data yang diproses, tujuan, penyedia layanan, retensi, serta penghapusan sesuai implementasi sebenarnya. Siapkan Data safety berdasarkan aliran data yang nyata.

Referensi: [User Data](https://support.google.com/googleplay/android-developer/answer/10144311), [account deletion](https://support.google.com/googleplay/android-developer/answer/13327111).

### 3. Hapus akun cloud tidak membersihkan kunci catatan lokal yang benar

- `lib/providers/app_state.dart:107` menghasilkan owner cloud `supabase:<id>`.
- `_scheduleSave()` dan `_loadRecords()` memakai owner tersebut (`:683`, `:700`).
- `deleteAccount()` memanggil `_recordsStore.clear(account.id)` (`:1116`), tanpa awalan `supabase:`.
- Akibatnya, salinan catatan lokal akun cloud dapat tetap tersimpan setelah penghapusan akun. Ini temuan dari penelusuran kode; tes yang ada hanya memeriksa panggilan server dan penutupan sesi.

Tindakan: gunakan identitas penyimpanan yang sama ketika menghapus, pastikan antrean penyimpanan selesai sebelum pembersihan agar data tidak tertulis kembali, dan tambahkan regresi yang memeriksa storage sesudah penghapusan. Verifikasi penghapusan profil/foto/akun di Supabase dengan akun uji; keberadaan file `supabase/functions/delete-account/index.ts` belum membuktikan fungsi telah di-deploy.

### 4. Suite Flutter belum lulus penuh

`flutter --no-version-check test --no-pub --reporter expanded`: **123 lulus, 1 gagal**.

Tes gagal: `test/session_restore_test.dart:125`, `masuk dari store demo tidak membocorkan data demo ke akun`. Diharapkan email akun uji Sari, tetapi profil masih milik demo Budi. Pengulangan tes tersebut secara terpisah menghasilkan kegagalan yang sama.

Penyebab yang terlihat: `startDemo()` menetapkan `signedIn = true`, sedangkan `authenticate()` langsung kembali jika `signedIn` aktif. Skenario tes melakukan login langsung dari demo. Tentukan alur yang diinginkan: keluar dari demo dahulu atau mendukung transisi langsung. Temuan ini bukan bukti kebocoran antar akun produksi; autentikasi lokal di tes menggunakan repository yang diinjeksi.

`flutter --no-version-check analyze --no-pub`: exit 1, **10 temuan tingkat info**, seluruhnya `curly_braces_in_flow_control_structures`; tidak dilaporkan error/warning analisis. Lokasi: `lib/app.dart:45`, `lib/providers/app_state.dart:223,279,842,845,865,868`, `lib/services/google_auth_repository.dart:408`, `lib/widgets/daily_consumption_warning.dart:18`, dan `test/avatar_upload_test.dart:109`.

## Perilaku data yang perlu dijelaskan dengan benar

- Autentikasi produksi menggunakan Supabase. Profil, alasan, baseline, dan foto memakai layanan cloud.
- Catatan konsumsi, craving, dan target disimpan lokal per akun melalui `RecordsStore`/SharedPreferences; belum ada sinkronisasi catatan ke Supabase pada jalur yang diperiksa.
- Uninstall atau clear app data dapat menghapus catatan lokal. Login pada perangkat lain tidak otomatis memulihkannya.
- Dialog hapus akun cloud di `lib/screens/settings_screen.dart:22` menyebut seluruh catatan di server, sehingga perlu disesuaikan dengan implementasi lokal saat ini.
- Kegagalan penyimpanan catatan ditelan di `_scheduleSave()` tanpa pemberitahuan; pengguna dapat melihat data tersimpan di UI tetapi kehilangan perubahan setelah aplikasi dimulai ulang jika penyimpanan gagal.
- README dan GOOGLE_LOGIN.md masih memuat keterangan lama tentang autentikasi lokal, data sementara, dan ketiadaan hapus akun cloud. Jangan memakai dokumentasi tersebut langsung sebagai deskripsi rilis atau dasar Data safety.
- Konfigurasi Supabase/OAuth lokal berisi tiga field yang diperlukan; nilai rahasia tidak dicetak. Keberadaan konfigurasi belum membuktikan login produksi berhasil.
- `firebase.local.json` dan resource native `firebase_local.xml` tidak tersedia. Push belum terkonfigurasi melalui berkas lokal yang didokumentasikan; pengingat lokal merupakan jalur terpisah. Jangan menjanjikan push server sebelum diuji.

## Pemeriksaan yang sudah memberikan hasil baik

| Pemeriksaan | Hasil dan batasnya |
| --- | --- |
| Backend `npm.cmd test` | 8/8 tes lulus; bukan uji pengiriman FCM nyata. |
| Identitas Android | `com.cihuy.app`, label CIHUY, versi `1.0.0+1`. Ketersediaan package/versionCode di Console belum diperiksa. |
| SDK | Flutter lokal 3.47.7 / Dart 3.13.5; compile SDK 37; target SDK 36; minimum SDK 24. Target 36 juga terlihat pada merged manifest release lama. |
| Target API Play | Source dengan SDK lokal memenuhi persyaratan target API 36 yang berlaku sejak 31 Agustus 2026. |
| Native 64-bit | Seluruh 8 library ARM64/x86_64 di AAB lama memiliki alignment segmen ELF LOAD minimal 16 KB. |
| Izin Android | Source memakai internet, notifikasi, dan boot. Merged manifest release lama tidak meminta lokasi, kontak, SMS, izin galeri luas, exact alarm, atau advertising ID. Dependency menambahkan izin pendukung seperti wake lock/network/biometrik. |
| Perlindungan data | Backup Android dinonaktifkan; sesi Supabase memakai secure storage; skrip database memiliki RLS dan bucket foto privat. Status penerapan pada server belum diverifikasi. |
| Penjelasan kesehatan | Layar Tentang sudah menyebut aplikasi bukan alat medis/pengganti nasihat dokter. |

Alignment ELF saja belum membuktikan kompatibilitas penuh 16 KB. Setelah AAB final dibangun, periksa konfigurasi bundle, alignment APK yang dihasilkan, dan jalankan di emulator/perangkat 16 KB.

Referensi: [target API Play](https://support.google.com/googleplay/android-developer/answer/11926878), [dukungan 16 KB](https://developer.android.com/guide/practices/page-sizes).

## Verifikasi berikutnya sebelum publikasi

1. Selesaikan signing, privasi, jalur penghapusan web, bug pembersihan storage, dan tes gagal di atas.
2. Uji daftar email/OTP, login email dan Google, reset password, sesi setelah restart, perpindahan akun, foto profil, penyimpanan catatan, dan hapus akun dengan akun uji pada layanan produksi yang dituju. Tidak ada perangkat/emulator aktif saat `adb devices -l` diperiksa pada audit ini.
3. Uji catatan setelah aplikasi ditutup, offline, logout/login, dan proses mati; pastikan UI menerangkan batas penyimpanan lokal.
4. Uji notifikasi ketika izin ditolak/diberikan, setelah reboot, dan saat aplikasi di background. Push hanya jika akan dirilis sebagai fitur aktif.
5. Lengkapi store listing, ikon/gambar/screenshot, kontak dukungan, content rating, target audience, deklarasi iklan, Data safety, dan akses reviewer ke fitur yang memerlukan login. Isi Health apps declaration berdasarkan fungsi bantuan berhenti merokok; jangan otomatis menyatakan tidak ada fitur kesehatan.
6. Jika akun developer personal dibuat setelah 13 November 2023, periksa kewajiban closed testing minimal 12 penguji selama 14 hari berturut-turut sebelum mengajukan akses production. Ini syarat akses production, bukan larangan membuat paket internal testing.
7. Baru bangun AAB final dengan upload key dan konfigurasi layanan eksplisit, verifikasi sertifikat/manifest/native libraries, kemudian uji instalasi dari track Play dan periksa pre-launch report.

Referensi: [Health apps declaration](https://support.google.com/googleplay/android-developer/answer/14738291), [testing akun personal](https://support.google.com/googleplay/android-developer/answer/14151465).

Audit ini tidak mengakses Play Console atau mengubah konfigurasi cloud. Build terbaru, alur perangkat nyata, deployment Supabase, keabsahan konfigurasi OAuth Play, serta keputusan review Google belum diverifikasi.
