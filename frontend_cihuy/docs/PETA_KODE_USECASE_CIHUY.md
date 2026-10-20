# PETA KODE USECASE CIHUY

**Repositori:** `D:\Project-CIHUY` (root git) · **Base commit:** `18c383c` · **Dibuat:** 20 Oktober 2026 (versi 2, setelah 5 fitur tambahan; semua perubahan masih uncommitted)
**Basis diagram:** `CIHUY.drawio` (halaman "Usecase Diagram" + "ERD") · **Aplikasi:** `frontend_cihuy/`

> SEMUA path relatif ke `frontend_cihuy/`. Nomor baris diverifikasi langsung ke file
> pada tanggal pembuatan dan **bisa berubah** setelah ada modifikasi kode (Ctrl+G di VS Code).

---

## PART 1 — MASTER CODE LOCATION TABLE

Status: ✅ lengkap · ◐ parsial · ❌ MISSING

| No | Nama Use Case | Status | File Dart | Class/Function | Exact Line Range | Function Explanation |
|----|---------------|--------|-----------|----------------|------------------|----------------------|
| 1 | Memilih Jenis Konsumsi | ✅ | lib/widgets/common.dart; lib/widgets/record_forms.dart; lib/screens/auth_screen.dart | `HabitSelector`/`ChoiceButton`; `_ConsumptionFormState`; onboarding `_OnboardingScreenState` | common.dart:114-188; record_forms.dart:280-439; auth_screen.dart:381-506 | Pilihan Rokok/Vape memakai enum `Habit` (records.dart:3) |
| 2 | Mencatat rata-rata konsumsi awal | ✅ (baru) | lib/screens/auth_screen.dart; lib/screens/profile_screen.dart; lib/providers/app_state.dart; lib/services/local_auth_repository.dart | Feld onboarding `_baseline`; `AppState.baseline/updateBaseline`; `LocalAccount.baselineCigarette/Vape`; `_BaselineForm` | auth_screen.dart:452-456 (input), 401-418 (`_complete`); app_state.dart:54-75; repo:21-38, 48-91; profile_screen.dart:176-190 (baris), 484-552 (form) | Baseline disimpan per akun, terpisah dari target harian & catatan historis |
| 3 | Menambahkan alasan berhenti | ✅ | lib/screens/auth_screen.dart; lib/providers/app_state.dart | `_complete` → `completeOnboarding(reason,...)` | auth_screen.dart:401-418; app_state.dart:547-571 | Field `reason` di profil & akun |
| 4 | Menambah catatan Konsumsi | ✅ | lib/widgets/record_forms.dart; lib/providers/app_state.dart | `showConsumptionForm`, `ConsumptionForm`, `AppState.saveConsumption` | record_forms.dart:107-278 (save 320-335); app_state.dart:283-308 | Validasi waktu/jumlah → tambah/ubah `Consumption` |
| 5 | Mengoreksi Catatan Konsumsi | ✅ | lib/widgets/record_details.dart | `showConsumptionDetails` → form edit (`entry:`) | record_details.dart:10-44 (edit 30) | id sama → merge jadi update |
| 6 | Menghapus catatan konsumsi | ✅ | lib/widgets/record_details.dart; lib/providers/app_state.dart | `confirmAction` → `deleteConsumption` | record_details.dart:34-43 (delete 41); app_state.dart:340-343 | `removeWhere` by id |
| 7 | Melihat riwayat dan detail konsumsi | ✅ | lib/screens/home_screen.dart; lib/screens/calendar_screen.dart; lib/widgets/record_details.dart | Riwayat lingkaran; daftar tanggal; `_RecordDetail` | home_screen.dart:100-162; calendar_screen.dart:616 (tap detail), 532 (konsumsi form); record_details.dart:10-80 | Riwayat 7 hari + detail sheet |
| 8 | Menambahkan Catatan Craving | ✅ | lib/widgets/record_forms.dart; lib/providers/app_state.dart | `CravingForm`; `saveCraving` | record_forms.dart:133-278 (497-515); app_state.dart:310-338 | Intensitas, pemicu, coping, ditahan |
| 9 | Mengoreksi Catatan Craving | ✅ | lib/widgets/record_details.dart | `showCravingDetails` → edit 66 | record_details.dart:47-81 | Update id sama |
| 10 | Menghapus catatan craving | ✅ | lib/widgets/record_details.dart; lib/providers/app_state.dart | `confirmAction` → `deleteCraving` | record_details.dart:70-79 (76); app_state.dart:345-348 | `removeWhere` by id |
| 11 | Melihat riwayat dan detail craving | ✅ | lib/screens/calendar_screen.dart; lib/widgets/record_details.dart | Kartu craving; tap `showCravingDetails` | calendar_screen.dart:667 (tap); record_details.dart:47-81 | Detail + status ditahan |
| 12 | Menambah Target Pengurangan | ✅ | lib/screens/targets_screen.dart; lib/providers/app_state.dart | `TargetForm` → `setTarget` | targets_screen.dart:68 (add), 242-380 (form, setTarget 358-375); app_state.dart:437-478 | Versi target bertanggal; validasi |
| 13 | Mengoreksi Target Pengurangan | ✅ | lib/screens/targets_screen.dart | edit sheet (`target:` target) | targets_screen.dart:133; 242-380 | Versi lama di-close (`endingOn`), histori aman |
| 14 | Menghapus Target Pengurangan | ✅ ◐ (soft utk riwayat) | lib/screens/targets_screen.dart; lib/providers/app_state.dart | "Nonaktifkan" (soft, berlaku per tanggal) + "Hapus permanen" untuk target terjadwal (`removeScheduledTarget`) | targets_screen.dart:126 (penjelasan), 213-225 (confirm), 145-150 (hard delete); app_state.dart:480-502 (deactivate), 495-503 (removeScheduledTarget) | Deaktivasi TIDAK menghapus riwayat (statistik historis tetap memakai target periode berjalan); hard-delete hanya target masa depan |
| 15 | Melihat Target Pengurangan | ✅ | lib/screens/home_screen.dart; lib/screens/targets_screen.dart | "Target Hari Ini" + `_TargetProgress`; `TargetsScreen` | home_screen.dart:167-202 (progress 433-488); targets_screen.dart:14-92 | Progres hari ini + riwayat target |
| 16 | Melihat Dasboard Konsumsi | ✅ | lib/screens/home_screen.dart | `HomeScreen.build` | home_screen.dart:13-205 | Tab beranda: timer, warning, rangkuman, pola craving, riwayat, target |
| 17 | Melihat Timer Bebas Konsumsi | ✅ | lib/screens/home_screen.dart; lib/services/progress_calculator.dart | `QuitTimerCard`; `elapsed/lastConsumption` | home_screen.dart:241-366; progress_calculator.dart:40-53 | Hitung live sejak `profile.startedAt` |
| 18 | Melihat Kalender Progres | ✅ | lib/screens/calendar_screen.dart | `CalendarScreen`, `MonthGrid`, `CalendarDay` | calendar_screen.dart:14-278 (grid 102, day 170) | Grid bulanan + status achieved/exceeded |
| 19 | Melihat Grafik Progres | ✅ (baru) (7/30) | lib/screens/calendar_screen.dart | `ConsumptionChart` + `SegmentedButton` 7/30 hari | calendar_screen.dart:291-437 (selector 331-356; 30-hari scroll 385-415; empty-note 417-424) | Chart bar dihitung dari catatan nyata; 30 hari bisa digeser horizontal |
| 20 | Melihat Pola Pemicu dan Craving | ✅ (baru) | lib/widgets/craving_pattern.dart; lib/screens/home_screen.dart | `CravingPatternSummary`, `_IntensityChip` | craving_pattern.dart:11-176; home_screen.dart:100-102 | Top pemicu + distribusi intensitas + resisted dari craving 30 hari; ada empty state |
| 21 | Melihat Streak Aktif, Best Streak dan Total Hari Berhasil | ✅ | lib/screens/home_screen.dart; lib/services/progress_calculator.dart | `_Streak`; `currentStreak/bestStreak/successfulDays` | home_screen.dart:368-383 (stats 398-430); progress_calculator.dart:54-91 | Run hari achieved |
| 22 | Melihat Rangkuman Mingguan | ✅ | lib/screens/home_screen.dart; lib/services/progress_calculator.dart | `SummaryStat`; `totalInRange/resistedInRange` | home_screen.dart:34-87; progress_calculator.dart:93-114 | Statistik 7 hari |
| 23 | Menerima Peringatan Batas Harian | ✅ | lib/widgets/daily_consumption_warning.dart; lib/screens/home_screen.dart | `DailyConsumptionWarning`; `_DailyLimitWarnings` | warning:1-149 (status 11-21, dismiss 127-146); home:208-239 | Kartu 80% / tercapai / melebihi, tombol "Dimengerti" |
| 24 | Daftar Akun | ✅ | lib/screens/auth_screen.dart; lib/providers/app_state.dart; lib/services/local_auth_repository.dart | `_submit` → `register` → repo register | auth_screen.dart:32-62; app_state.dart:110-138; repo:146-175 | Hash PBKDF2 120k + kode pemulihan |
| 25 | Login | ✅ | idem | `_submit` → `authenticate` → `signIn` | auth_screen.dart:60; app_state.dart:140-161; repo:177-196 | Constant-time verify + sesi secure storage |
| 26 | Mereset Kata Sandi | ✅ | auth_screen/_showRecovery; app_state; repo | `_showRecovery` → `resetPassword` | auth_screen.dart:239-343 (dialog) + 345-380 (`_showRecovery`, bersih galat); app_state.dart:195-223 (clearAuthError :105); repo:198-232 | Email+kode+password baru; galat gagal tidak menempel di form login |
| 27 | Mengubah Kata Sandi | ✅ | lib/screens/profile_screen.dart; auth_screen.dart; app_state.dart; repo | ListTile "Ubah kata sandi" → `PasswordForm._submit` → `changePassword` | profile_screen.dart:197-209; auth_screen.dart:508-641 (submit 553-569); app_state.dart:165-193; repo:234-267 | Verify lama, hash/salt baru, sinkron `_account` |
| 28 | Melihat Profil | ✅ | lib/screens/profile_screen.dart | `ProfileScreen.build` + `_ProfileStat` + `ProfileAvatar` | profile_screen.dart:13-308 (stat 311-341) | Header gradient + stat + foto |
| 29 | Edit Profil | ✅ | lib/screens/profile_screen.dart; lib/providers/app_state.dart | `_InfoRow` Edit → `_EditProfileForm` → `updateProfile` | profile_screen.dart:157/173/423-481; app_state.dart:350-371 updateProfile | Nama/alason + sinkron akun |
| 30 | Log Out | ✅ | lib/screens/profile_screen.dart; lib/providers/app_state.dart | ListTile "Keluar" → `signOut` | profile_screen.dart:258-281; app_state.dart:505-515 | Hapus sesi + recoveryCode |
| 31 | Hapus Akun | ✅ (baru) | lib/screens/profile_screen.dart; lib/providers/app_state.dart; lib/services/local_auth_repository.dart | ListTile "Hapus akun" + confirm → `AppState.deleteAccount` → `repo.deleteAccount(id:)` | profile_screen.dart:231-257; app_state.dart:579-593; repo:279-292; test completed_usecases_test.dart | Hapus akun terdaftar saat ini secara permanen; sesi hilang; akun lain aman |
| 32 | Tindakan Lanjutan (kategori) | ✅ | lib/app.dart; lib/screens/profile_screen.dart | FAB "Catat Sekarang"; grup LAINNYA | app.dart:93-116; profile_screen.dart:220-257 | Kategori diagram |
| 33 | (Paket) kelompok diagram | ✅ | — | Node kelompok; turunannya di atas | — | Data Awal Pengguna / Catatan / Target / Pemantauan / Akun |

