import 'dart:async';
import 'package:cihuy/models/records.dart';
import 'package:cihuy/providers/app_state.dart';
import 'package:cihuy/services/records_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'google_login_test.dart' show FakeGoogle, account;

class DelayedRecordsStore extends RecordsStore {
  final started = Completer<void>();
  final resume = Completer<void>();

  @override
  Future<void> save(String owner, RecordsSnapshot snapshot) async {
    started.complete();
    await resume.future;
    await super.save(owner, snapshot);
  }
}

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  AppState app(FakeGoogle repo) {
    final state = AppState(
      startSignedIn: false,
      autoTick: false,
      googleAuthRepository: repo,
    );
    addTearDown(state.dispose);
    return state;
  }

  test('hapus akun cloud memanggil server lalu menutup sesi', () async {
    final repo = FakeGoogle()..session = account('a');
    final state = app(repo);
    await state.initializeAuth();
    await pumpEventQueue();
    expect(state.signedIn, isTrue);
    expect(state.usesCloudAuth, isTrue);

    await state.deleteAccount();
    await pumpEventQueue();

    expect(repo.deleteCalls, 1);
    expect(repo.session, isNull);
    expect(state.signedIn, isFalse);
    expect(state.usesCloudAuth, isFalse);
  });

  test('kegagalan penghapusan server tidak menutup sesi pengguna', () async {
    final repo = FakeGoogle()..session = account('a');
    repo.deleteFailure = StateError('Akun belum dapat dihapus. Coba lagi.');
    final state = app(repo);
    await state.initializeAuth();
    await pumpEventQueue();

    await expectLater(state.deleteAccount(), throwsA(isA<StateError>()));
    expect(repo.deleteCalls, 1);
    expect(state.signedIn, isTrue);
    expect(state.usesCloudAuth, isTrue);
  });

  test(
    'hapus akun cloud membersihkan storage pemilik tanpa menghapus akun lain',
    () async {
      final records = RecordsStore();
      final snapshot = RecordsSnapshot(
        consumption: [
          Consumption(
            id: 'saved',
            habit: Habit.cigarette,
            amount: 2,
            at: DateTime(2026, 1, 1),
          ),
        ],
        cravings: const [],
        targets: const [],
      );
      await records.save('supabase:a', snapshot);
      await records.save('supabase:b', snapshot);
      final state = app(FakeGoogle()..session = account('a'));
      await state.initializeAuth();
      await pumpEventQueue();
      expect(state.consumption, hasLength(1));

      await state.deleteAccount();

      expect(await records.load('supabase:a'), isNull);
      expect((await records.load('supabase:b'))!.consumption, hasLength(1));
    },
  );

  test(
    'save yang sedang berjalan tidak menghidupkan kembali data akun terhapus',
    () async {
      final records = DelayedRecordsStore();
      final state = AppState(
        startSignedIn: false,
        autoTick: false,
        googleAuthRepository: FakeGoogle()..session = account('a'),
        recordsStore: records,
      );
      addTearDown(state.dispose);
      await state.initializeAuth();
      await pumpEventQueue();
      state.saveConsumption(
        habit: Habit.cigarette,
        amount: 1,
        at: DateTime(2026, 1, 1),
      );
      await records.started.future;
      final deleting = state.deleteAccount();
      await pumpEventQueue();
      expect(state.deletingAccount, isTrue);
      records.resume.complete();
      await deleting;
      expect(await records.load('supabase:a'), isNull);
      expect(state.signedIn, isFalse);
    },
  );
}
