import 'package:cihuy/models/records.dart';
import 'package:cihuy/providers/app_state.dart';
import 'package:cihuy/screens/targets_screen.dart';
import 'package:cihuy/services/mock_store.dart';
import 'package:cihuy/utils/dates.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID');
  });

  test('tanggal mulai yang sama menggantikan target, bukan menumpuk', () {
    final state = AppState(autoTick: false);
    addTearDown(state.dispose);
    final today = dayOnly(state.now);
    state.setTarget(habit: Habit.cigarette, limit: 5, startsOn: today);
    state.setTarget(habit: Habit.cigarette, limit: 7, startsOn: today);
    state.setTarget(habit: Habit.cigarette, limit: 9, startsOn: today);
    expect(state.targets.length, 1);
    expect(state.targets.single.limit, 9);
  });

  test('mengedit target aktif menyisakan satu target berjalan', () {
    final now = DateTime(2026, 11, 17, 10);
    final state = AppState(
      store: MockStore.demo(now),
      clock: () => now,
      autoTick: false,
    );
    addTearDown(state.dispose);
    final today = dayOnly(now);
    final active = state.targets
        .where((target) => target.habit == Habit.cigarette)
        .single;
    expect(active.appliesOn(today), isTrue);

    state.setTarget(habit: Habit.cigarette, limit: 9, startsOn: today);

    final current = state.targets
        .where(
          (target) =>
              target.habit == Habit.cigarette &&
              (target.endsOn == null || target.endsOn!.isAfter(today)),
        )
        .toList();
    expect(current.length, 1);
    expect(current.single.limit, 9);
    expect(state.progress.targetOn(today, Habit.cigarette)!.limit, 9);
  });

  test('target ganda dan versi yang tidak pernah berlaku dibersihkan', () {
    final start = DateTime(2026, 1, 1);
    final targets = [
      DailyTarget(
        id: 'lama',
        habit: Habit.cigarette,
        limit: 5,
        startsOn: start,
      ),
      DailyTarget(
        id: 'ganda',
        habit: Habit.cigarette,
        limit: 7,
        startsOn: start,
      ),
      DailyTarget(
        id: 'tidak-berlaku',
        habit: Habit.cigarette,
        limit: 3,
        startsOn: start,
        endsOn: start,
      ),
    ];
    final clean = normalizedTargets(targets);
    expect(clean.length, 1);
    expect(clean.single.id, 'ganda');
    expect(clean.single.limit, 7);
  });

  test('target terjadwal tidak tergeser diam-diam saat menambah target', () {
    final state = AppState(autoTick: false);
    addTearDown(state.dispose);
    final today = dayOnly(state.now);
    state.setTarget(habit: Habit.cigarette, limit: 5, startsOn: today);
    state.setTarget(
      habit: Habit.cigarette,
      limit: 8,
      startsOn: shiftDay(today, 5),
    );

    expect(
      () => state.setTarget(habit: Habit.cigarette, limit: 9, startsOn: today),
      throwsArgumentError,
    );

    final scheduled = state.targets.firstWhere(
      (target) => target.startsOn == shiftDay(today, 5),
    );
    expect(scheduled.limit, 8);
    expect(state.progress.targetOn(today, Habit.cigarette)!.limit, 5);

    state.setTarget(
      habit: Habit.cigarette,
      limit: 9,
      startsOn: shiftDay(today, 5),
    );
    final updated = state.targets
        .where((target) => target.startsOn == shiftDay(today, 5))
        .single;
    expect(updated.limit, 9);
  });

  test('nonaktifkan target aktif hanya mengakhiri mulai besok', () {
    final now = DateTime(2026, 11, 17, 10);
    final state = AppState(
      store: MockStore.demo(now),
      clock: () => now,
      autoTick: false,
    );
    addTearDown(state.dispose);
    final today = dayOnly(now);
    final active = state.targets
        .where((target) => target.habit == Habit.cigarette)
        .single;

    state.deactivateTarget(active, shiftDay(today, 1));

    final after = state.targets
        .where((target) => target.habit == Habit.cigarette)
        .single;
    expect(after.endsOn, shiftDay(today, 1));
    expect(state.progress.targetOn(today, Habit.cigarette), isNotNull);
    expect(
      state.progress.targetOn(shiftDay(today, 1), Habit.cigarette),
      isNull,
    );
  });

  test('nonaktifkan target terjadwal membatalkan jadwal, bukan menyimpan '
      'versi kosong', () {
    final now = DateTime(2026, 11, 17, 10);
    final state = AppState(
      store: MockStore.demo(now),
      clock: () => now,
      autoTick: false,
    );
    addTearDown(state.dispose);
    final today = dayOnly(now);
    state.setTarget(
      habit: Habit.cigarette,
      limit: 8,
      startsOn: shiftDay(today, 5),
    );
    final scheduled = state.targets.firstWhere(
      (target) => target.startsOn == shiftDay(today, 5),
    );

    state.deactivateTarget(scheduled, scheduled.startsOn);

    final targets = state.targets
        .where((target) => target.habit == Habit.cigarette)
        .toList();
    expect(targets.length, 1);
    expect(targets.single.endsOn, isNull);
    expect(
      targets.where((target) => target.endsOn == target.startsOn),
      isEmpty,
    );
  });

  test('membatalkan jadwal mengembalikan periode sebelumnya', () {
    final now = DateTime(2026, 11, 17, 10);
    final state = AppState(
      store: MockStore.demo(now),
      clock: () => now,
      autoTick: false,
    );
    addTearDown(state.dispose);
    final today = dayOnly(now);
    final active = state.targets
        .where((target) => target.habit == Habit.cigarette)
        .single;

    state.setTarget(
      habit: Habit.cigarette,
      limit: 8,
      startsOn: shiftDay(today, 5),
    );
    final scheduled = state.targets.firstWhere(
      (target) => target.startsOn == shiftDay(today, 5),
    );
    expect(
      state.targets.firstWhere((target) => target.id == active.id).endsOn,
      scheduled.startsOn,
    );

    state.removeScheduledTarget(scheduled);

    final remaining = state.targets
        .where((target) => target.habit == Habit.cigarette)
        .single;
    expect(remaining.id, active.id);
    expect(remaining.endsOn, isNull);
    expect(
      state.progress.targetOn(shiftDay(today, 5), Habit.cigarette),
      isNotNull,
    );
  });

  test('nonaktifkan pada tanggal mulai ditolak', () {
    final state = AppState(autoTick: false);
    addTearDown(state.dispose);
    final today = dayOnly(state.now);
    state.setTarget(habit: Habit.cigarette, limit: 5, startsOn: today);
    expect(
      () => state.deactivateTarget(state.targets.single, today),
      throwsArgumentError,
    );
  });

  testWidgets('form target menyimpan batas dalam satuan bungkus', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final state = AppState(autoTick: false);
    addTearDown(state.dispose);
    state.sticksPerPack = 12;
    await tester.pumpWidget(_Host(state: state, form: const TargetForm()));
    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Bungkus'));
    await tester.pumpAndSettle();
    expect(
      find.text('= 12 batang per hari · 0 berarti berhenti sepenuhnya.'),
      findsOneWidget,
    );
    await tester.enterText(find.byKey(const Key('target-limit')), '2');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Simpan target'));
    await tester.tap(find.text('Simpan target'));
    await tester.pumpAndSettle();

    expect(state.targets.length, 1);
    expect(state.targets.single.limit, 24);
  });

  testWidgets('menyimpan ulang form edit tidak menggandakan target', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final state = AppState(autoTick: false);
    addTearDown(state.dispose);
    state.setTarget(
      habit: Habit.cigarette,
      limit: 5,
      startsOn: dayOnly(state.now),
    );
    await tester.pumpWidget(
      _Host(
        state: state,
        form: TargetForm(target: state.targets.single),
      ),
    );
    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('target-limit')), '8');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Simpan target'));
    await tester.tap(find.text('Simpan target'));
    await tester.pumpAndSettle();

    expect(state.targets.length, 1);
    expect(state.targets.single.limit, 8);
  });
  testWidgets('target aktif menawarkan nonaktifkan, bukan batalkan jadwal', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final state = AppState(autoTick: false);
    addTearDown(state.dispose);
    state.setTarget(
      habit: Habit.cigarette,
      limit: 5,
      startsOn: dayOnly(state.now),
    );

    await tester.pumpWidget(_Screen(state: state));
    await tester.pumpAndSettle();

    expect(find.text('Nonaktifkan'), findsOneWidget);
    expect(find.text('Batalkan jadwal'), findsNothing);
    expect(find.text('Edit target'), findsOneWidget);
  });

  testWidgets('target terjadwal menawarkan pembatalan jadwal saja', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final state = AppState(autoTick: false);
    addTearDown(state.dispose);
    state.setTarget(
      habit: Habit.cigarette,
      limit: 5,
      startsOn: shiftDay(dayOnly(state.now), 5),
    );

    await tester.pumpWidget(_Screen(state: state));
    await tester.pumpAndSettle();

    expect(find.text('Batalkan jadwal'), findsOneWidget);
    expect(find.text('Edit jadwal'), findsOneWidget);
    expect(find.text('Nonaktifkan'), findsNothing);
    expect(find.text('Terjadwal'), findsOneWidget);
  });
}

class _Screen extends StatelessWidget {
  const _Screen({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider<AppState>.value(
    value: state,
    child: const MaterialApp(home: TargetsScreen()),
  );
}

class _Host extends StatelessWidget {
  const _Host({required this.state, required this.form});
  final AppState state;
  final Widget form;

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider<AppState>.value(
    value: state,
    child: MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => Scaffold(
                    body: SingleChildScrollView(
                      padding: const EdgeInsets.all(18),
                      child: form,
                    ),
                  ),
                ),
              ),
              child: const Text('buka'),
            ),
          ),
        ),
      ),
    ),
  );
}
