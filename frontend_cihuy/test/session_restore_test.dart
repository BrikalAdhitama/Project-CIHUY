import 'package:cihuy/providers/app_state.dart';
import 'package:cihuy/services/local_auth_repository.dart';
import 'package:cihuy/utils/dates.dart';
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

  AppState appState({LocalAuthRepository? repository}) => AppState(
    clock: () => now,
    autoTick: false,
    startSignedIn: false,
    authRepository: repository ?? LocalAuthRepository(),
  );

  Future<void> registered(LocalAuthRepository repository) => repository.register(
    name: 'Sari Rahayu',
    email: 'sari@contoh.test',
    password: 'kata-sandi-aman',
  );

  test('cold start tanpa sesi tetap di halaman masuk tanpa data demo', () async {
    final state = appState();
    await state.initializeAuth();
    expect(state.signedIn, isFalse);
    expect(state.recordCount, 0);
    expect(state.targets, isEmpty);
  });

  test('cold start dengan sesi memulihkan akun terdaftar tanpa data demo', () async {
    final repo = LocalAuthRepository();
    await registered(repo);
    final state = appState(repository: repo);
    await state.initializeAuth();
    expect(state.signedIn, isTrue);
    expect(state.profile.name, 'Sari Rahayu');
    expect(state.profile.email, 'sari@contoh.test');
    expect(state.recordCount, 0);
    expect(state.targets, isEmpty);
  });

  test('logout menghapus sesi; cold start berikutnya di halaman masuk', () async {
    final repo = LocalAuthRepository();
    await registered(repo);
    final state = appState(repository: repo);
    await state.initializeAuth();
    expect(state.signedIn, isTrue);
    state.signOut();
    final next = appState(repository: repo);
    await next.initializeAuth();
    expect(next.signedIn, isFalse);
    expect(next.profile.name, isNot('Sari Rahayu'));
  });

  test('masuk dari store demo tidak membocorkan data demo ke akun', () async {
    final repo = LocalAuthRepository();
    final email = 'sari@contoh.test';
    await registered(repo);
    final state = appState(repository: repo);
    state.startDemo();
    expect(state.recordCount, greaterThan(0));
    await state.authenticate(email: email, password: 'kata-sandi-aman');
    expect(state.signedIn, isTrue);
    expect(state.profile.email, email);
    expect(state.recordCount, 0);
    expect(state.targets, isEmpty);
    expect(dayOnly(state.profile.startedAt), dayOnly(now));
  });
}