---

## PART 2 — DETAIL PER USE CASE (5 FITUR BARU/LAMA TERPELAJAR)

### Use Case: Mencatat rata-rata konsumsi awal (BARU)
1. UI entry: onboarding input `Rata-rata konsumsi awal` — `auth_screen.dart:328-347` (controller `_baseline` 339; field 336-348).
2. Handler: `_complete` `auth_screen.dart:349-366` memanggil `state.completeOnboarding(reason, baselineHabit: _habit, baselineValue: ...)` (360-365).
3. Logic: `AppState.completeOnboarding` `app_state.dart:547-571` menyimpan baseline ke akun terdaftar; `updateBaseline` `:67-77` digunakan dari profil; getter `baseline(habit)` `:58-64` dibaca UI.
4. Data: `LocalAccount.baselineCigarette/baselineVape` `local_auth_repository.dart:37-38` (ctor 21-22, copyWith 48-62, toJson 76-77, fromJson 91-92) — persisten di SharedPreferences bersama akun lainnya.
5. Alur: Onboarding/profil → AppState → LocalAccount → SharedPreferences → UI (profil baris 176-190).
6. Dosen: "Baseline dibedakan dari target: baseline taksiran konsumsi sebelum berhenti, target batas kesepian harian. Mengubah baseline tidak menyentuh catatan historis."
7. Snippet:
```dart
// app_state.dart:67-77
void updateBaseline(Habit habit, int value) {
  final account = _account;
  if (account == null || value < 0) return;
  final updated = account.copyWith(
    baselineCigarette: habit == Habit.cigarette ? value : null,
    baselineVape: habit == Habit.vape ? value : null,
  );
  _account = updated;
  unawaited(_auth.updateAccount(updated));
  notifyListeners();
}
```

