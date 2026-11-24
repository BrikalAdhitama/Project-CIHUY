import 'dart:async';
import 'package:cihuy/app.dart';
import 'package:cihuy/models/records.dart';
import 'package:cihuy/providers/app_state.dart';
import 'package:cihuy/services/google_auth_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

GoogleAccount account(String id, {bool onboarded = true}) => GoogleAccount(
  id: id,
  profile: UserProfile(
    name: 'User $id',
    email: '$id@example.invalid',
    reason: 'Alasan $id',
    startedAt: DateTime(2026, 9, 5),
  ),
  onboardingCompleted: onboarded,
);

class FakeGoogle extends GoogleAuthRepository {
  bool available = true;
  GoogleAccount? session;
  GoogleAccount next = account('a');
  Object? failure;
  Object? saveFailure;
  int loginCalls = 0;
  Completer<GoogleAccount>? pendingLogin;
  Completer<GoogleAccount>? pendingSave;
  final changes = StreamController<String?>.broadcast(sync: true);
  @override
  bool get configured => available;
  @override
  bool get hasSession => session != null;
  @override
  String? get currentUserId => session?.id;
  @override
  Stream<String?> get accountChanges => changes.stream;
  @override
  Future<GoogleAccount?> restore() async => session;
  @override
  Future<GoogleAccount> signIn() async {
    loginCalls++;
    if (failure != null) throw failure!;
    session = pendingLogin == null ? next : await pendingLogin!.future;
    return session!;
  }

  int deleteCalls = 0;
  Object? deleteFailure;

  @override
  Future<void> deleteAccount(String id) async {
    deleteCalls++;
    if (deleteFailure != null) throw deleteFailure!;
  }

  @override
  Future<void> signOut() async {
    session = null;
    changes.add(null);
  }

  @override
  Future<void> saveBaseline(String id, Habit habit, int value) async {
    if (saveFailure != null) throw saveFailure!;
    session = GoogleAccount(
      id: id,
      profile: session!.profile,
      onboardingCompleted: session!.onboardingCompleted,
      baselines: {...session!.baselines, habit: value},
    );
  }

  @override
  Future<GoogleAccount> updateProfile(
    String id, {
    String? name,
    String? reason,
    bool? onboardingCompleted,
  }) async {
    if (saveFailure != null) throw saveFailure!;
    if (pendingSave != null) return pendingSave!.future;
    return session = GoogleAccount(
      id: id,
      profile: session!.profile.updated(name: name, reason: reason),
      onboardingCompleted: onboardingCompleted ?? session!.onboardingCompleted,
      baselines: session!.baselines,
    );
  }
}

class MemorySecrets extends FlutterSecureStoragePlatform {
  final values = <String, String>{};
  @override
  Future<Map<String, String>> readAll({
    required Map<String, String> options,
  }) async => Map.of(values);
  @override
  Future<void> deleteAll({required Map<String, String> options}) async {
    values.clear();
  }

