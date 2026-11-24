import 'package:cihuy/app.dart';
import 'package:cihuy/providers/app_state.dart';
import 'package:cihuy/services/local_auth_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

class _MemorySecrets extends FlutterSecureStoragePlatform {
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
    FlutterSecureStoragePlatform.instance = _MemorySecrets();
  });

  testWidgets(
    'recovery dialog uses the auth fields and stays usable above the keyboard',
    (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);

      final state = AppState(
        startSignedIn: false,
        autoTick: false,
        authRepository: LocalAuthRepository(),
      );
      addTearDown(state.dispose);
      await tester.pumpWidget(CihuyApp(state: state));

      await tester.tap(find.text('Lupa kata sandi?'));
      await tester.pumpAndSettle();

      expect(find.text('Pulihkan kata sandi'), findsOneWidget);
      expect(find.byKey(const ValueKey('recovery-email')), findsOneWidget);
      expect(find.byKey(const ValueKey('recovery-code')), findsOneWidget);
      expect(find.byKey(const ValueKey('recovery-password')), findsOneWidget);

      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();

      // Dialog tidak boleh menghitung keyboard dua kali (lewat padding luar
      // dan inset bawaan Dialog), karena akan menyisakan ruang terlalu sempit.
      expect(tester.getSize(find.byType(Dialog)).height, greaterThan(300));

      final submit = find.byKey(const ValueKey('recovery-submit-button'));
      await tester.ensureVisible(submit);
      await tester.pumpAndSettle();
      expect(submit.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('switching auth mode keeps the entered email', (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final state = AppState(startSignedIn: false, autoTick: false);
    addTearDown(state.dispose);
    await tester.pumpWidget(CihuyApp(state: state));

    await tester.enterText(
      find.byKey(const ValueKey('auth-email')),
      'nama@contoh.test',
    );
    await tester.tap(find.text('Daftar'));
    await tester.pumpAndSettle();

    final field = tester.widget<TextFormField>(
      find.byKey(const ValueKey('auth-email')),
    );
    expect(field.controller?.text, 'nama@contoh.test');
    expect(find.byKey(const ValueKey('auth-name')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
