import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/records.dart';
import '../services/mock_store.dart';
import '../services/progress_calculator.dart';
import '../services/profile_photo_picker.dart';
import '../services/local_auth_repository.dart';
import '../utils/dates.dart';

class AppState extends ChangeNotifier {
  AppState({
    DateTime Function()? clock,
    MockStore? store,
    bool autoTick = true,
    ProfilePhotoPicker? photoPicker,
    LocalAuthRepository? authRepository,
    bool startSignedIn = true,
  }) : _clock = clock ?? DateTime.now,
       _photoPicker = photoPicker ?? ProfilePhotoPicker(),
       _authRepository = authRepository {
    _store = store ?? MockStore.empty(now);
    signedIn = startSignedIn;
    selectedDay = dayOnly(now);
    chartEnd = selectedDay;
    visibleMonth = DateTime(now.year, now.month);
    if (autoTick) {
      _refresh = Timer.periodic(
        const Duration(seconds: 30),
        (_) => notifyListeners(),
      );
    }
  }

  final DateTime Function() _clock;
  late MockStore _store;
  Timer? _refresh;
  final ProfilePhotoPicker _photoPicker;
  LocalAuthRepository? _authRepository;
  LocalAuthRepository get _auth => _authRepository ??= LocalAuthRepository();
  LocalAccount? _account;
  int _photoRequest = 0;
  bool pickingPhoto = false;
  String? photoError;
  DateTime get now => _clock();
  UserProfile get profile => _store.profile;
  List<Consumption> get consumption => List.unmodifiable(_store.consumption);
  List<Craving> get cravings => List.unmodifiable(_store.cravings);
  List<DailyTarget> get targets => List.unmodifiable(_store.targets);
  ProgressCalculator get progress => ProgressCalculator(_store);
  int get recordCount => _store.consumption.length + _store.cravings.length;

  /// Akun terdaftar sedang aktif (bukan demo atau pengguna tanpa akun)?
  bool get hasAccount => _account != null;

  /// Rata-rata konsumsi awal (baseline) per jenis kebiasaan. Null berarti
  /// belum diisi.
  int? baseline(Habit habit) {
    final account = _account;
    if (account == null) return null;
    return habit == Habit.cigarette
        ? account.baselineCigarette
        : account.baselineVape;
  }

  /// Memperbarui baseline dari profil. Tidak menyentuh catatan historis.
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
  int tab = 0;
  late DateTime selectedDay;
  late DateTime chartEnd;
  late DateTime visibleMonth;
  Habit chartHabit = Habit.cigarette;
  bool signedIn = false;
  bool needsOnboarding = false;
  bool authLoading = false;
  String? authError;
  String? recoveryCode;

  Future<void> initializeAuth() async {
    if (_account != null || signedIn) return;
    authLoading = true;
    notifyListeners();
    final account = await _auth.currentAccount();
    if (account == null) {
      signedIn = false;
    } else {
      _applyAccount(account);
    }
    authLoading = false;
    notifyListeners();
  }

  /// Menghapus sisa pesan galat autentikasi (mis. dari dialog pemulihan)
  /// agar tidak menempel di form yang lain.
  void clearAuthError() {
    authError = null;
    notifyListeners();
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {
    authLoading = true;
    authError = null;
    notifyListeners();
    try {
      final result = await _auth.register(
        name: name,
        email: email,
        password: password,
      );
      recoveryCode = result.code;
      _applyAccount(result.account);
      _store = MockStore.empty(
        now,
        name: result.account.name,
        email: result.account.email,
      );
      needsOnboarding = true;
    } on LocalAuthException catch (error) {
      authError = error.message;
    } finally {
      authLoading = false;
      notifyListeners();
    }
  }

  Future<void> authenticate({
    required String email,
    required String password,
  }) async {
    authLoading = true;
    authError = null;
    notifyListeners();
    try {
      _applyAccount(await _auth.signIn(email: email, password: password));
      _store = MockStore.empty(
        now,
        name: _account!.name,
        email: _account!.email,
        reason: _account!.reason,
      );
    } on LocalAuthException catch (error) {
      authError = error.message;
    } finally {
      authLoading = false;
      notifyListeners();
    }
  }

  /// Mengganti kata sandi akun lokal yang sedang masuk. Mengembalikan true
  /// bila berhasil; kegagalan diisi ke [authError].
  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (!signedIn || _account == null) {
      authError = 'Mode demo tidak memiliki akun terdaftar.';
      notifyListeners();
      return false;
    }
    authLoading = true;
    authError = null;
    notifyListeners();
    try {
      // Simpan kredensial terbaru agar perubahan profil berikutnya tidak
      // menimpa hash baru dengan hash lama.
      final updated = await _auth.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      _account = updated;
      return true;
    } on LocalAuthException catch (error) {
      authError = error.message;
      return false;
    } finally {
      authLoading = false;
      notifyListeners();
    }
  }