### Use Case: Menghapus Target Pengurangan (dilengkapi)
- Soft-delete (default): tombol "Nonaktifkan" `targets_screen.dart:213-225` — konfirmasi + penjelasan di UI (126) bahwa riwayat tidak dihapus; logic `AppState.deactivateTarget` `app_state.dart:480-493` (set tanggal `endsOn`).
- Hard-delete khusus target terjadwal (belum berjalan): sheet detail menampilkan "Hapus permanen" `targets_screen.dart:145-150` → confirm `:137` → `removeScheduledTarget` `app_state.dart:486-496` (guard `startsOn > today`, `ArgumentError` bila sudah berjalan).
- Target nonaktif/terjadwal tidak muncul sebagai aktif: filter `targets_screen.dart:25-33` + Home memakai `progress.targetOn(today)`.
- Test: `test/completed_usecases_test.dart` group 'hapus target terjadwal'.

### Use Case: Melihat Grafik Progres (7/30 hari, BARU)
1. UI: `ConsumptionChart` `calendar_screen.dart:291-437` — `SegmentedButton 7 Hari/30 Hari` (331-356).
2. Logic: `_days` state (297-300); `from = shiftDay(end, -(_days-1))` (306); nilai dari `progress.total(day, habit)`.
3. Bar: 7 hari → `Row Expanded` (363-385); 30 hari → `SingleChildScrollView` horizontal (385-415) dengan bar selebar 40 agar tidak overflow. Bar emyak: contigs 'exceeded' merah (ChartBar color :396-401).
4. Empty: 'Belum ada catatan konsumsi pada rentang ini.' (417-424).
5. Tidak ada fake data — dihitung dari catatan nyata; `chart-range` key dipertahankan.
- Test: widget test 'grafik mendukung pilihan rentang 30 hari'.

