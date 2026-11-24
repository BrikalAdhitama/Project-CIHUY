import 'package:cihuy/models/records.dart';
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

  AppState appState({required LocalAuthRepository repository}) => AppState(
    clock: () => now,
    autoTick: false,
    startSignedIn: false,
    authRepository: repository,
  );

  test('catatan tersimpan per akun dan pulih saat masuk lagi', () async {
    final repository = LocalAuthRepository();
    await repository.register(
      name: 'Sari Rahayu',
      email: 'sari@contoh.test',
      password: 'kata-sandi-aman',
    );

    final first = appState(repository: repository);
    addTearDown(first.dispose);
    await first.initializeAuth();
    await pumpEventQueue();
    expect(first.signedIn, isTrue);

    first.saveConsumption(
      habit: Habit.cigarette,
      amount: 3,
      at: now,
      note: 'Setelah makan',
    );
    first.saveCraving(
      habit: Habit.cigarette,
      at: now,
      intensity: Intensity.medium,
      triggers: const ['Stres'],
      coping: 'Minum air putih',
      resisted: true,
    );
    first.setTarget(habit: Habit.cigarette, limit: 5, startsOn: dayOnly(now));
    await pumpEventQueue();

    final second = appState(repository: repository);
    addTearDown(second.dispose);
    await second.initializeAuth();
    await pumpEventQueue();

    expect(second.signedIn, isTrue);
    expect(second.consumption, hasLength(1));
    expect(second.consumption.single.amount, 3);
    expect(second.consumption.single.note, 'Setelah makan');
    expect(second.cravings, hasLength(1));
    expect(second.cravings.single.triggers, ['Stres']);
    expect(second.targets, hasLength(1));
    expect(second.targets.single.limit, 5);
  });

  test('catatan satu akun tidak muncul di akun lain', () async {
    final repository = LocalAuthRepository();
    await repository.register(
      name: 'Sari Rahayu',
      email: 'sari@contoh.test',
      password: 'kata-sandi-aman',
    );

    final sari = appState(repository: repository);
    addTearDown(sari.dispose);
    await sari.initializeAuth();
    await pumpEventQueue();
    sari.saveConsumption(habit: Habit.cigarette, amount: 3, at: now);
    await pumpEventQueue();
    sari.signOut();

    await repository.register(
      name: 'Budi Santoso',
      email: 'budi@contoh.test',
      password: 'kata-sandi-aman',
    );
    final budi = appState(repository: repository);
    addTearDown(budi.dispose);
    await budi.initializeAuth();
    await pumpEventQueue();

    expect(budi.signedIn, isTrue);
    expect(budi.profile.email, 'budi@contoh.test');
    expect(budi.consumption, isEmpty);
  });

  test('hapus semua data juga mengosongkan catatan tersimpan', () async {
    final repository = LocalAuthRepository();
    await repository.register(
      name: 'Sari Rahayu',
      email: 'sari@contoh.test',
      password: 'kata-sandi-aman',
    );

    final first = appState(repository: repository);
    addTearDown(first.dispose);
    await first.initializeAuth();
    await pumpEventQueue();
    first.saveConsumption(habit: Habit.cigarette, amount: 2, at: now);
    await pumpEventQueue();
    first.clearRecords();
    await pumpEventQueue();

    final second = appState(repository: repository);
    addTearDown(second.dispose);
    await second.initializeAuth();
    await pumpEventQueue();

    expect(second.consumption, isEmpty);
    expect(second.cravings, isEmpty);
    expect(second.targets, isEmpty);
  });
}
