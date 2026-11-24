import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/records.dart';
import '../services/mock_store.dart';
import '../services/progress_calculator.dart';
import '../services/profile_photo_picker.dart';
import '../services/local_auth_repository.dart';
import '../services/google_auth_repository.dart';
import '../services/records_store.dart';
import '../services/unit_settings.dart';
import '../utils/dates.dart';

class AppState extends ChangeNotifier {
  AppState({
    DateTime Function()? clock,
    MockStore? store,
    bool autoTick = true,
    ProfilePhotoPicker? photoPicker,
    LocalAuthRepository? authRepository,
    GoogleAuthRepository? googleAuthRepository,
    RecordsStore? recordsStore,
    bool startSignedIn = true,
  }) : _clock = clock ?? DateTime.now,
       localAuthEnabled = authRepository != null,
       _photoPicker = photoPicker ?? ProfilePhotoPicker(),
       _authRepository = authRepository,
       _googleAuth = googleAuthRepository ?? GoogleAuthRepository(),
       _recordsStore = recordsStore ?? RecordsStore() {
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

  /// Explicit legacy/test repository injection only; never a network fallback.
  final bool localAuthEnabled;
  late MockStore _store;
  Timer? _refresh;
  final ProfilePhotoPicker _photoPicker;
  LocalAuthRepository? _authRepository;
  LocalAuthRepository get _auth => _authRepository ??= LocalAuthRepository();
  final GoogleAuthRepository _googleAuth;
  final RecordsStore _recordsStore;
  Future<void> _saveChain = Future.value();
  GoogleAccount? _googleAccount;
  StreamSubscription<String?>? _googleSubscription;
  bool googleBusy = false;
  bool cloudSaving = false;
  bool deletingAccount = false;
  bool _disposed = false;
  int _authGeneration = 0;
  bool get usesCloudAuth => _googleAccount != null;
  bool get usesGoogleAuth =>
      _googleAccount != null && !_googleAccount!.emailPassword;
  bool get googleConfigured => _googleAuth.configured;

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

  /// Berapa batang dalam satu bungkus rokok. Nilainya hanya dipakai untuk
  /// memasukkan catatan lebih cepat; semua catatan tetap disimpan dalam batang.
  int sticksPerPack = UnitSettings.defaultSticksPerPack;
  final _unitSettings = UnitSettings();

  Future<void> loadUnitSettings() async {
    try {
      final value = await _unitSettings.load();
      if (_disposed || value == sticksPerPack) return;
      sticksPerPack = value;
      notifyListeners();
    } catch (_) {
      // Preferensi bersifat opsional; nilai bawaan tetap dipakai.
    }
  }

  Future<void> setSticksPerPack(int value) async {
    if (value < 1) {
      throw ArgumentError('Isi per bungkus minimal 1 batang.');
    }
    if (value == sticksPerPack) return;
    sticksPerPack = value;
    notifyListeners();
    await _unitSettings.save(value);
  }

  /// Akun terdaftar sedang aktif (bukan demo atau pengguna tanpa akun)?
  bool get hasAccount => _account != null || _googleAccount != null;
  String? get accountId =>
      _googleAccount == null ? _account?.id : 'supabase:${_googleAccount!.id}';

  /// Rata-rata konsumsi awal (baseline) per jenis kebiasaan. Null berarti
  /// belum diisi.
  int? baseline(Habit habit) {
    if (_googleAccount != null) return _googleAccount!.baselines[habit];
    final account = _account;
    if (account == null) return null;
    return habit == Habit.cigarette
        ? account.baselineCigarette
        : account.baselineVape;
  }

  /// Memperbarui baseline dari profil. Tidak menyentuh catatan historis.
  Future<void> updateBaseline(Habit habit, int value) {
    if (_googleAccount != null) {
      final account = _googleAccount!;
      return _saveGoogle(() async {
        await _googleAuth.saveBaseline(account.id, habit, value);
        return _googleAuth.updateProfile(account.id, reason: profile.reason);
      });
    }
    final account = _account;
    if (account == null || value < 0) return Future.value();
    final updated = account.copyWith(
      baselineCigarette: habit == Habit.cigarette ? value : null,
      baselineVape: habit == Habit.vape ? value : null,
    );
    _account = updated;
    unawaited(_auth.updateAccount(updated));
    notifyListeners();
    return Future.value();
  }

  int tab = 0;
  late DateTime selectedDay;
  late DateTime chartEnd;
  late DateTime visibleMonth;
  Habit chartHabit = Habit.cigarette;
  bool signedIn = false;
  bool needsOnboarding = false;
  bool authLoading = false;
  bool authInitializing = false;
  String? pendingSignupEmail;
  DateTime? _resendAfter;
  int get resendSeconds {
    final milliseconds = _resendAfter?.difference(now).inMilliseconds ?? 0;
    return milliseconds <= 0 ? 0 : (milliseconds / 1000).ceil();
  }

  String? authError;
  String? recoveryCode;

  Future<void> initializeAuth() async {
    unawaited(loadUnitSettings());
    if (_account != null || signedIn) return;
    authLoading = true;
    authInitializing = true;
    notifyListeners();
    try {
      if (_googleAuth.emailConfigured || _googleAuth.configured) {
        final generation = _authGeneration;
        final account = await _googleAuth.restore();
        _watchGoogleSession();
        if (_disposed || generation != _authGeneration) return;
        if (account != null) {
          _applyGoogleAccount(account);
          return;
        }
      }
      if (!localAuthEnabled) return;
      final account = await _auth.currentAccount();
      if (_disposed) return;
      if (account != null) {
        _applyAccount(account);
      } else {
        signedIn = false;
      }
    } catch (storageError) {
      // Kegagalan pemulihan sesi tetap menampilkan layar login.
      signedIn = false;
      if (_googleAuth.emailConfigured || _googleAuth.configured) {
        authError =
            'Sesi belum dapat dipulihkan. Periksa koneksi dan coba login kembali.';
      }
    } finally {
      authInitializing = false;
      authLoading = false;
      if (!_disposed) notifyListeners();
    }
  }

  void _watchGoogleSession() {
    _googleSubscription ??= _googleAuth.accountChanges.listen(
      (id) {
        if (!_disposed &&
            !googleBusy &&
            _googleAccount != null &&
            id != _googleAccount!.id) {
          _clearGoogleAccount();
          authError = 'Sesi telah berakhir. Silakan masuk kembali.';
          notifyListeners();
        }
      },
      onError: (Object _) {
        if (!_disposed) {
          authError = 'Sesi belum dapat diperbarui. Periksa koneksi.';
          notifyListeners();
        }
      },
    );
  }

  Future<void> signInWithGoogle() async {
    if (googleBusy || authLoading || signedIn || pendingSignupEmail != null) {
      return;
    }
    googleBusy = true;
    authError = null;
    final generation = ++_authGeneration;
    notifyListeners();
    try {
      final account = await _googleAuth.signIn();
      _watchGoogleSession();
      if (_disposed || generation != _authGeneration) return;
      if (_authRepository != null) await _auth.signOut();
      if (_disposed || generation != _authGeneration) return;
      _applyGoogleAccount(account);
    } on GoogleLoginCancelled {
      // Closing the account picker leaves the login screen unchanged.
    } on StateError catch (error) {
      authError = error.message;
    } catch (_) {
      authError =
          'Login Google belum berhasil. Periksa koneksi internet lalu coba lagi.';
    } finally {
      googleBusy = false;
      if (!_disposed) notifyListeners();
    }
  }

  void _applyGoogleAccount(GoogleAccount account) {
    pendingSignupEmail = null;
    _account = null;
    _googleAccount = account;
    _store = MockStore.empty(account.profile.startedAt);
    _store.profile = account.profile;
    signedIn = true;
    recoveryCode = null;
    needsOnboarding = !account.onboardingCompleted;
    _resetNavigation();
    if (profile.avatarPath != null && profile.photo == null) {
      photoError =
          'Foto belum dapat dimuat. Ketuk foto profil lalu pilih Muat ulang foto.';
    }
    unawaited(_loadRecords());
  }

  void _clearGoogleAccount() {
    pendingSignupEmail = null;
    ++_authGeneration;
    _googleAccount = null;
    _account = null;
    _store = MockStore.empty(now);
    signedIn = false;
    needsOnboarding = false;
    recoveryCode = null;
    _resetNavigation();
  }

  Future<void> _saveGoogle(Future<GoogleAccount> Function() action) async {
    if (cloudSaving || pickingPhoto) {
      throw StateError('Perubahan sedang disimpan.');
    }
    final generation = _authGeneration;
    cloudSaving = true;
    try {
      final updated = await action();
      if (_disposed || generation != _authGeneration) {
        throw StateError('Sesi berubah.');
      }
      _googleAccount = updated;
      _store.profile = updated.profile;
      needsOnboarding = !updated.onboardingCompleted;
    } catch (_) {
      throw StateError(
        'Perubahan belum tersimpan. Periksa koneksi dan coba lagi.',
      );
    } finally {
      cloudSaving = false;
      if (!_disposed) notifyListeners();
    }
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
    if (googleBusy || authLoading || signedIn) return;
    if (!localAuthEnabled) {
      await _runEmailAuth(() async {
        await _googleAuth.registerEmail(
          name: name,
          email: email,
          password: password,
        );
        pendingSignupEmail = email.trim().toLowerCase();
        _resendAfter = now.add(const Duration(seconds: 60));
      });
      return;
    }
    authLoading = true;
    authError = null;
    notifyListeners();
    if (!await _prepareLocalLogin()) return;
    try {
      final result = await _auth.register(
        name: name,
        email: email,
        password: password,
      );
      recoveryCode = result.code;
      _applyAccount(result.account);
      needsOnboarding = true;
    } on LocalAuthException catch (error) {
      authError = error.message;
    } catch (_) {
      authError = 'Pendaftaran belum tersimpan. Coba lagi.';
    } finally {
      authLoading = false;
      notifyListeners();
    }
  }

  Future<void> authenticate({
    required String email,
    required String password,
  }) async {
    if (googleBusy || authLoading || signedIn) return;
    if (!localAuthEnabled) {
      await _runEmailAuth(() async {
        try {
          final account = await _googleAuth.signInEmail(email, password);
          if (!_disposed) {
            _watchGoogleSession();
            _applyGoogleAccount(account);
          }
        } on AuthException catch (error) {
          if (error.code == 'email_not_confirmed') {
            pendingSignupEmail = email.trim().toLowerCase();
          }
          rethrow;
        }
      });
      return;
    }
    authLoading = true;
    authError = null;
    notifyListeners();
    if (!await _prepareLocalLogin()) return;
    try {
      _applyAccount(await _auth.signIn(email: email, password: password));
      _store = MockStore.empty(
        now,
        name: _account!.name,
        email: _account!.email,
        reason: _account!.reason,
      );
    } catch (error) {
      if (error is LocalAuthException) {
        authError = error.message;
      } else {
        authError = 'Penyimpanan lokal bermasalah. Coba lagi.';
      }
    } finally {
      authLoading = false;
      notifyListeners();
    }
  }

  Future<void> _runEmailAuth(Future<void> Function() action) async {
    if (authLoading || googleBusy || _disposed) return;
    authLoading = true;
    authError = null;
    notifyListeners();
    try {
      await action();
    } catch (error) {
      if (!_disposed) authError = GoogleAuthRepository.emailErrorMessage(error);
    } finally {
      authLoading = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> verifySignup(String code) async {
    final email = pendingSignupEmail;
    if (email == null || authLoading || googleBusy) return;
    if (!RegExp(r'^\d{6}$').hasMatch(code.trim())) {
      authError = 'Masukkan kode OTP 6 digit.';
      notifyListeners();
      return;
    }
    final generation = _authGeneration;
    await _runEmailAuth(() async {
      final account = await _googleAuth.verifySignup(email, code);
      if (_disposed || generation != _authGeneration) return;
      _watchGoogleSession();
      _applyGoogleAccount(account);
    });
  }

  Future<void> resendSignup() async {
    final email = pendingSignupEmail;
    if (email == null || resendSeconds > 0 || authLoading || googleBusy) return;
    // Keep the cooldown even when delivery fails; the server also limits requests.
    _resendAfter = now.add(const Duration(seconds: 60));
    await _runEmailAuth(() => _googleAuth.resendSignup(email));
  }

  void cancelSignup() {
    if (authLoading || googleBusy) return;
    ++_authGeneration;
    pendingSignupEmail = null;
    authError = null;
    notifyListeners();
  }

  Future<bool> _prepareLocalLogin() async {
    try {
      if (_googleAuth.hasSession) await _googleAuth.signOut();
      return true;
    } catch (_) {
      authError = 'Sesi sebelumnya belum dapat ditutup. Coba lagi.';
      authLoading = false;
      if (!_disposed) notifyListeners();
      return false;
    }
  }

  /// Mengganti kata sandi akun lokal yang sedang masuk. Mengembalikan true
  /// bila berhasil; kegagalan diisi ke [authError].
  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (usesCloudAuth) {
      if (authLoading || googleBusy) return false;
      await _runEmailAuth(
        () => _googleAuth.changeEmailPassword(currentPassword, newPassword),
      );
      return authError == null;
    }
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
    } catch (storageError) {
      authError =
          'Penyimpanan lokal bermasalah; ubah kata sandi tidak tersedia.';
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
    if (!localAuthEnabled) {
      authError =
          'Pemulihan kata sandi melalui email belum tersedia pada versi ini.';
      notifyListeners();
      return;
    }
    if (googleBusy || authLoading || usesGoogleAuth) return;
    authLoading = true;
    authError = null;
    notifyListeners();
    if (!await _prepareLocalLogin()) return;
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
    } catch (storageError) {
      authError =
          'Reset kata sandi tidak tersedia saat penyimpanan bermasalah.';
    } finally {
      authLoading = false;
      notifyListeners();
    }
  }

  void _applyAccount(LocalAccount account) {
    ++_authGeneration;
    _googleAccount = null;
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
    unawaited(_loadRecords());
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
    _scheduleSave();
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
    _scheduleSave();
    return entry;
  }

  void deleteConsumption(String id) {
    _store.consumption.removeWhere((entry) => entry.id == id);
    notifyListeners();
    _scheduleSave();
  }

  void deleteCraving(String id) {
    _store.cravings.removeWhere((entry) => entry.id == id);
    notifyListeners();
    _scheduleSave();
  }

  /// Mengosongkan seluruh catatan konsumsi, craving, dan target harian.
  /// Profil, akun, dan pengaturan perangkat tetap ada.
  void clearRecords() {
    _store.consumption.clear();
    _store.cravings.clear();
    _store.targets.clear();
    notifyListeners();
    _scheduleSave();
  }

  /// Menyimpan catatan aktif ke penyimpanan lokal milik akun yang sedang
  /// dipakai. Tanpa akun (demo atau belum masuk) catatan hanya di memori.
  void _scheduleSave() {
    final owner = accountId;
    if (owner == null) return;
    final snapshot = RecordsSnapshot(
      consumption: List.of(_store.consumption),
      cravings: List.of(_store.cravings),
      targets: List.of(_store.targets),
    );
    _saveChain = _saveChain
        .then((_) => _recordsStore.save(owner, snapshot))
        .catchError((Object _) {
          // Catatan tetap tersedia di memori bila penyimpanan gagal.
        });
  }

  /// Memulihkan catatan milik akun yang baru aktif. Dipanggil setelah
  /// store direset saat masuk, sehingga data akun lain tidak terbawa.
  Future<void> _loadRecords() async {
    final owner = accountId;
    if (owner == null) return;
    final generation = _authGeneration;
    try {
      final snapshot = await _recordsStore.load(owner);
      if (_disposed || generation != _authGeneration || accountId != owner) {
        return;
      }
      if (snapshot == null) return;
      _store.consumption
        ..clear()
        ..addAll(snapshot.consumption);
      _store.cravings
        ..clear()
        ..addAll(snapshot.cravings);
      _store.targets
        ..clear()
        ..addAll(normalizedTargets(snapshot.targets));
      _store.adoptExistingIds();
      notifyListeners();
    } catch (_) {
      // Data lokal bersifat opsional; kegagalan membaca tidak boleh
      // menghalangi pengguna masuk ke aplikasi.
    }
  }

  Future<void> updateProfile({String? name, String? reason}) {
    if (name != null && name.trim().isEmpty) {
      throw ArgumentError('Nama wajib diisi.');
    }
    if (reason != null && reason.trim().isEmpty) {
      throw ArgumentError('Alasan wajib diisi.');
    }
    if (_googleAccount != null) {
      final id = _googleAccount!.id;
      return _saveGoogle(
        () => _googleAuth.updateProfile(
          id,
          name: name?.trim(),
          reason: reason?.trim(),
        ),
      );
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
    return Future.value();
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
    if (pickingPhoto || cloudSaving || !signedIn) return;
    final request = ++_photoRequest;
    final account = _googleAccount;
    final previousPath = profile.avatarPath;
    pickingPhoto = true;
    photoError = null;
    notifyListeners();
    try {
      final photo = await _photoPicker.pickPhoto();
      if (request != _photoRequest) return;
      // Cancelling the picker preserves the current photo.
      if (photo != null) {
        final path = account == null
            ? null
            : await _googleAuth.uploadProfilePhoto(
                account.id,
                photo,
                previousPath: previousPath,
              );
        if (_disposed || request != _photoRequest) return;
        _store.profile = profile.withPhoto(photo, avatarPath: path);
      }
    } on PlatformException {
      if (request != _photoRequest) return;
      photoError = 'Galeri tidak dapat dibuka. Coba pilih foto lagi.';
    } on StateError catch (error) {
      if (request == _photoRequest) photoError = error.message;
    } catch (_) {
      if (request != _photoRequest) return;
      photoError = account == null
          ? 'Foto tidak dapat dibaca. Pilih gambar lain berukuran di bawah 20 MB.'
          : 'Foto belum tersimpan. Periksa koneksi internet dan coba lagi.';
    } finally {
      if (request == _photoRequest) {
        pickingPhoto = false;
        notifyListeners();
      }
    }
  }

  Future<void> removeProfilePhoto() async {
    if (pickingPhoto || cloudSaving || !signedIn) return;
    final account = _googleAccount;
    final path = profile.avatarPath;
    if (account == null || path == null) {
      _cancelPhotoRequest();
      _store.profile = profile.withPhoto(null);
      notifyListeners();
      return;
    }
    final request = ++_photoRequest;
    pickingPhoto = true;
    photoError = null;
    notifyListeners();
    try {
      await _googleAuth.removeProfilePhoto(account.id, path);
      if (!_disposed && request == _photoRequest) {
        _store.profile = profile.withPhoto(null);
      }
    } catch (_) {
      if (request == _photoRequest) {
        photoError = 'Foto belum terhapus. Periksa koneksi dan coba lagi.';
      }
    } finally {
      if (!_disposed && request == _photoRequest) {
        pickingPhoto = false;
        notifyListeners();
      }
    }
  }

  Future<void> reloadProfilePhoto() async {
    final account = _googleAccount;
    final path = profile.avatarPath;
    if (account == null || path == null || pickingPhoto || cloudSaving) return;
    final request = ++_photoRequest;
    pickingPhoto = true;
    photoError = null;
    notifyListeners();
    try {
      final bytes = await _googleAuth.loadProfilePhoto(account.id, path);
      if (!_disposed && request == _photoRequest) {
        _store.profile = profile.withPhoto(bytes, avatarPath: path);
      }
    } catch (_) {
      if (request == _photoRequest) {
        photoError = 'Foto belum dapat dimuat. Periksa koneksi dan coba lagi.';
      }
    } finally {
      if (!_disposed && request == _photoRequest) {
        pickingPhoto = false;
        notifyListeners();
      }
    }
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
    final future = _store.targets
        .where(
          (target) => target.habit == habit && target.startsOn.isAfter(start),
        )
        .map((target) => target.startsOn)
        .fold<DateTime?>(
          null,
          (earliest, date) =>
              earliest == null || date.isBefore(earliest) ? date : earliest,
        );
    if (future != null) {
      throw ArgumentError(
        'Sudah ada target terjadwal mulai ${shortDate(future)}. '
        'Batalkan atau ubah jadwal itu lebih dulu.',
      );
    }
    // Versi baru untuk tanggal mulai yang sama menggantikan versi lama, dan
    // versi yang tidak pernah berlaku dibuang. Tanpa ini, menyimpan edit
    // berulang menumpuk target ganda pada tanggal yang sama.
    _store.targets.removeWhere(
      (target) =>
          target.habit == habit &&
          (target.startsOn == start ||
              (target.endsOn != null &&
                  !target.endsOn!.isAfter(target.startsOn))),
    );
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
    _scheduleSave();
  }

  void deactivateTarget(DailyTarget target, DateTime endsOn) {
    final today = dayOnly(now);
    final end = dayOnly(endsOn);
    if (end.isBefore(today) || end.isBefore(target.startsOn)) {
      throw ArgumentError(
        'Tanggal nonaktif tidak boleh mendahului hari ini atau tanggal mulai.',
      );
    }
    // Target yang belum pernah berjalan tidak bisa berakhir pada tanggal
    // mulainya sendiri; hapus jadwalnya saja daripada menyimpan versi kosong.
    if (!end.isAfter(target.startsOn)) {
      if (target.startsOn.isAfter(today)) {
        removeScheduledTarget(target);
        return;
      }
      throw ArgumentError('Tanggal nonaktif harus setelah tanggal mulai.');
    }
    final index = _store.targets.indexWhere((entry) => entry.id == target.id);
    if (index < 0) throw StateError('Target tidak ditemukan.');
    _store.targets[index] = target.endingOn(end);
    notifyListeners();
    _scheduleSave();
  }

  /// Menghapus permanen target yang belum pernah berjalan (tanggal mulai
  /// masih di masa depan) karena tidak memengaruhi status/streak historis.
  void removeScheduledTarget(DailyTarget target) {
    final today = dayOnly(now);
    if (!target.startsOn.isAfter(today)) {
      throw ArgumentError('Target sudah berjalan; gunakan nonaktifkan.');
    }
    final index = _store.targets.indexWhere((entry) => entry.id == target.id);
    if (index < 0) throw StateError('Target tidak ditemukan.');
    _store.targets.removeAt(index);
    // Target sebelumnya mungkin dipotong tepat pada tanggal mulai jadwal ini.
    // Rentangkan kembali agar tidak ada hari tanpa target setelah pembatalan.
    DailyTarget? previous;
    for (final entry in _store.targets) {
      if (entry.habit != target.habit) continue;
      if (!entry.startsOn.isBefore(target.startsOn)) continue;
      if (previous == null || entry.startsOn.isAfter(previous.startsOn)) {
        previous = entry;
      }
    }
    if (previous != null && previous.endsOn == target.startsOn) {
      final at = _store.targets.indexWhere((entry) => entry.id == previous!.id);
      if (at >= 0) {
        _store.targets[at] = previous.withEnd(target.endsOn);
      }
    }
    notifyListeners();
    _scheduleSave();
  }

  Future<void> signOut() async {
    if (authLoading) return;
    if (usesCloudAuth || googleBusy) {
      if (googleBusy) return;
      googleBusy = true;
      _clearGoogleAccount();
      notifyListeners();
      try {
        await _googleAuth.signOut();
      } catch (_) {
        authError =
            'Sesi perangkat telah ditutup; pencabutan sesi server belum terkonfirmasi.';
      } finally {
        googleBusy = false;
        if (!_disposed) notifyListeners();
      }
      return;
    }
    ++_authGeneration;
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

  Future<void> completeOnboarding(
    String reason, {
    Habit? baselineHabit,
    int? baselineValue,
  }) {
    if (_googleAccount != null) {
      final id = _googleAccount!.id;
      return _saveGoogle(() async {
        if (baselineHabit != null && baselineValue != null) {
          await _googleAuth.saveBaseline(id, baselineHabit, baselineValue);
        }
        return _googleAuth.updateProfile(
          id,
          reason: reason.trim().isEmpty
              ? 'Saya ingin hidup lebih sehat.'
              : reason.trim(),
          onboardingCompleted: true,
        );
      });
    }
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
    return Future.value();
  }

  /// Menghapus permanen akun pengguna beserta datanya. Akun cloud dihapus di
  /// server sebelum sesi perangkat ditutup; akun lokal dihapus dari perangkat.
  Future<void> deleteAccount() async {
    if (deletingAccount) return;
    deletingAccount = true;
    notifyListeners();
    try {
      await _deleteAccount();
    } finally {
      deletingAccount = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> _deleteAccount() async {
    if (usesCloudAuth) {
      final account = _googleAccount;
      if (account == null) {
        throw StateError('Tidak ada akun cloud yang sedang aktif.');
      }
      final owner = accountId!;
      await _googleAuth.deleteAccount(account.id);
      // Invalidate pending loads and prevent new saves for the deleted owner.
      _clearGoogleAccount();
      try {
        await _saveChain;
        await _recordsStore.clear(owner);
      } catch (_) {
        throw StateError(
          'Akun server sudah dihapus, tetapi catatan perangkat belum dapat '
          'dibersihkan. Hapus data aplikasi melalui Pengaturan Android.',
        );
      } finally {
        try {
          await _googleAuth.signOut();
        } catch (_) {
          // Akun server sudah dihapus; UI tetap keluar dari akun.
        }
      }
      notifyListeners();
      return;
    }
    final account = _account;
    if (account != null) {
      await _auth.deleteAccount(id: account.id);
      try {
        await _saveChain;
        await _recordsStore.clear(account.id);
      } catch (_) {
        // Penghapusan akun tetap berlanjut walau catatan lokal gagal dihapus.
      }
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
    _disposed = true;
    ++_authGeneration;
    unawaited(_googleSubscription?.cancel());
    _cancelPhotoRequest();
    _refresh?.cancel();
    super.dispose();
  }
}