### Use Case: Melihat Pola Pemicu dan Craving (BARU)
1. UI: kartu di Beranda setelah 'Motivasi' — `home_screen.dart:100-102` → `CravingPatternSummary` `craving_pattern.dart:11-176`.
2. Logic: craving 30 hari terakhir (`:20-26`); pemicu hitung `<String,int>` map (39-46) dan top-5 (49-50); distribusi intensitas per `Intensity` (52-56); ringkasan ditahan `:57-58`.
3. Empty state: craving kosong →pesan (28-37); 30-hari kosong → pesan lain (38-48).
4. Test: 'pola craving menampilkan pemicu dari catatan nyata' & 'keadaan kosong'.

```dart
// craving_pattern.dart:39-50
final triggerCounts = <String,int>{};
for (final craving in recent) {
  for (final trigger in craving.triggers) {
    triggerCounts[trigger] = (triggerCounts[trigger] ?? 0) + 1;
  }
}
final triggers = triggerCounts.entries.toList()
  ..sort((a, b) => b.value.compareTo(a.value));
final topTriggers = triggers.take(5).toList();
```

### Use Case: Hapus Akun (BARU)
1. UI: tile "Hapus akun" hanya saat akun terdaftar — `profile_screen.dart:231-257` (`hasAccount` `app_state.dart:54`).
2. Confirm dialog: `confirmAction(title 'Hapus akun?', message 'permanen... tidak bisa dibatalkan', confirm 'Hapus akun')` `:246-255` kemudian `await state.deleteAccount()` `:253`.
3. Logic: `AppState.deleteAccount` `app_state.dart:579-593` async: `await _auth.deleteAccount(id: account.id)` (582-584) → reset store & UI.
4. Repo: `deleteAccount({required String id})` `local_auth_repository.dart:281-292` — hapus SATU akun dari daftar (`removeWhere`) + hapus sesi secure storage; akun lain aman; id unknown → `LocalAuthException`.
5. Prevent relogin: email yang dihapus tak ada dalam daftar → `signIn` gagal (`repo.signIn` filter email).
6. Test: 'akun terhapus permanen, sesi jelas, akun lain tetap ada' + 'id yang tidak dikenal ditolak'.

```dart
// local_auth_repository.dart:281-292
Future<void> deleteAccount({required String id}) async {
  final accounts = await _accounts();
  if (!accounts.any((item) => item.id == id)) {
    throw const LocalAuthException('Akun lokal tidak ditemukan.');
  }
  accounts.removeWhere((item) => item.id == id);
  await _saveAccounts(accounts);
  await _secureStorage.delete(key: _sessionKey);
}
```