  Future<void> resetPassword({
    required String email,
    required String code,
    required String password,
  }) async {
    authLoading = true;
    authError = null;
    notifyListeners();
    try {
      final result = await _auth.resetPassword(
        email: email,
        code: code,
        password: password,
      );
      recoveryCode = result.code;
      _applyAccount(result.account);
      _store = MockStore.empty(
        now,
        name: result.account.name,
        email: result.account.email,
        reason: result.account.reason,
      );
    } on LocalAuthException catch (error) {
      authError = error.message;
    } finally {
      authLoading = false;
      notifyListeners();
    }
  }

  void _applyAccount(LocalAccount account) {
    _account = account;
    signedIn = true;
    // Pemulihan sesi dari cold start harus selalu menampilkan data akun yang
    // sesuai, bukan isi demo atau store dari akun/ sesi sebelumnya.
    _store = MockStore.empty(
      now,
      name: account.name,
      email: account.email,
      reason: account.reason,
    );
    needsOnboarding = !account.onboardingCompleted;
    _resetNavigation();
  }

  void refresh() => notifyListeners();
  void selectTab(int value) {
    tab = value;
    notifyListeners();
  }

  void selectDate(
    DateTime value, {
    bool openCalendar = false,
    bool keepChartRange = false,
  }) {
    selectedDay = dayOnly(value);
    if (!keepChartRange) {
      chartEnd = selectedDay;
      visibleMonth = DateTime(value.year, value.month);
    }
    if (openCalendar) tab = 1;
    notifyListeners();
  }

  void changeMonth(int direction) {
    visibleMonth = DateTime(visibleMonth.year, visibleMonth.month + direction);
    notifyListeners();
  }

  void selectHabit(Habit value) {
    chartHabit = value;
    notifyListeners();
  }

  List<Consumption> consumptionOn(DateTime day) =>
      _store.consumption.where((entry) => sameDay(day, entry.at)).toList()
        ..sort((a, b) => a.at.compareTo(b.at));
  List<Craving> cravingsOn(DateTime day) =>
      _store.cravings.where((entry) => sameDay(day, entry.at)).toList()
        ..sort((a, b) => a.at.compareTo(b.at));

  void _checkTime(DateTime at) {
    if (at.isAfter(now)) {
      throw ArgumentError('Waktu kejadian tidak boleh di masa depan.');
    }
  }

  Consumption saveConsumption({
    String? id,
    required Habit habit,
    required int amount,
    required DateTime at,
    String note = '',
  }) {
    _checkTime(at);
    if (amount < 1) throw ArgumentError('Jumlah harus bilangan bulat positif.');
    final entry = Consumption(
      id: id ?? _store.nextId(),
      habit: habit,
      amount: amount,
      at: at,
      note: note.trim(),
    );
    if (id == null) {
      _store.consumption.add(entry);
    } else {
      final index = _store.consumption.indexWhere((item) => item.id == id);
      if (index < 0) throw StateError('Catatan tidak ditemukan.');
      _store.consumption[index] = entry;
    }
    notifyListeners();
    return entry;
  }

  Craving saveCraving({
    String? id,
    required Habit habit,
    required DateTime at,
    required Intensity intensity,
    required List<String> triggers,
    required String coping,
    required bool resisted,
  }) {
    _checkTime(at);
    final entry = Craving(
      id: id ?? _store.nextId(),
      habit: habit,
      at: at,
      intensity: intensity,
      triggers: triggers,
      coping: coping.trim(),
      resisted: resisted,
    );
    if (id == null) {
      _store.cravings.add(entry);
    } else {
      final index = _store.cravings.indexWhere((item) => item.id == id);
      if (index < 0) throw StateError('Catatan tidak ditemukan.');
      _store.cravings[index] = entry;
    }
    notifyListeners();
    return entry;
  }

