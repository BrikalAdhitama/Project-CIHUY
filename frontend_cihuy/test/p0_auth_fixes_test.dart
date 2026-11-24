import 'package:cihuy/providers/app_state.dart';
import 'package:cihuy/services/local_auth_repository.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

class _MemorySecureStorage extends FlutterSecureStoragePlatform {
  final Map<String, String> _values = {};

  @override
  Future<void> write({
    required String key,
    required String value,
    required Map<String, String> options,
  }) async {
    _values[key] = value;
  }

  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) async => _values[key];

  @override
  Future<bool> containsKey({
    required String key,
    required Map<String, String> options,
  }) async => _values.containsKey(key);

  @override
  Future<void> delete({
    required String key,
    required Map<String, String> options,
  }) async {
    _values.remove(key);
  }

  @override
  Future<Map<String, String>> readAll({
    required Map<String, String> options,
  }) async => Map.of(_values);

  @override
  Future<void> deleteAll({required Map<String, String> options}) async {
    _values.clear();
  }
}

void main() {
  final now = DateTime(2026, 10, 20, 9);
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    FlutterSecureStoragePlatform.instance = _MemorySecureStorage();
  });

  AppState appState(LocalAuthRepository repository) => AppState(
    clock: () => now,
    autoTick: false,
    startSignedIn: false,
    authRepository: repository,
  );

  test(
    'change password then edit profile keeps the new password working',
    () async {
      final repo = LocalAuthRepository();
      final state = appState(repo);
      await state.register(
        name: 'Budi Santoso',
        email: 'budi@contoh.test',
        password: 'kata-sandi-lama',
      );
      expect(
        await state.changePassword(
          currentPassword: 'kata-sandi-lama',
          newPassword: 'kata-sandi-baru',
        ),
        isTrue,
      );
      state.updateProfile(name: 'Budi Terbaru');
      expect(
        state.profile.name,
        'Budi Terbaru',
        reason: 'in-memory profile must follow edit',
      );
      await expectLater(
        repo.signIn(email: 'budi@contoh.test', password: 'kata-sandi-lama'),
        throwsA(isA<LocalAuthException>()),
        reason: 'old password must be rejected after profile edit',
      );
      final account = await repo.signIn(
        email: 'budi@contoh.test',
        password: 'kata-sandi-baru',
      );
      expect(account.name, 'Budi Terbaru');
    },
  );

  test('recovery code is cleared from memory after sign out', () async {
    final repo = LocalAuthRepository();
    final state = appState(repo);
    await state.register(
      name: 'Sari Rahayu',
      email: 'sari@contoh.test',
      password: 'kata-sandi-aman',
    );
    expect(state.recoveryCode, isNotNull);
    state.signOut();
    expect(state.recoveryCode, isNull);
  });

  test(
    'recovery code is cleared after account switching and display',
    () async {
      final repo = LocalAuthRepository();
      final state = appState(repo);
      await state.register(
        name: 'Sari Rahayu',
        email: 'sari@contoh.test',
        password: 'kata-sandi-aman',
      );
      state.startDemo();
      expect(state.recoveryCode, isNull);
      final other = appState(LocalAuthRepository());
      await other.register(
        name: 'Budi',
        email: 'budi@contoh.test',
        password: 'kata-sandi-aman',
      );
      expect(other.recoveryCode, isNotNull);
      other.clearRecoveryCode();
      expect(other.recoveryCode, isNull);
    },
  );

  test(
    'galat pemulihan yang gagal tidak menempel setelah dialog ditutup',
    () async {
      final repo = LocalAuthRepository();
      final state = appState(repo);
      await state.register(
        name: 'Sari Rahayu',
        email: 'sari@contoh.test',
        password: 'kata-sandi-aman',
      );
      state.signOut();
      await state.resetPassword(
        email: 'sari@contoh.test',
        code: '000000000000',
        password: 'kata-sandi-baru',
      );
      expect(state.authError, 'Email atau kode pemulihan tidak sesuai.');
      state.clearAuthError();
      expect(state.authError, isNull);
      expect(
        state.signedIn,
        isFalse,
        reason: 'reset gagal tidak boleh membuat sesi',
      );
    },
  );
}