### Use case lain (tidak berubah fungsi, baris ikut bergeser)
- CRUD konsumsi: saveConsumption `app_state.dart:283`; delete 340; craving 310/345; updateProfile 350.
- Peringatan batas: `_statusFor` `daily_consumption_warning.dart:11-21`; Bentuk kartu `:47-148`.
- Auth: register `auth_screen.dart:32-62` (`state.register :36`, dialog kode pemulihan 42-57 + `clearRecoveryCode` 58); login `:60`; reset `_showRecovery :345-380` (dialog `_RecoveryDialog :239-343`); `PasswordForm._submit :553-569` → `changePassword` (`app_state.dart:165-193` → `repo:234-267`).
- Navigasi & state: `app.dart:42` Provider; `home: Consumer` conditional `:51-58`; `IndexedStack` `:87`; BottomNav `:138-140` → `selectTab`; `openTargets` Navigator.push `targets_screen.dart:9`.
- Data & progress: MockStore lists `mock_store.dart:74-76`; `ProgressCalculator` `progress_calculator.dart:5-114` (status 28, streaks 54/66, weekly 93/103).
- Session: `initializeAuth` `app_state.dart:89-101`; `_applyAccount` `:218-230` (reset store per akun).

---

## PART 3 — NAVIGASI & STATE MANAGEMENT (tidak berubah)
- `main.dart:6-10` `runApp`.
- `app.dart:42` ChangeNotifierProvider.value + MaterialApp.
- `app.dart:51-58` conditional switch auth/onboarding/shell; `_AuthLoadingScreen` 64; AppShell 71; PopScope 76; IndexedStack 87; footer FAB 93-101; BottomNav 138-140.
- `provider` + `notifyListeners` + pernyataan `context.watch/read`.
- Cold start: `app.dart:25-40` initState → `initializeAuth` (app_state.dart:89) → sesi restore atau AuthScreen.

---

## PART 4 — PETA ERD → KODE (penting: DATA AKUN persisten; TRACKING MASIH MEMORI)

| ERD | Field ERD | Dart | File:Line | Penyimpanan | CRUD |
|-----|-----------|------|-----------|-------------|------|
| User | nama/reason/startedAt | `UserProfile` + `LocalAccount` | records.dart:83-103; repo:9-96 | sesi memori / SharedPreferences `local_auth_accounts` | register repo:146; updateAccount repo:269 |
| | email (UK) | `LocalAccount.email` | repo:16 | SharedPreferences | register/signIn repo:146/177 |
| | password_hash/salt | `passwordHash/passwordSalt` | repo:18-19 | SharedPreferences | changePassword repo:234-267 |
| | **rata_rata_awal** | **`baselineCigarette/baselineVape`** | **repo:37-38** | SharedPreferences (persisten per akun) | `completeOnboarding` app_state.dart:547; `updateBaseline` :67 |
| | sebagai sesi | `local_auth_session` | repo:103-104 | secure storage | write repo:173/194/229; delete repo:291 |
| Kebiasaan_Konsumsi | jenis/satuan | enum `Habit` + label/unit | records.dart:3-8 | global enum | HabitSelector common.dart:114 |
| Target_Harian | id/habit/limit/startsOn/endsOn | `DailyTarget` | records.dart:53-73 | memori `_store.targets` mock_store.dart:76 | setTarget app_state.dart:437; deactivateTarget :480; removeScheduledTarget :495; appliesOn records.dart:69 |
| Catatan_Konsumsi | id/habit/waktu/jumlah/catatan | `Consumption` | records.dart:20-35 | memori `_store.consumption` | save 276 / delete 333 / baca 263; total progress_calculator.dart:9 |
| Catatan_Craving | id/habit/waktu/intensitas/pemicu/coping/hasil | `Craving` (+enum Intensity 10) | records.dart:35-55 | memori `_store.cravings` | save 303 / delete 338 / baca 266; resistedInRange progress_calculator.dart:103 |
| | dibuat_pada/diubah_pada | tidak ada | — | — | ❌ belum diterapkan (rencana persistence) |

**Relasi:** satu akun = satu store sesi; relasi ERD dipetakan secara logika (bukan tabel FK nyata). HANYA data akun (termasuk baseline) yang persisten — catatan tracking masih menguasai memori sesi.

---

