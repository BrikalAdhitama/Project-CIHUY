import 'package:cihuy/models/records.dart';
import 'package:cihuy/providers/app_state.dart';
import 'package:cihuy/utils/app_theme.dart';
import 'package:cihuy/widgets/record_forms.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('id_ID');
  });

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test('hanya rokok yang ditawarkan untuk catatan baru', () {
    expect(Habit.tracked, [Habit.cigarette]);
    expect(Habit.vape.isLegacy, isTrue);
    expect(Habit.cigarette.isLegacy, isFalse);
    expect(Habit.vape.legacyLabel, 'Vape (lama)');
  });

  test('label batang menambahkan padanan bungkus bila habis dibagi', () {
    expect(cigaretteAmountLabel(5, 12), '5 batang');
    expect(cigaretteAmountLabel(12, 12), '12 batang (1 bungkus)');
    expect(cigaretteAmountLabel(24, 12), '24 batang (2 bungkus)');
    expect(cigaretteAmountLabel(20, 16), '20 batang');
    expect(cigaretteAmountLabel(3, 0), '3 batang');
  });

  test('isi per bungkus dapat diubah dan disimpan', () async {
    final app = AppState(autoTick: false);
    addTearDown(app.dispose);
    expect(app.sticksPerPack, 12);

    await app.setSticksPerPack(16);
    expect(app.sticksPerPack, 16);

    final restored = AppState(autoTick: false);
    addTearDown(restored.dispose);
    await restored.loadUnitSettings();
    expect(restored.sticksPerPack, 16);

    await expectLater(app.setSticksPerPack(0), throwsArgumentError);
    expect(app.sticksPerPack, 16);
  });

  testWidgets('catat 2 bungkus tersimpan sebagai 24 batang', (tester) async {
    final app = AppState(autoTick: false);
    addTearDown(app.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: app,
        child: MaterialApp(
          theme: cihuyTheme(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: ConsumptionForm(
                initialTime: app.now,
                initialHabit: Habit.cigarette,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Bungkus'));
    await tester.pumpAndSettle();
    expect(find.text('= 12 batang'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('consumption-amount')), '2');
    await tester.pump();
    expect(find.text('= 24 batang'), findsOneWidget);

    await tester.tap(find.byKey(const Key('save-consumption')));
    await tester.pumpAndSettle();

    expect(app.consumption.single.amount, 24);
    expect(app.consumption.single.habit, Habit.cigarette);
  });

  testWidgets('catatan vape lama tetap memakai satuan hisapan', (tester) async {
    final app = AppState(autoTick: false);
    addTearDown(app.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: app,
        child: MaterialApp(
          theme: cihuyTheme(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: ConsumptionForm(
                initialTime: app.now,
                initialHabit: Habit.vape,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bungkus'), findsNothing);
    expect(find.text('Hisapan · catatan vape lama'), findsOneWidget);
    expect(find.text('Jumlah (hisapan)'), findsOneWidget);
  });
}
