import 'package:cihuy/services/local_auth_repository.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    FlutterSecureStoragePlatform.instance = _MemorySecureStorage();
  });

  Future<LocalAuthRepository> registered() async {
    final repo = LocalAuthRepository(
      preferences: SharedPreferencesAsync(),
      secureStorage: const FlutterSecureStorage(),
    );
    await repo.register(
      name: 'Budi Santoso',
      email: 'budi@contoh.test',
      password: 'kata-sandi-lama',
    );
    return repo;
  }

  test('mengubah kata sandi tanpa sesi aktif ditolak', () async {
    final repo = LocalAuthRepository(
      preferences: SharedPreferencesAsync(),
      secureStorage: const FlutterSecureStorage(),
    );
    await expectLater(
      repo.changePassword(
        currentPassword: 'kata-sandi-lama',
        newPassword: 'kata-sandi-baru',
      ),
      throwsA(
        const LocalAuthException('Tidak ada sesi akun yang aktif.'),
      ),
    );
  });

  test('kata sandi saat ini yang salah tidak mengubah sesi apa pun', () async {
    final repo = await registered();
    await expectLater(
      repo.changePassword(
        currentPassword: 'bukan-kata-sandi',
        newPassword: 'kata-sandi-baru',
      ),
      throwsA(const LocalAuthException('Kata sandi saat ini tidak sesuai.')),
    );
    await expectLater(
      repo.signIn(email: 'budi@contoh.test', password: 'kata-sandi-lama'),
      completes,
    );
  });

  test('kata sandi baru yang-nilai lama sama ditolak', () async {
    final repo = await registered();
    await expectLater(
      repo.changePassword(
        currentPassword: 'kata-sandi-lama',
        newPassword: 'kata-sandi-lama',
      ),
      throwsA(
        const LocalAuthException(
          'Kata sandi baru harus berbeda dari yang sekarang.',
        ),
      ),
    );
  });

  test('kata sandi berhasil diubah; kata sandi lama tidak bisa masuk', () async {
    final repo = await registered();
    await repo.changePassword(
      currentPassword: 'kata-sandi-lama',
      newPassword: 'kata-sandi-baru',
    );
    await expectLater(
      repo.signIn(email: 'budi@contoh.test', password: 'kata-sandi-lama'),
      throwsA(
        const LocalAuthException('Email atau kata sandi tidak sesuai.'),
      ),
    );
    final account = await repo.signIn(
      email: 'budi@contoh.test',
      password: 'kata-sandi-baru',
    );
    expect(account.email, 'budi@contoh.test');
  });

  test('kode pemulihan tetap berlaku setelah mengubah kata sandi', () async {
    final repo = await registered();
    final recovery = await repo.register(
      name: 'Sari',
      email: 'sari@contoh.test',
      password: 'kata-sandi-lama',
    );
    await repo.changePassword(
      currentPassword: 'kata-sandi-lama',
      newPassword: 'kata-sandi-baru',
    );
    final reset = await repo.resetPassword(
      email: 'sari@contoh.test',
      code: recovery.code,
      password: 'kata-sandi-operasi',
    );
    expect(reset.account.email, 'sari@contoh.test');
  });
}
