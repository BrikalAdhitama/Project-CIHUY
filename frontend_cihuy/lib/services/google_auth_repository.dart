import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/records.dart';

class GoogleAccount {
  const GoogleAccount({
    required this.id,
    required this.profile,
    required this.onboardingCompleted,
    this.baselines = const {},
    this.emailPassword = false,
  });
  final String id;
  final UserProfile profile;
  final bool onboardingCompleted;
  final Map<Habit, int> baselines;
  final bool emailPassword;
}

class GoogleLoginCancelled implements Exception {}

/// Sessions contain refresh tokens; persist them in platform secure storage.
class SupabaseSessionStorage extends LocalStorage {
  const SupabaseSessionStorage(
    this.key, {
    this.storage = const FlutterSecureStorage(),
  });
  final String key;
  final FlutterSecureStorage storage;
  @override
  Future<void> initialize() async {}
  @override
  Future<String?> accessToken() => storage.read(key: key);
  @override
  Future<bool> hasAccessToken() => storage.containsKey(key: key);
  @override
  Future<void> persistSession(String persistSessionString) =>
      storage.write(key: key, value: persistSessionString);
  @override
  Future<void> removePersistedSession() => storage.delete(key: key);
}

class GoogleAuthRepository {
  GoogleAuthRepository({SupabaseClient? client}) : _clientOverride = client;
  final SupabaseClient? _clientOverride;
  static const avatarBucket = 'photo-profil';
  static const maxAvatarBytes = 5 * 1024 * 1024;
  static const url = String.fromEnvironment('SUPABASE_URL');
  static const publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );
  static const webClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
  bool get configured => validConfiguration(url, publishableKey, webClientId);
  bool get emailConfigured =>
      _clientOverride != null || validEmailConfiguration(url, publishableKey);
  static bool validEmailConfiguration(String url, String key) {
    final uri = Uri.tryParse(url);
    return uri?.scheme == 'https' &&
        uri!.host.isNotEmpty &&
        key.startsWith('sb_publishable_') &&
        key.length > 15;
  }

  static bool validConfiguration(String url, String key, String clientId) {
    final uri = Uri.tryParse(url);
    return uri?.scheme == 'https' &&
        uri!.host.isNotEmpty &&
        key.startsWith('sb_publishable_') &&
        key.length > 15 &&
        RegExp(
          r'^[0-9]+-[A-Za-z0-9_-]+\.apps\.googleusercontent\.com$',
        ).hasMatch(clientId);
  }

  bool _initialized = false;
  static Future<void>? _googleInitialization;
  static Future<void>? _supabaseInitialization;
  SupabaseClient get _client => _clientOverride ?? Supabase.instance.client;
  bool get hasSession => _initialized && _client.auth.currentSession != null;
  String? get currentUserId =>
      _initialized ? _client.auth.currentUser?.id : null;
  Stream<String?> get accountChanges => _client.auth.onAuthStateChange
      .map((event) => event.session?.user.id)
      .distinct();

  Future<void> initialize() async {
    if (_initialized) return;
    if (!emailConfigured) {
      throw StateError(
        'Konfigurasi autentikasi belum tersedia. Lengkapi '
        'supabase.local.json lalu jalankan aplikasi dengan '
        '--dart-define-from-file=supabase.local.json.',
      );
    }
    if (_clientOverride != null) {
      _initialized = true;
      return;
    }
    try {
      await (_supabaseInitialization ??= Supabase.initialize(
        url: url,
        publishableKey: publishableKey,
        debug: false,
        authOptions: FlutterAuthClientOptions(
          detectSessionInUri: false,
          localStorage: SupabaseSessionStorage(
            'cihuy_supabase_${Uri.parse(url).host}',
          ),
        ),
      ));
    } catch (_) {
      _supabaseInitialization = null;
      rethrow;
    }
    _initialized = true;
  }

  Future<GoogleAccount?> restore() async {
    await initialize();
    if (!hasSession) return null;
    if (_client.auth.currentSession!.isExpired) {
      await _client.auth.refreshSession();
    }
    // Validate with Auth before exposing an account after a cold start.
    final user = (await _client.auth.getUser()).user;
    if (user == null) return null;
    return _load(user.id, user.email ?? '');
  }

  Future<GoogleAccount> signIn() async {
    if (!configured) throw StateError('Login Google belum tersedia.');
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      throw StateError('Login Google ini tersedia untuk aplikasi Android.');
    }
    await initialize();
    final google = GoogleSignIn.instance;
    _googleInitialization ??= google.initialize(serverClientId: webClientId);
    try {
      await _googleInitialization;
    } catch (_) {
      _googleInitialization = null;
      throw StateError(
        'Google belum dapat disiapkan. Periksa Web Client ID OAuth dan '
        'Google Play Services, lalu coba lagi.',
      );
    }
    try {
      final account = await google.authenticate(
        scopeHint: const ['email', 'profile'],
      );
      final idToken = account.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw StateError(
          'Google belum memberikan token login. Periksa konfigurasi OAuth '
          'Android (package dan SHA-1) lalu coba lagi.',
        );
      }
      final result = await _client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
      );
      final user = result.user;
      if (user == null) {
        throw StateError('Sesi Supabase belum tersedia. Coba login kembali.');
      }
      return await _load(user.id, user.email ?? '');
    } on GoogleSignInException catch (error) {
      switch (error.code) {
        case GoogleSignInExceptionCode.canceled:
          throw GoogleLoginCancelled();
        case GoogleSignInExceptionCode.interrupted:
          throw StateError('Login Google terhenti. Silakan coba lagi.');
        case GoogleSignInExceptionCode.uiUnavailable:
          throw StateError(
            'Jendela pemilih akun Google tidak dapat dibuka. Tutup aplikasi '
            'lain yang sedang memakai layar lalu coba lagi.',
          );
        case GoogleSignInExceptionCode.clientConfigurationError:
        case GoogleSignInExceptionCode.providerConfigurationError:
          throw StateError(
            'Konfigurasi Google Sign-In tidak cocok. Periksa Web Client ID, '
            'package com.brikal.cihuy, dan SHA-1 sertifikat build.',
          );
        default:
          throw StateError(
            'Login Google belum berhasil. Periksa koneksi internet dan '
            'konfigurasi OAuth Android.',
          );
      }
    } on AuthException catch (error) {
      throw StateError(_authErrorMessage(error));
    }
  }

  static String _authErrorMessage(AuthException error) {
    final message = error.message.toLowerCase();
    if (message.contains('provider is not enabled') ||
        message.contains('unsupported provider')) {
      return 'Provider Google belum diaktifkan di Supabase.';
    }
    if (message.contains('network') ||
        message.contains('socket') ||
        message.contains('failed host lookup') ||
        message.contains('connection')) {
      return 'Tidak dapat terhubung ke server CIHUY. Periksa koneksi internet.';
    }
    return 'Login Google ditolak server. Periksa konfigurasi provider Google '
        'di Supabase dan daftar penguji OAuth.';
  }

  /// Registration must never establish a session before email verification.
  Future<void> registerEmail({
    required String name,
    required String email,
    required String password,
  }) async {
    await initialize();
    final result = await _client.auth.signUp(
      email: email.trim().toLowerCase(),
      password: password,
      data: {'full_name': name.trim()},
    );
    if (result.session != null) {
      await _client.auth.signOut(scope: SignOutScope.local);
      throw StateError(
        'Verifikasi email belum aktif. Hubungi pengelola aplikasi.',
      );
    }
  }

  Future<void> resendSignup(String email) async {
    await initialize();
    await _client.auth.resend(
      type: OtpType.signup,
      email: email.trim().toLowerCase(),
    );
  }

  Future<GoogleAccount> verifySignup(String email, String token) async {
    await initialize();
    final result = await _client.auth.verifyOTP(
      email: email.trim().toLowerCase(),
      token: token.trim(),
      type: OtpType.signup,
    );
    return _loadAuthenticated(result);
  }

  Future<GoogleAccount> signInEmail(String email, String password) async {
    await initialize();
    final result = await _client.auth.signInWithPassword(
      email: email.trim().toLowerCase(),
      password: password,
    );
    return _loadAuthenticated(result);
  }

  Future<GoogleAccount> _loadAuthenticated(AuthResponse result) async {
    final user = result.user;
    if (user == null ||
        result.session == null ||
        user.emailConfirmedAt == null) {
      await _client.auth.signOut(scope: SignOutScope.local);
      throw StateError(
        'Email belum terverifikasi. Masukkan kode dari emailmu.',
      );
    }
    try {
      return await _load(user.id, user.email ?? '');
    } catch (_) {
      // Do not leave a persisted session behind a failed profile load.
      await _client.auth.signOut(scope: SignOutScope.local);
      throw StateError(
        'Profil belum dapat dimuat. Coba masuk dengan email dan kata sandi.',
      );
    }
  }

  Future<void> changeEmailPassword(
    String currentPassword,
    String newPassword,
  ) async {
    final email = _client.auth.currentUser?.email;
    if (email == null) throw StateError('Silakan masuk kembali.');
    await _client.auth.signInWithPassword(
      email: email,
      password: currentPassword,
    );
    await _client.auth.updateUser(UserAttributes(password: newPassword));
  }

  static String emailErrorMessage(Object error) {
    if (error is AuthException) {
      switch (error.code) {
        case 'email_not_confirmed':
          return 'Email belum terverifikasi. Masukkan OTP atau kirim ulang kode.';
        case 'invalid_credentials':
          return 'Email atau kata sandi tidak sesuai.';
        case 'otp_expired':
        case 'otp_disabled':
          return 'Kode salah atau sudah kedaluwarsa. Periksa kode atau minta kode baru.';
        case 'over_email_send_rate_limit':
        case 'over_request_rate_limit':
          return 'Terlalu banyak permintaan. Tunggu sebentar sebelum mencoba lagi.';
        case 'user_already_exists':
        case 'email_exists':
          return 'Email sudah terdaftar. Silakan masuk.';
        case 'weak_password':
          return 'Kata sandi belum memenuhi persyaratan keamanan.';
        case 'reauthentication_needed':
          return 'Silakan keluar dan masuk kembali sebelum mengubah kata sandi.';
      }
      // Supabase membalas 500 `unexpected_failure` saat server emailnya gagal
      // mengirim pesan verifikasi. Bukan salah isian pengguna, jadi jangan
      // tampilkan pesan generik yang menyuruh memeriksa formulir.
      final detail = error.message.toLowerCase();
      if (detail.contains('sending confirmation email') ||
          detail.contains('error sending')) {
        return 'Server CIHUY gagal mengirim email verifikasi. Coba lagi beberapa '
            'saat lagi, atau masuk dengan Google.';
      }
      return 'Permintaan belum berhasil. Periksa isian dan coba lagi nanti.';
    }
    if (error is StateError) return error.message;
    return 'Tidak dapat terhubung. Periksa koneksi internet dan coba lagi.';
  }

  void _requireOwner(String id) {
    if (currentUserId != id) {
      throw StateError('Sesi berubah. Silakan masuk kembali.');
    }
  }

  Future<GoogleAccount> _load(String id, String email) async {
    _requireOwner(id);
    final row = await _client.from('profiles').select().eq('id', id).single();
    final habits = await _client
        .from('consumption_habits')
        .select('kind,baseline_daily')
        .eq('user_id', id);
    _requireOwner(id);
    final displayName = (row['display_name'] as String?)?.trim() ?? '';
    final startedAt = DateTime.tryParse(
      (row['started_at'] as String?) ?? '',
    )?.toLocal();
    final avatarPath = (row['avatar_url'] as String?)?.trim();
    Uint8List? photo;
    if (avatarPath != null && avatarPath.isNotEmpty) {
      try {
        photo = await loadProfilePhoto(id, avatarPath);
      } catch (_) {
        // Storage failure must not prevent login. The profile offers a retry.
      }
    }
    _requireOwner(id);
    return GoogleAccount(
      id: id,
      emailPassword:
          _client.auth.currentUser?.appMetadata['provider'] == 'email',
      profile: UserProfile(
        avatarPath: avatarPath?.isNotEmpty == true ? avatarPath : null,
        photo: photo,
        name: displayName.isEmpty ? 'Pengguna CIHUY' : displayName,
        email: (row['email'] as String?) ?? email,
        reason: (row['reason'] as String?)?.trim().isNotEmpty == true
            ? (row['reason'] as String).trim()
            : 'Saya ingin hidup lebih sehat.',
        startedAt: startedAt ?? DateTime.now(),
      ),
      onboardingCompleted: row['onboarding_completed'] == true,
      baselines: {
        for (final habit in habits)
          if (habit['baseline_daily'] != null)
            Habit.values.byName(habit['kind']): habit['baseline_daily'] as int,
      },
    );
  }

  static bool ownsAvatar(String id, String path) =>
      path.startsWith('$id/') &&
      path.split('/').length == 2 &&
      RegExp(r'^[a-zA-Z0-9_-]+\.png$').hasMatch(path.split('/').last);

  static void validateAvatar(Uint8List bytes) {
    const signature = [137, 80, 78, 71, 13, 10, 26, 10];
    if (bytes.length < 24 ||
        bytes.length > maxAvatarBytes ||
        !listEquals(bytes.take(8).toList(), signature)) {
      throw StateError(
        'Foto tidak valid atau lebih besar dari 5 MB. Pilih foto lain.',
      );
    }
    final header = ByteData.sublistView(bytes);
    final width = header.getUint32(16);
    final height = header.getUint32(20);
    if (width == 0 || height == 0 || width > 1024 || height > 1024) {
      throw StateError('Ukuran foto tidak valid. Pilih ulang foto profil.');
    }
  }

  Future<Uint8List> loadProfilePhoto(String id, String path) async {
    _requireOwner(id);
    if (!ownsAvatar(id, path)) {
      throw StateError('Path foto profil tidak valid.');
    }
    final bytes = await _client.storage
        .from(avatarBucket)
        .download(path)
        .timeout(const Duration(seconds: 30));
    _requireOwner(id);
    validateAvatar(bytes);
    return bytes;
  }

  Future<String> uploadProfilePhoto(
    String id,
    Uint8List bytes, {
    String? previousPath,
  }) async {
    _requireOwner(id);
    validateAvatar(bytes);
    final random = Random.secure();
    final suffix = List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    final path = '$id/$suffix.png';
    try {
      await _client.storage
          .from(avatarBucket)
          .uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'image/png',
              upsert: false,
            ),
          )
          .timeout(const Duration(seconds: 30));
    } on StorageException {
      throw StateError(
        'Foto belum terunggah. Periksa koneksi dan izin penyimpanan akun.',
      );
    }
    await _writeAvatarPath(id, path, previousPath);
    await _discardOldAvatar(id, previousPath);
    return path;
  }

  Future<void> removeProfilePhoto(String id, String previousPath) async {
    await _writeAvatarPath(id, null, previousPath);
    await _discardOldAvatar(id, previousPath);
  }

  Future<void> _writeAvatarPath(
    String id,
    String? path,
    String? previousPath,
  ) async {
    _requireOwner(id);
    var query = _client
        .from('profiles')
        .update({'avatar_url': path})
        .eq('id', id);
    // A stale device must not overwrite a newer avatar selected elsewhere.
    query = previousPath == null
        ? query.isFilter('avatar_url', null)
        : query.eq('avatar_url', previousPath);
    try {
      await query.select('id').single().timeout(const Duration(seconds: 30));
    } catch (_) {
      // A timeout can happen AFTER commit. Never delete the new object here.
      throw StateError(
        'Perubahan foto belum terkonfirmasi. Buka ulang aplikasi sebelum mencoba lagi.',
      );
    }
    _requireOwner(id);
  }

  Future<void> _discardOldAvatar(String id, String? path) async {
    if (path == null || !ownsAvatar(id, path) || currentUserId != id) return;
    try {
      await _client.storage
          .from(avatarBucket)
          .remove([path])
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      // The profile is already committed; cleanup failure must not undo it.
    }
  }

  Future<GoogleAccount> updateProfile(
    String id, {
    String? name,
    String? reason,
    bool? onboardingCompleted,
  }) async {
    _requireOwner(id);
    await _client
        .from('profiles')
        .update({
          'display_name': ?name,
          'reason': ?reason,
          'onboarding_completed': ?onboardingCompleted,
        })
        .eq('id', id)
        .select('id')
        .single();
    return _load(id, _client.auth.currentUser!.email ?? '');
  }

  Future<void> saveBaseline(String id, Habit habit, int value) async {
    _requireOwner(id);
    if (value < 0) throw ArgumentError('Baseline tidak boleh negatif.');
    final existing = await _client
        .from('consumption_habits')
        .select('id')
        .eq('user_id', id)
        .eq('kind', habit.name)
        .maybeSingle();
    _requireOwner(id);
    if (existing == null) {
      await _client.from('consumption_habits').insert({
        'user_id': id,
        'kind': habit.name,
        'baseline_daily': value,
      });
    } else {
      await _client
          .from('consumption_habits')
          .update({'baseline_daily': value})
          .eq('id', existing['id'])
          .eq('user_id', id)
          .select('id')
          .single();
    }
  }

  /// Menghapus akun cloud beserta datanya. Penghapusan user auth membutuhkan
  /// service role, jadi dilakukan Edge Function `delete-account`; server
  /// memverifikasi token pengguna sebelum menghapus apa pun.
  Future<void> deleteAccount(String id) async {
    _requireOwner(id);
    await initialize();
    _requireOwner(id);
    final FunctionResponse response;
    try {
      response = await _client.functions
          .invoke('delete-account')
          .timeout(const Duration(seconds: 30));
    } on TimeoutException {
      throw StateError('Penghapusan akun melebihi waktu tunggu. Coba lagi.');
    } catch (_) {
      throw StateError(
        'Akun belum dapat dihapus. Periksa koneksi lalu coba lagi.',
      );
    }
    if (response.status < 200 || response.status >= 300) {
      throw StateError('Akun belum dapat dihapus. Coba lagi.');
    }
  }

  Future<void> signOut() async {
    try {
      if (_initialized) await _client.auth.signOut(scope: SignOutScope.local);
    } finally {
      if (_initialized) {
        await SupabaseSessionStorage(
          'cihuy_supabase_${Uri.parse(url).host}',
        ).removePersistedSession();
      }
      if (_googleInitialization != null) {
        try {
          await GoogleSignIn.instance.signOut();
        } catch (_) {}
      }
    }
  }
}