## PART 5 — PERTANYAAN DOSEN (20) (versi terbaru)
1. Data catatan disimpan di mana? Memori sesi `MockStore` (mock_store.dart:74-76).
2. Akun? SharedPreferences `local_auth_accounts` (repo:102) + sesi secure storage.
3. Hash? PBKDF2-SHA256 120k iterasi (repo:295-306), _constantTimeEquals repo:322.
4. Kenapa constant time? anti timing attack.
5. setTarget? app_state.dart:437-478 versi target.
6. Tombol "Catat Sekarang" → app.dart:101 → record_forms.dart:9/107 → save app_state.dart:283.
7. State management? provider + ChangeNotifier; watch/read; notifyListeners.
8. Routing? conditional home switch (app.dart:51) + IndexedStack (87) + selectTab; Navigator.push hanya target (targets_screen.dart:9).
9. Pemulihan sesi? app.dart:25 → initializeAuth app_state.dart:89 → _applyAccount 218.
10. Konsumsi validasi? _checkTime & amount>=1 app_state.dart:283-299.
11. Streak? progress_calculator.dart:54-79.
12. Warna kalender? DayStatus records.dart:18 → CalendarDay calendar_screen.dart:170.
13. Peringatan 80/100/lebih? daily_consumption_warning.dart:11-21.
14. Ubah kata sandi? profile_screen.dart:197-209 → auth_screen.dart:553 → app_state.dart:165 → repo:234.
15. Kode pemulihan? auth_screen.dart:42-57 tampil sekali lalu `clearRecoveryCode` (58; app_state.dart:517).
16. Fix timpa hash lama? changePassword mengembalikan akun terbarui → `_account = updated` (app_state.dart:165-176).
17. Rangkuman mingguan? home_screen.dart:34-87 + calculator: 80-114.
18. Edit konsumsi aman id? saveConsumption ditimpa dalam index (app_state.dart:283-308).
19. Baseline vs target? baseline repo:37-38 (basis awal), target batas harian; updateBaseline tidak menyentuh catatan (app_state.dart:67-77).
20. Hapus target? Nonaktif (soft) app_state.dart:480; hard-delete terjadwal :495-503 w/ guard.

---

## PART 6 — DOSEN NANYA KODE? BUKA SINI!

| Use case | File | Baris | Function | Satu kalimat |
|----------|------|-------|----------|--------------|
| Daftar akun | auth_screen.dart | 32 | _submit | Register + dialog kode pemulihan |
| Register logic | app_state.dart | 110 | register | Bungkus errorCode+onboarding |
| Register storage | local_auth_repository.dart | 146 | register | Simpan hash/recovery/sesi |
| Hashing | local_auth_repository.dart | 295 | _derive | PBKDF2 120k |
| Login | auth_screen.dart | 32/60 | _submit | Branch login → authenticate |
| Login verify | local_auth_repository.dart | 177 | signIn | Email + hash verify |
| Reset kata sandi | auth_screen.dart | 279/345 | _showRecovery | Kode pemulihan → password baru |
| Ubah kata sandi | auth_screen.dart | 508/553 | PasswordForm | Sheet dari profil |
| Ubah kata sandi logic | app_state.dart | 165 | changePassword | Verify lama, hash baru, sync akun |
| **Baseline onboarding** | auth_screen.dart | 452-458 | TextFormField/baseline | Input awal (opsional) |
| **Baseline edit dari profil** | profile_screen.dart | 484+ | _BaselineForm | Sheet edit baseline |
| **Baseline state** | app_state.dart | 58/67 | baseline/updateBaseline | Getter & penyimpanan per akun |
| **Baseline storage** | local_auth_repository.dart | 37 | baselineCigarette/Vape | Persisten |
| **Hapus akun tile** | profile_screen.dart | 231-257 | confirm → deleteAccount | Warning irreversible |
| **Hapus akun logic** | app_state.dart | 579 | deleteAccount async | Reset UI + repo delete |
| **Hapus akun repo** | local_auth_repository.dart | 281 | deleteAccount(id:) | Hapus 1 akun + sesi |
| **Grafik 7/30** | calendar_screen.dart | 291/331 | ConsumptionChart/SegmentedButton | Rentang selector |
| **Grafik 30-hari scroll** | calendar_screen.dart | 385-415 | SingleChildScrollView | Bars horizontal |
| **Pola craving** | craving_pattern.dart | 11 | CravingPatternSummary | Pemicu top + intensitas |
| Pola mount | home_screen.dart | 101 | const CravingPatternSummary | Kartu Beranda |
| **Hapus target terjadwal** | targets_screen.dart | 145-150 | 'Hapus permanen' | Hard-delete w/ confirm |
| **removeScheduledTarget** | app_state.dart | 495 | removeScheduledTarget | Guard sudah berjalan |
| Nonaktif target | app_state.dart | 480 | deactivateTarget | Soft delete via endsOn |
| Catat konsumsi | record_forms.dart | 9/107/320 | chooser/showConsumptionForm | FAB footer app.dart:101 |
| Simpan konsumsi | app_state.dart | 283 | saveConsumption | Validasi + upsert |
| Edit/hapus konsumsi | record_details.dart | 10/30/41 | detail sheet | confirmAction |
| Catat craving | record_forms.dart | 133/497 | CravingForm/save | Intensity/pemicu |
| Tambah target | targets_screen.dart | 9/68/242 | openTargets/TargetForm | Navigator.push |
| Peringatan batas | daily_consumption_warning.dart | 11/47 | status/kartu | 80/100/>100 |
| Dashboard | home_screen.dart | 13/17 | HomeScreen | Beranda |
| Timer | home_screen.dart | 241/275 | QuitTimerCard | Live |
| Streak | progress_calculator.dart | 54/66 | current/best | mundur achieved |
| Kalender | calendar_screen.dart | 14/102/170 | Screen/grid/day | Status per hari |
| Riwayat detail | record_details.dart | 82 | _RecordDetail | Sheet |
| Pemilih habit | common.dart | 114 | HabitSelector | ChoiceButton |
| Model habit/unit | records.dart | 3-8 | Habit + ext | Rokok/batang |
| Status hari | records.dart | 18-20 | DayStatus | achieved/exceeded |
| App init | main.dart | 6 | main() | runApp |
| Splash / switch auth | app.dart | 64/51-58 | _AuthLoadingScreen/Consumer | conditional |
| Tab routing | app.dart | 87/138/140 | IndexedStack/BottomNav | selectTab |
| Sesi restore | app_state.dart | 89/218 | initializeAuth/_applyAccount | cold start |
| recoveryCode | app_state.dart | 87/517 | field/clearRecoveryCode | tampil sekali lalu nol |
| authError | app_state.dart | 86/105 | field/clearAuthError | galat dialog pemulihan tidak menempel di form lain |