  void deleteConsumption(String id) {
    _store.consumption.removeWhere((entry) => entry.id == id);
    notifyListeners();
  }

  void deleteCraving(String id) {
    _store.cravings.removeWhere((entry) => entry.id == id);
    notifyListeners();
  }

  void updateProfile({String? name, String? reason}) {
    if (name != null && name.trim().isEmpty) {
      throw ArgumentError('Nama wajib diisi.');
    }
    if (reason != null && reason.trim().isEmpty) {
      throw ArgumentError('Alasan wajib diisi.');
    }
    _store.profile = profile.updated(
      name: name?.trim(),
      reason: reason?.trim(),
    );
    final account = _account;
    if (account != null) {
      unawaited(
        _auth.updateAccount(
          account.copyWith(
            name: _store.profile.name,
            reason: _store.profile.reason,
          ),
        ),
      );
      _account = account.copyWith(
        name: _store.profile.name,
        reason: _store.profile.reason,
      );
    }
    notifyListeners();
  }

  Future<void> initializePhotoPicker() async {
    final request = ++_photoRequest;
    pickingPhoto = true;
    notifyListeners();
    try {
      // All account data resets on process restart. An interrupted selection
      // must not be attached to the new demo account.
      await _photoPicker.discardLostPhoto();
    } catch (_) {
      // No current photo or user action is affected by a missing stale result.
    } finally {
      if (request == _photoRequest) {
        pickingPhoto = false;
        notifyListeners();
      }
    }
  }

  Future<void> changeProfilePhoto() async {
    if (pickingPhoto || !signedIn) return;
    final request = ++_photoRequest;
    pickingPhoto = true;
    photoError = null;
    notifyListeners();
    try {
      final photo = await _photoPicker.pickPhoto();
      if (request != _photoRequest) return;
      // Cancelling the picker preserves the current photo.
      if (photo != null) _store.profile = profile.withPhoto(photo);
    } on PlatformException catch (error) {
      if (request != _photoRequest) return;
      photoError = error.code == 'photo_access_denied'
          ? 'Akses foto ditolak. Izinkan akses foto di pengaturan aplikasi lalu coba lagi.'
          : 'Galeri tidak dapat dibuka. Coba pilih foto lagi.';
    } catch (_) {
      if (request != _photoRequest) return;
      photoError =
          'Foto tidak dapat dibaca. Pilih gambar lain berukuran di bawah 20 MB.';
    } finally {
      if (request == _photoRequest) {
        pickingPhoto = false;
        notifyListeners();
      }
    }
  }

  void removeProfilePhoto() {
    _cancelPhotoRequest();
    _store.profile = profile.withPhoto(null);
    notifyListeners();
  }

  void _cancelPhotoRequest() {
    _photoRequest++;
    pickingPhoto = false;
    photoError = null;
  }

  void setTarget({
    required Habit habit,
    required int limit,
    required DateTime startsOn,
    DateTime? endsOn,
  }) {
    final start = dayOnly(startsOn);
    final end = endsOn == null ? null : dayOnly(endsOn);
    if (limit < 0) throw ArgumentError('Batas tidak boleh negatif.');
    if (start.isBefore(dayOnly(now))) {
      throw ArgumentError(
        'Perubahan target tidak boleh mengubah periode masa lalu.',
      );
    }
    if (end != null && !end.isAfter(start)) {
      throw ArgumentError('Tanggal selesai harus setelah tanggal mulai.');
    }
    // Keep every version. A future scheduled change must not be silently erased.
    if (_store.targets.any(
      (target) => target.habit == habit && target.startsOn.isAfter(start),
    )) {
      throw ArgumentError(
        'Sudah ada target terjadwal. Pilih tanggal setelah jadwal terakhir.',
      );
    }
    for (var i = 0; i < _store.targets.length; i++) {
      final target = _store.targets[i];
      if (target.habit == habit && target.appliesOn(start)) {
        _store.targets[i] = target.endingOn(start);
      }
    }
    _store.targets.add(
      DailyTarget(
        id: _store.nextId(),
        habit: habit,
        limit: limit,
        startsOn: start,
        endsOn: end,
      ),
    );
    notifyListeners();
  }

