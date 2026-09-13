import 'package:cihuy/app.dart';
import 'package:cihuy/models/records.dart';
import 'package:cihuy/providers/app_state.dart';
import 'package:cihuy/screens/calendar_screen.dart';
import 'package:cihuy/services/mock_store.dart';
import 'package:cihuy/utils/app_theme.dart';
import 'package:cihuy/widgets/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  final now = DateTime(2026, 9, 12, 18, 25);
  setUpAll(() => initializeDateFormatting('id_ID'));

  Future<AppState> mount(
    WidgetTester tester, {
    double width = 390,
    MockStore? store,
  }) async {
    tester.view.physicalSize = Size(width, 844);
    tester.view.devicePixelRatio = 1;
    final state = AppState(clock: () => now, store: store, autoTick: false);
    await tester.pumpWidget(CihuyApp(state: state));
    await tester.pumpAndSettle();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      state.dispose();
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetViewInsets();
    });
    return state;
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'three tabs retain the selected date and data; Android back returns home',
    (tester) async {
      final state = await mount(tester);
      expect(find.text('BERHENTI SEJAK'), findsOneWidget);
      await tap(tester, find.byKey(const Key('tab-calendar')));
      await tap(tester, find.byKey(const Key('calendar-2026-09-07')));
      expect(find.text('1–7 Sep'), findsOneWidget);
      await tap(tester, find.byKey(const Key('tab-profile')));
      expect(find.text('Budi Santoso'), findsNWidgets(2));
      expect(find.text('34'), findsOneWidget);
      await tap(tester, find.byKey(const Key('tab-calendar')));
      expect(state.selectedDay, DateTime(2026, 9, 7));
      expect(find.text('1–7 Sep'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(state.tab, 0);
      expect(state.recordCount, 34);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('tapping a chart bar keeps the visible seven-day range', (
    tester,
  ) async {
    final state = await mount(tester);
    await tap(tester, find.byKey(const Key('tab-calendar')));
    expect(find.text('6–12 Sep'), findsOneWidget);

    await tap(tester, find.byKey(const Key('bar-2026-09-07')));

    expect(state.selectedDay, DateTime(2026, 9, 7));
    expect(state.chartEnd, DateTime(2026, 9, 12));
    expect(find.text('6–12 Sep'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    '6/5 stays red on calendar, bar and detail; editing to 5 removes exceeded status',
    (tester) async {
      final store = MockStore.empty(DateTime(2026, 9, 1));
      store.targets.add(
        DailyTarget(
          id: 'target',
          habit: Habit.cigarette,
          limit: 5,
          startsOn: DateTime(2026, 9, 1),
        ),
      );
      store.consumption.add(
        Consumption(
          id: 'six',
          habit: Habit.cigarette,
          amount: 6,
          at: DateTime(2026, 9, 7, 7),
        ),
      );
      final state = await mount(tester, store: store);
      await tap(tester, find.byKey(const Key('tab-calendar')));
      await tap(tester, find.byKey(const Key('calendar-2026-09-07')));
      expect(find.text('1–7 Sep'), findsOneWidget);
      final day = tester
          .widgetList<CalendarDay>(find.byType(CalendarDay))
          .singleWhere((day) => day.date.day == 7);
      expect(day.status, DayStatus.exceeded);
      final cell = tester.widget<Container>(
        find.byKey(const Key('calendar-2026-09-07')),
      );
      expect(
        ((cell.decoration! as BoxDecoration).border! as Border).top.color,
        CihuyColors.red,
      );
      final bar = tester.widget<Container>(
        find.byKey(const Key('bar-2026-09-07')),
      );
      expect((bar.decoration! as BoxDecoration).color, const Color(0xFFF49B9F));
      await tap(tester, find.byKey(const Key('calendar-2026-09-12')));
      final unselected = tester
          .widgetList<CalendarDay>(find.byType(CalendarDay))
          .singleWhere((day) => day.date.day == 7);
      expect(unselected.background, CihuyColors.pink);
      expect(unselected.foreground, CihuyColors.red);
      expect(
        (tester
                    .widget<Container>(find.byKey(const Key('bar-2026-09-07')))
                    .decoration!
                as BoxDecoration)
            .color,
        const Color(0xFFF49B9F),
      );
      await tap(tester, find.byKey(const Key('calendar-2026-09-07')));
      await tester.ensureVisible(find.byType(ExceededBadge));
      expect(find.text('Melampaui batas · 6/5 batang'), findsOneWidget);
      await tap(tester, find.byKey(const Key('consumption-six')));
      await tap(tester, find.text('Edit catatan'));
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('consumption-amount')))
            .controller!
            .text,
        '6',
      );
      await tester.enterText(find.byKey(const Key('consumption-amount')), '5');
      await tap(tester, find.byKey(const Key('save-consumption')));
      expect(state.progress.total(DateTime(2026, 9, 7), Habit.cigarette), 5);
      expect(find.byType(ExceededBadge), findsNothing);
      expect(find.text('✓ Target tercapai'), findsOneWidget);
      // Scroll back to verify every shared consumer after the actual form edit.
      await tester.drag(
        find.byKey(const PageStorageKey('calendar-scroll')),
        const Offset(0, 900),
      );
      await tester.pumpAndSettle();
      final corrected = tester
          .widgetList<CalendarDay>(find.byType(CalendarDay))
          .singleWhere((day) => day.date.day == 7);
      expect(corrected.status, DayStatus.achieved);
      expect(corrected.background, CihuyColors.green);
      expect(state.progress.currentStreak(now), 11);
      expect(state.progress.bestStreak(now), 11);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('today marker cannot cover exceeded status', (tester) async {
    final state = await mount(tester);
    state.saveConsumption(habit: Habit.cigarette, amount: 4, at: now);
    await tap(tester, find.byKey(const Key('tab-calendar')));
    final today = tester
        .widgetList<CalendarDay>(find.byType(CalendarDay))
        .singleWhere((day) => day.today);
    expect(today.selected, isTrue);
    expect(today.background, CihuyColors.pink);
    expect(today.foreground, CihuyColors.red);
    expect(today.outline, CihuyColors.red);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'record action has reserved space and never overlaps target content',
    (tester) async {
      await mount(tester, width: 360);
      final scroll = find.byKey(const PageStorageKey('home-scroll'));
      await tester.drag(scroll, const Offset(0, -600));
      await tester.pumpAndSettle();
      expect(
        tester.getRect(scroll).bottom,
        lessThanOrEqualTo(
          tester.getRect(find.byKey(const Key('record-now'))).top,
        ),
      );
      expect(find.text('2 dari 5 batang'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final width in [360.0, 430.0]) {
    testWidgets(
      'consumption form validates amount and fits keyboard at width $width',
      (tester) async {
        final state = await mount(tester, width: width);
        await tap(tester, find.byKey(const Key('record-now')));
        await tap(tester, find.text('Catat Konsumsi'));
        expect(find.text('Pilih jenis catatan'), findsNothing);
        expect(
          tester
              .widget<IconButton>(find.byKey(const Key('quantity-minus')))
              .onPressed,
          isNull,
        );
        await tester.enterText(
          find.byKey(const Key('consumption-amount')),
          '1.5',
        );
        await tap(tester, find.byKey(const Key('save-consumption')));
        expect(find.text('Isi bilangan bulat ≥ 1'), findsOneWidget);
        await tester.enterText(
          find.byKey(const Key('consumption-amount')),
          '2',
        );
        await tester.enterText(
          find.byKey(const Key('consumption-note')),
          'Catatan pengujian',
        );
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(const Key('save-consumption')));
        await tester.pumpAndSettle();
        final rect = tester.getRect(find.byKey(const Key('save-consumption')));
        expect(rect.bottom, lessThanOrEqualTo(844 - 300));
        await tap(tester, find.byKey(const Key('save-consumption')));
        tester.view.resetViewInsets();
        await tester.pumpAndSettle();
        expect(state.recordCount, 35);
        expect(state.consumption.last.note, 'Catatan pengujian');
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'craving other trigger validates and declined consumption creates no duplicate',
    (tester) async {
      final state = await mount(tester, width: 360);
      final before = state.progress.elapsed(now);
      await tap(tester, find.byKey(const Key('record-now')));
      await tap(tester, find.text('Catat Craving'));
      await tap(tester, find.text('Lainnya'));
      await tap(tester, find.text('Akhirnya konsumsi'));
      await tap(tester, find.byKey(const Key('save-craving')));
      expect(find.text('Isi pemicu lainnya'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Pemicu lainnya'),
        'Perjalanan panjang',
      );
      await tap(tester, find.byKey(const Key('save-craving')));
      expect(find.text('Catat konsumsinya juga?'), findsOneWidget);
      await tap(tester, find.text('Batal'));
      expect(state.cravings.length, 8);
      expect(state.consumption.length, 27);
      expect(state.progress.elapsed(now), before);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Android back dismisses picker then form without saving', (
    tester,
  ) async {
    final state = await mount(tester);
    await tap(tester, find.byKey(const Key('record-now')));
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Pilih jenis catatan'), findsNothing);
    await tap(tester, find.byKey(const Key('record-now')));
    await tap(tester, find.text('Catat Konsumsi'));
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('save-consumption')), findsNothing);
    expect(state.recordCount, 34);
  });

  testWidgets('empty user onboarding and profile changes reach home', (
    tester,
  ) async {
    final state = await mount(tester);
    state.startNewUser(name: 'Sari');
    await tester.pumpAndSettle();
    await tap(tester, find.text('Mulai tanpa target dulu'));
    expect(state.recordCount, 0);
    state.updateProfile(reason: 'Ingin lebih sehat bersama keluarga.');
    await tester.pumpAndSettle();
    expect(find.text('Ingin lebih sehat bersama keluarga.'), findsOneWidget);
    await tap(tester, find.byKey(const Key('tab-calendar')));
    expect(find.byType(ExceededBadge), findsNothing);
    await tester.ensureVisible(find.text('Belum ada catatan konsumsi.'));
    expect(find.text('Belum ada catatan konsumsi.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
