# Foto profil Supabase

Penyebab sebelumnya: Image Picker/cropper hanya mengisi `UserProfile.photo` di memori. Tidak ada upload Storage, pembaruan `profiles.avatar_url`, atau pemuatan foto saat sesi dipulihkan.

## Setup sekali

1. Gunakan proyek yang sama dengan `SUPABASE_URL` pada `supabase.local.json`.
2. Bucket yang sudah dibuat adalah **photo-profil**. Jalankan `supabase/photo_profil_storage.sql` di SQL Editor. Script menjadikannya private, membatasi 5 MB dan PNG/JPEG, serta menambahkan SELECT/INSERT/DELETE hanya pada folder UID pemilik. Tidak mengubah tabel/kolom aplikasi. Tidak perlu policy UPDATE karena file tidak ditimpa.
3. Periksa hasil daftar policy. Policy permissive lain dapat memperluas akses; jangan tambahkan policy `true` untuk bucket ini. Screenshot awal menunjukkan 0 policy. Script tidak menghapus policy lain.
4. Pakai akun Google/Supabase di aplikasi. Akun email lokal belum mempunyai sesi Supabase dan tetap memakai foto sementara. Jangan memasukkan secret/service-role key ke Flutter.
5. Restart aplikasi dengan `flutter run --dart-define-from-file=supabase.local.json`.

## Alur dan pengujian perangkat

- Profil → foto → Pilih dari galeri. Izin Android diminta saat pemilihan saja; izin penuh maupun foto terpilih diterima. Batalkan/tolak: foto lama tetap tampil.
- Pilih dan crop foto. Aplikasi menghasilkan PNG maksimal 1024×1024, memvalidasi ukuran maksimal 5 MB, lalu upload ke `photo-profil/<auth.uid()>/<nama-acak>.png`.
- Setelah upload selesai, hanya baris `public.profiles.id = auth.uid()` yang diperbarui. **avatar_url menyimpan path relatif**, bukan URL publik atau signed URL kedaluwarsa.
- Periksa objek di Storage serta nilai `profiles.avatar_url` setelah spinner selesai. Tutup paksa/buka aplikasi: sesi dipulihkan, path dibaca dan gambar diunduh memakai JWT pengguna.
- Coba offline/gagal upload: foto lama tetap ada dan pesan error tampil. Jika pemuatan foto gagal setelah login, ketuk foto → Muat ulang foto.
- Hapus foto: `avatar_url` menjadi NULL sebelum file lama dihapus. Uji akun lain: tidak boleh membaca/menulis folder UID pertama. Uji keluar akun saat upload: hasil terlambat tidak boleh mengubah profil akun baru.

Update profil memakai pemeriksaan path sebelumnya supaya perangkat dengan data lama tidak menimpa foto baru. Jika update database timeout, file baru tidak otomatis dihapus karena update mungkin sudah committed. Buka ulang aplikasi untuk melihat keadaan server. File yang tidak terpakai akibat kegagalan/timeout atau cleanup gagal dapat memerlukan pembersihan manual; hapus hanya objek yang tidak lagi dirujuk `profiles.avatar_url`.

Izin Android dan notifikasi yang sudah ada tidak diubah oleh fitur upload ini. Policy cloud dan alur HP perlu diuji manual; tes otomatis memakai server mock dan tidak mengunggah foto pengguna.

Referensi: [Supabase Storage RLS](https://supabase.com/docs/guides/storage/security/access-control).