### Catatan Presentasi
- JUJUR: catatan konsumsi/craving & target masih memori sesi (restart hilang); yang persisten = AKUN + baseline (SharedPreferences) + sesi (secure storage).
- Fitur baru siap demo: baseline (onboarding & profil), hapus akun (profil), grafik 7/30 (kalender), pola craving (beranda), hapus target terjadwal (targets).

---

## PART 6 - PEMETAAN CIHUY.drawio -> LAYAR APLIKASI

Diperiksa langsung dari CIHUY.drawio pada 20 Okt 2026 (nomor baris diverifikasi ulang setelah fix clearAuthError).
Semua path relatif ke frontend_cihuy/.

| Paket diagram (aktor) | Use case diagram | Halaman/layar | File utama |
|---|---|---|---|
| Data Awal Pengguna | Memilih Jenis Konsumsi | Onboarding (pilihan Rokok/Vape) | auth_screen.dart:381-506 (OnboardingScreen); widgets/common.dart:114 (HabitSelector) |
| Data Awal Pengguna | Menambahkan alasan berhenti | Onboarding field "Alasan ingin berhenti" -> profil | auth_screen.dart:401-418 (_complete -> completeOnboarding, app_state.dart:547-571); edit ulang: profile_screen.dart:423-471 (_EditProfileForm) |
| Data Awal Pengguna | Mencatat rata-rata konsumsi awal | Onboarding "Rata-rata konsumsi awal" + profil (sheet baseline) | auth_screen.dart:452-458 (input, _complete 401-418); profile_screen.dart:484-543 (_BaselineForm); app_state.dart:58-77 |
| Catatan Konsumsi | Menambah catatan Konsumsi | FAB "Catat Sekarang" (beranda) / "+ Tambah" (kalender) | app.dart:93-123 (FAB); widgets/record_forms.dart:107-278 (showConsumptionForm); app_state.dart:283-308 (saveConsumption) |
| Catatan Konsumsi | Mengoreksi Catatan Konsumsi | Detail sheet dari kalender | widgets/record_details.dart:10-44 (edit :30) |
| Catatan Konsumsi | Menghapus catatan konsumsi | Detail sheet -> konfirmasi | record_details.dart:34-43; app_state.dart:340-343 |
| Catatan Konsumsi | Melihat riwayat dan detail konsumsi | Beranda (lingkaran riwayat) + Kalender (daftar harian) | home_screen.dart:102-165; calendar_screen.dart:507-674 (DailyDetails, pill "Tambah" :588) |
| Catatan Craving | Menambahkan Catatan Craving | Chooser FAB -> form craving / "+ Tambah" kalender | record_forms.dart (CravingForm, save showCravingForm); app_state.dart:310-338 (saveCraving); calendar_screen.dart:533-536 |
| Catatan Craving | Mengoreksi Catatan Craving | Detail sheet craving | record_details.dart:47-81 |
| Catatan Craving | Menghapus catatan craving | Detail sheet -> konfirmasi | record_details.dart:70-79; app_state.dart:345-348 |
| Catatan Craving | Melihat riwayat dan detail craving | Beranda (pola 30 hari) + Kalender (daftar craving) | calendar_screen.dart:645-668; widgets/craving_pattern.dart:11-176 |
| Target Pengurangan | Menambah Target Pengurangan | Layar target (full route) / "Buat target harian" beranda | targets_screen.dart:68, 242-380; app_state.dart:437-478 |
| Target Pengurangan | Mengoreksi Target Pengurangan | Edit sheet target (versi bertanggal) | targets_screen.dart:133, 242-380 |
| Target Pengurangan | Menghapus Target Pengurangan | Nonaktifkan (soft) / Hapus permanen (terjadwal) | targets_screen.dart:126, 145-150, 213-225; app_state.dart:480-503 |
| Target Pengurangan | Melihat Target Pengurangan | Kartu "Target Hari Ini" (beranda) + "Target harian" (profil) | home_screen.dart:172-202 (_TargetProgress 439-494); targets_screen.dart:14-92 |
| Pemantauan Progres | Melihat Dasboard Konsumsi | Tab Beranda (IndexedStack 0) | home_screen.dart:14-205; app.dart:87 |
| Pemantauan Progres | Melihat Timer Bebas Konsumsi | Kartu "BERHENTI SEJAK" live | home_screen.dart:241-372 (QuitTimerCard); progress_calculator.dart:40-53 |
| Pemantauan Progres | Melihat Kalender Progres | Tab Kalender + grid bulanan berwarna | calendar_screen.dart:14-278 (MonthGrid 102, CalendarDay 170) |
| Pemantauan Progres | Melihat Grafik Progres | Kartu grafik (selector 7/30 hari) | calendar_screen.dart:291-427 (ConsumptionChart) |
| Pemantauan Progres | Melihat Pola Pemicu dan Craving | Kartu pola craving di beranda | widgets/craving_pattern.dart:11-176; home_screen.dart:101 |
| Pemantauan Progres | Melihat Streak Aktif, Best Streak dan Total Hari Berhasil | Beranda (streak) + profil (stat) | home_screen.dart:374-389; progress_calculator.dart:54-91; profile_screen.dart:111-134 |
| Pemantauan Progres | Melihat Rangkuman Mingguan | Kartu "Rangkuman Mingguan" (beranda) | home_screen.dart:36-85; progress_calculator.dart:93-114 |
| Pemantauan Progres (extend) | Menerima Peringatan Batas Harian | Kartu kuning/merah di atas beranda | widgets/daily_consumption_warning.dart:1-149; home_screen.dart:208-239 |
| Akun Dan Autentikasi | Daftar Akun | Tab layar awal "Buat akun" | auth_screen.dart:32-62; app_state.dart:110-138; repo:146-175 |
| Akun Dan Autentikasi | Login | Layar awal "Masuk" | auth_screen.dart:60; app_state.dart:140-161; repo:177-196 |
| Akun Dan Autentikasi | Mereset Kata Sandi | Dialog "Pulihkan kata sandi" (lupa kata sandi) | auth_screen.dart:345-380 (_showRecovery) + 239-343 (_RecoveryDialog); app_state.dart:195-223; repo:198-232 |
| Akun Dan Autentikasi | Mengubah Kata Sandi | Profil -> KEAMANAN -> sheet | profile_screen.dart:197-209; auth_screen.dart:508-641 (PasswordForm, submit 553-569); app_state.dart:165-193 |
| Akun Dan Autentikasi | Melihat Profil | Tab Profil (header gradient + statistik) | profile_screen.dart:13-299 |
| Akun Dan Autentikasi | Edit Profil | Baris INFORMASI AKUN -> sheet edit | profile_screen.dart:151-175, 423-471; app_state.dart:350-371 |
| Akun Dan Autentikasi | Log Out | Profil -> LAINNYA -> "Keluar" | profile_screen.dart:258-281; app_state.dart:505-515 |
| Akun Dan Autentikasi | Hapus Akun | Profil -> "Hapus akun" + konfirmasi | profile_screen.dart:231-256; app_state.dart:579-593; repo:279-292 |

****Cara membaca:** paket diagram = bagian UI, baris file = titik masuk handler (nilai default diverifikasi 20 Okt 2026). Routing antar tab: app.dart:87-90 (IndexedStack 0/1/2 = Beranda/Kalender/Profil); rute penuh: targets_screen & progress_screen via Navigator.push.