  @override
  Future<void> write({
    required String key,
    required String value,
    required Map<String, String> options,
  }) async {
    values[key] = value;
  }

  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) async => values[key];
  @override
  Future<bool> containsKey({
    required String key,
    required Map<String, String> options,
  }) async => values.containsKey(key);
  @override
  Future<void> delete({
    required String key,
    required Map<String, String> options,
  }) async {
    values.remove(key);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    FlutterSecureStoragePlatform.instance = MemorySecrets();
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

  test('only public client configuration is accepted', () {
    const url = 'https://example.supabase.co';
    const id = '123-test.apps.googleusercontent.com';
    expect(
      GoogleAuthRepository.validConfiguration(
        url,
        'sb_publishable_example',
        id,
      ),
      isTrue,
    );
    expect(
      GoogleAuthRepository.validConfiguration(url, 'sb_secret_example', id),
      isFalse,
    );
    expect(
      GoogleAuthRepository.validConfiguration(
        'http://example.com',
        'sb_publishable_example',
        id,
      ),
      isFalse,
    );
    expect(
      GoogleAuthRepository.validConfiguration(
        url,
        'sb_publishable_example',
        'CIHUY',
      ),
      isFalse,
    );
  });

  test(
    'secure session persistence is isolated by project and removed on logout',
    () async {
      const a = SupabaseSessionStorage('test-a');
      const b = SupabaseSessionStorage('test-b');
      await a.persistSession('test-session');
      expect(await a.accessToken(), 'test-session');
      expect(await b.accessToken(), isNull);
      await a.removePersistedSession();
      expect(await a.hasAccessToken(), isFalse);
    },
  );

  test(
    'login restores real profile and start date, never mock records',
    () async {
      final repo = FakeGoogle();
      final state = app(repo);
      await state.signInWithGoogle();
      expect(state.signedIn, isTrue);
      expect(state.accountId, 'supabase:a');
      expect(state.profile.startedAt, DateTime(2026, 9, 5));
      expect(state.consumption, isEmpty);
      final restored = app(repo);
      await restored.initializeAuth();
      expect(restored.accountId, 'supabase:a');
      expect(restored.profile.name, 'User a');
      expect(restored.authLoading, isFalse);
    },
  );

  test(
    'cancel, failure and duplicate taps do not create a local fallback account',
    () async {
      final repo = FakeGoogle()..failure = GoogleLoginCancelled();
      final state = app(repo);
      await state.signInWithGoogle();
      expect(state.signedIn, isFalse);
      expect(state.authError, isNull);
      repo.failure = Exception('private token payload');
      await state.signInWithGoogle();
      expect(state.hasAccount, isFalse);
      expect(state.authError, isNot(contains('private token payload')));
      repo.failure = null;
      repo.pendingLogin = Completer();
      final first = state.signInWithGoogle();
      await state.signInWithGoogle();
      expect(repo.loginCalls, 3);
      repo.pendingLogin!.complete(account('a'));
      await first;
      expect(state.googleBusy, isFalse);
    },
  );

  test(
    'logout and switching account clear previous tracking and profile',
    () async {
      final repo = FakeGoogle();
      final state = app(repo);
      await state.signInWithGoogle();
      state.saveConsumption(habit: Habit.cigarette, amount: 2, at: state.now);
      await state.signOut();
      expect(repo.session, isNull);
      expect(state.accountId, isNull);
      expect(state.consumption, isEmpty);
      repo.next = account('b');
      await state.signInWithGoogle();
      expect(state.profile.email, 'b@example.invalid');
      expect(state.recordCount, 0);
    },
  );

  test('expired remote session clears account and tracking', () async {
    final repo = FakeGoogle();
    final state = app(repo);
    await state.signInWithGoogle();
    state.saveConsumption(habit: Habit.vape, amount: 2, at: state.now);
    repo.session = null;
    repo.changes.add(null);
    expect(state.signedIn, isFalse);
    expect(state.recordCount, 0);
  });

  test(
    'onboarding/profile writes persist; a failed write preserves the old profile',
    () async {
      final repo = FakeGoogle()..next = account('a', onboarded: false);
      final state = app(repo);
      await state.signInWithGoogle();
      expect(state.needsOnboarding, isTrue);
      await state.completeOnboarding(
        'Keluarga',
        baselineHabit: Habit.cigarette,
        baselineValue: 8,
      );
      expect(state.needsOnboarding, isFalse);
      expect(state.baseline(Habit.cigarette), 8);
      await state.updateProfile(name: 'Nama baru');
      final restored = app(repo);
      await restored.initializeAuth();
      expect(restored.profile.name, 'Nama baru');
      expect(restored.profile.reason, 'Keluarga');
      repo.saveFailure = Exception('offline');
      await expectLater(
        state.updateProfile(name: 'Not saved'),
        throwsStateError,
      );
      expect(state.profile.name, 'Nama baru');
    },
  );

  test('late profile save cannot restore an account after logout', () async {
    final repo = FakeGoogle();
    final state = app(repo);
    await state.signInWithGoogle();
    repo.pendingSave = Completer();
    final save = state.updateProfile(name: 'Late');
    final assertion = expectLater(save, throwsStateError);
    await state.signOut();
    repo.pendingSave!.complete(account('a'));
    await assertion;
    expect(state.signedIn, isFalse);
    expect(state.accountId, isNull);
  });

  testWidgets(
    'Google button signs in without validating local password fields',
    (tester) async {
      final repo = FakeGoogle();
      final state = app(repo);
      await tester.pumpWidget(CihuyApp(state: state));
      await tester.tap(find.byKey(const ValueKey('google-login')));
      await tester.pumpAndSettle();
      expect(state.signedIn, isTrue);
      expect(find.text('Beranda'), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('Google stays visible without config and never starts sign in', (
    tester,
  ) async {
    final repo = FakeGoogle()..available = false;
    final state = app(repo);
    await tester.pumpWidget(CihuyApp(state: state));
    await tester.tap(find.byKey(const ValueKey('google-login')));
    await tester.pump();
    expect(
      find.text('Login Google belum tersedia pada versi aplikasi ini.'),
      findsOneWidget,
    );
    expect(repo.loginCalls, 0);
    expect(state.signedIn, isFalse);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('registration is discoverable and validates confirmation', (
    tester,
  ) async {
    final state = app(FakeGoogle());
    await tester.pumpWidget(CihuyApp(state: state));
    await tester.tap(find.text('Daftar'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('auth-name')), 'Nama');
    await tester.enterText(
      find.byKey(const ValueKey('auth-email')),
      'test@example.invalid',
    );
    await tester.enterText(
      find.byKey(const ValueKey('auth-password')),
      'password123',
    );
    await tester.enterText(
      find.byKey(const ValueKey('auth-confirm')),
      'different',
    );
    await tester.ensureVisible(find.byKey(const ValueKey('auth-submit')));
    await tester.tap(find.byKey(const ValueKey('auth-submit')));
    await tester.pumpAndSettle();
    expect(find.text('Konfirmasi kata sandi belum sama'), findsOneWidget);
    expect(state.signedIn, isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'auth remains usable on small screens with keyboard and large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final state = app(FakeGoogle());
      await tester.pumpWidget(CihuyApp(state: state));
      await tester.ensureVisible(find.text('Daftar'));
      await tester.tap(find.text('Daftar'));
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 250);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('auth-submit')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('auth-submit')).hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
