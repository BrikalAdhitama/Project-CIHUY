import 'package:cihuy/models/records.dart';
import 'package:cihuy/providers/app_state.dart';
import 'package:cihuy/screens/calendar_screen.dart';
import 'package:cihuy/services/local_auth_repository.dart';
import 'package:cihuy/services/mock_store.dart';
import 'package:cihuy/utils/dates.dart';
import 'package:cihuy/widgets/craving_pattern.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
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
  setUpAll(() => initializeDateFormatting('id_ID'));
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    FlutterSecureStoragePlatform.instance = _MemorySecureStorage();
  });

  AppState appState({LocalAuthRepository? repository, MockStore? store}) =>
      AppState(
        clock: () => now,
        store: store,
        autoTick: false,
        startSignedIn: false,
        authRepository: repository ?? LocalAuthRepository(),
      );

  group('baseline rata-rata konsumsi awal', () {
    test('disimpan dari onboarding, diperbarui, dan terisolasi per akun', () async {
      final repo = LocalAuthRepository();
      await repo.register(
        name: 'Sari Rahayu',
        email: 'sari@contoh.test',
        password: 'kata-sandi-aman',
      );
      final state = appState(repository: repo);
      await state.initializeAuth();
      state.completeOnboarding(
        'Ingin sehat',
        baselineHabit: Habit.cigarette,
        baselineValue: 12,
      );
      expect(state.baseline(Habit.cigarette), 12);
      expect(state.baseline(Habit.vape), isNull);

      // Persisten lintas instance (akun dibaca ulang dari penyimpanan).
      final loaded = await LocalAuthRepository().currentAccount();
      expect(loaded?.baselineCigarette, 12);

      // Diperbarui dari profil tanpa menyentuh catatan historis.
      final before = state.recordCount;
      state.updateBaseline(Habit.vape, 40);
      expect(state.baseline(Habit.vape), 40);
      expect(state.recordCount, before);
      final loaded2 = await LocalAuthRepository().currentAccount();
      expect(loaded2?.baselineVape, 40);

      // Akun kedua tidak mewarisi baseline akun pertama.
      final repo2 = LocalAuthRepository();
      await repo2.register(
        name: 'Budi',
        email: 'budi@contoh.test',
        password: 'kata-sandi-aman',
      );
      final state2 = appState(repository: repo2);
      await state2.initializeAuth();
      expect(state2.baseline(Habit.cigarette), isNull);
    });
  });

  group('hapus akun terdaftar', () {
    test('akun terhapus permanen, sesi jelas, akun lain tetap ada', () async {
      final repo = LocalAuthRepository();
      await repo.register(
        name: 'Sari Rahayu',
        email: 'sari@contoh.test',
        password: 'kata-sandi-aman',
      );
      await repo.register(
        name: 'Budi',
        email: 'budi@contoh.test',
        password: 'kata-sandi-aman',
      );
      final state = appState(repository: repo);
      await state.authenticate(email: 'sari@contoh.test', password: 'kata-sandi-aman');
      expect(state.hasAccount, isTrue);

      await state.deleteAccount();

      // Sesi login terhapus langsung (cek sebelum uji masuk ulang).
      final session = await repo.currentAccount();
      expect(session, isNull);
      // Akun tidak bisa dipakai masuk kembali.
      await expectLater(
        repo.signIn(
          email: 'sari@contoh.test',
          password: 'kata-sandi-aman',
        ),
        throwsA(isA<LocalAuthException>()),
      );
      // Akun lain di perangkat tetap dapat dipakai.
      await expectLater(
        repo.signIn(
          email: 'budi@contoh.test',
          password: 'kata-sandi-aman',
        ),
        completes,
      );
      // UI kembali ke halaman masuk dengan store kosong.
      expect(state.signedIn, isFalse);
      expect(state.recordCount, 0);
    });

    test('id yang tidak dikenal ditolak tanpa efek samping', () async {
      final repo = LocalAuthRepository();
      await repo.register(
        name: 'Budi',
        email: 'budi@contoh.test',
        password: 'kata-sandi-aman',
      );
      await expectLater(
        repo.deleteAccount(id: 'id-tidak-dikenal'),
        throwsA(const LocalAuthException('Akun lokal tidak ditemukan.')),
      );
      await expectLater(
        repo.signIn(
          email: 'budi@contoh.test',
          password: 'kata-sandi-aman',
        ),
        completes,
      );
    });
  });

  group('hapus target terjadwal', () {
    test('target masa depan dihapus permanen', () {
      final state = appState();
      state.setTarget(
        habit: Habit.cigarette,
        limit: 5,
        startsOn: shiftDay(now, 3),
      );
      final target = state.targets.last;
      state.removeScheduledTarget(target);
      expect(state.targets, isEmpty);
    });

    test('target yang sudah berjalan tidak boleh dihapus permanen', () {
      final state = appState();
      state.setTarget(
        habit: Habit.cigarette,
        limit: 5,
        startsOn: dayOnly(now),
      );
      final target = state.targets.last;
      expect(() => state.removeScheduledTarget(target), throwsArgumentError);
      expect(state.targets, isNotEmpty);
    });
  });

  group('widget: pola craving dan grafik 30 hari', () {
    Widget wrapper(AppState state, Widget child) =>
        ChangeNotifierProvider<AppState>.value(
          value: state,
          child: MaterialApp(home: Scaffold(body: child)),
        );

    Future<void> prepareViewport(WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }

    testWidgets('pola craving menampilkan pemicu dari catatan nyata', (
      tester,
    ) async {
      await prepareViewport(tester);
      final state = appState(store: MockStore.demo(now));
      await tester.pumpWidget(wrapper(state, const CravingPatternSummary()));
      expect(find.text('Setelah makan'), findsOneWidget);
      expect(
        find.text('Kamu menahan 7 dari 7 craving tercatat.'),
        findsOneWidget,
      );
    });

    testWidgets('pola craving menampilkan keadaan kosong', (tester) async {
      await prepareViewport(tester);
      final state = appState(store: MockStore.empty(now));
      await tester.pumpWidget(wrapper(state, const CravingPatternSummary()));
      expect(find.textContaining('Belum ada craving tercatat'), findsWidgets);
    });

    testWidgets('grafik mendukung pilihan rentang 30 hari', (tester) async {
      await prepareViewport(tester);
      final state = appState(store: MockStore.demo(now));
      await tester.pumpWidget(wrapper(state, const ConsumptionChart()));
      await tester.pumpAndSettle();
      expect(find.text('Konsumsi 7 Hari Terakhir'), findsOneWidget);
      await tester.tap(find.text('30 Hari'));
      await tester.pumpAndSettle();
      expect(find.text('Konsumsi 30 Hari Terakhir'), findsOneWidget);
      expect(find.byKey(const Key('chart-range')), findsOneWidget);
    });
  });
}