  void deactivateTarget(DailyTarget target, DateTime endsOn) {
    final end = dayOnly(endsOn);
    if (end.isBefore(dayOnly(now)) || end.isBefore(target.startsOn)) {
      throw ArgumentError(
        'Tanggal nonaktif tidak boleh mendahului hari ini atau tanggal mulai.',
      );
    }
    final index = _store.targets.indexWhere((entry) => entry.id == target.id);
    if (index < 0) throw StateError('Target tidak ditemukan.');
    _store.targets[index] = target.endingOn(end);
    notifyListeners();
  }

  /// Menghapus permanen target yang belum pernah berjalan (tanggal mulai
  /// masih di masa depan) karena tidak memengaruhi status/streak historis.
  void removeScheduledTarget(DailyTarget target) {
    if (!target.startsOn.isAfter(dayOnly(now))) {
      throw ArgumentError('Target sudah berjalan; gunakan nonaktifkan.');
    }
    final index = _store.targets.indexWhere((entry) => entry.id == target.id);
    if (index < 0) throw StateError('Target tidak ditemukan.');
    _store.targets.removeAt(index);
    notifyListeners();
  }

  void signOut() {
    _cancelPhotoRequest();
    signedIn = false;
    _account = null;
    recoveryCode = null;
    needsOnboarding = false;
    if (_authRepository != null) unawaited(_auth.signOut());
    notifyListeners();
  }

  /// Menghapus kode pemulihan dari memori begitu sudah ditampilkan dan
  /// tersimpan oleh pengguna, sehingga tidak bocor lewat sesudahnya.
  void clearRecoveryCode() {
    recoveryCode = null;
    notifyListeners();
  }

  void signIn() {
    signedIn = true;
    notifyListeners();
  }

  void startDemo() {
    _store = MockStore.demo(now);
    _resetNavigation();
    signedIn = true;
    _account = null;
    recoveryCode = null;
    needsOnboarding = false;
    notifyListeners();
  }

  void startNewUser({String name = 'Pengguna Baru'}) {
    _store = MockStore.empty(now, name: name);
    _resetNavigation();
    signedIn = true;
    _account = null;
    recoveryCode = null;
    needsOnboarding = true;
    notifyListeners();
  }

  void completeOnboarding(
    String reason, {
    Habit? baselineHabit,
    int? baselineValue,
  }) {
    _store.profile = profile.updated(
      reason: reason.trim().isEmpty
          ? 'Saya ingin hidup lebih sehat.'
          : reason.trim(),
    );
    needsOnboarding = false;
    final account = _account;
    if (account != null) {
      final updated = account.copyWith(
        onboardingCompleted: true,
        reason: profile.reason,
        baselineCigarette:
            baselineHabit == Habit.cigarette && baselineValue != null
            ? baselineValue
            : null,
        baselineVape: baselineHabit == Habit.vape && baselineValue != null
            ? baselineValue
            : null,
      );
      _account = updated;
      unawaited(_auth.updateAccount(updated));
    }
    notifyListeners();
  }

  /// Menghapus permanen akun terdaftar (data pada penyimpanan lokal) dari
  /// perangkat, bukan sekadar logout. Data catatan sesi hanya dalam memori.
  Future<void> deleteAccount() async {
    final account = _account;
    if (account != null) {
      await _auth.deleteAccount(id: account.id);
    }
    _store = MockStore.empty(now);
    _resetNavigation();
    signedIn = false;
    _account = null;
    recoveryCode = null;
    if (_authRepository != null) unawaited(_auth.signOut());
    needsOnboarding = false;
    notifyListeners();
  }

  void _resetNavigation() {
    _cancelPhotoRequest();
    tab = 0;
    selectedDay = dayOnly(now);
    visibleMonth = DateTime(now.year, now.month);
    chartHabit = Habit.cigarette;
  }

  @override
  void dispose() {
    _cancelPhotoRequest();
    _refresh?.cancel();
    super.dispose();
  }
}
