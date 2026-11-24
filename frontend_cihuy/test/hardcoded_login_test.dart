import 'package:cihuy/providers/app_state.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// Penyimpanan yang selalu gagal — mensimulasikan plugin hilang di build APK.
class _BrokenSecureStorage extends FlutterSecureStoragePlatform {
  Never _fail() => throw PlatformException(
    code: 'missing_plugin',
    message: 'secure storage tidak tersedia',
  );

  @override
  Future<void> write({
    required String key,
    required String value,
    required Map<String, String> options,
  }) => _fail();

  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) => _fail();

  @override
  Future<bool> containsKey({
    required String key,
    required Map<String, String> options,
  }) => _fail();

  @override
  Future<void> delete({
    required String key,
    required Map<String, String> options,
  }) => _fail();

  @override
  Future<Map<String, String>> readAll({required Map<String, String> options}) =>
      _fail();

  @override
  Future<void> deleteAll({required Map<String, String> options}) => _fail();
}

void main() {
  final now = DateTime(2026, 10, 20, 9);
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    FlutterSecureStoragePlatform.instance = _BrokenSecureStorage();
  });

  AppState appState() =>
      AppState(clock: () => now, autoTick: false, startSignedIn: false);

  test('cold start tidak menggantung saat penyimpanan rusak', () async {
    final state = appState();
    await state.initializeAuth();
    expect(state.authLoading, isFalse);
    expect(state.signedIn, isFalse);
    expect(state.authError, isNull);
  });

  test(
    'legacy hardcoded credentials never bypass Supabase authentication',
    () async {
      final state = appState();
      await state.initializeAuth();
      await state.authenticate(
        email: 'sbrikal@gmail.com',
        password: 'cihuy12345',
      );
      expect(state.signedIn, isFalse);
      expect(state.hasAccount, isFalse);
      expect(state.needsOnboarding, isFalse);
      expect(state.authError, isNotNull);
      expect(state.profile.name, isNotEmpty);
    },
  );

  test('kredensial selain hardcode ditolak', () async {
    final state = appState();
    await state.initializeAuth();
    await state.authenticate(
      email: 'sbrikal@gmail.com',
      password: 'salahbanget',
    );
    expect(state.signedIn, isFalse);
    expect(state.authError, isNotNull);
  });

  test(
    'registration failure never creates an in-memory verified account',
    () async {
      final state = appState();
      await state.register(
        name: 'Budi Santoso',
        email: 'budi@contoh.test',
        password: 'kata-sandi-aman',
      );
      expect(state.signedIn, isFalse);
      expect(state.recoveryCode, isNull);
      expect(state.needsOnboarding, isFalse);
      expect(state.hasAccount, isFalse);
      expect(state.authError, isNotNull);
    },
  );
}
