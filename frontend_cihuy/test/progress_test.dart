import 'package:cihuy/models/records.dart';
import 'package:cihuy/providers/app_state.dart';
import 'package:cihuy/services/mock_store.dart';
import 'package:cihuy/utils/dates.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 9, 12, 18, 25);
  final seventh = DateTime(2026, 9, 7, 12);
  late AppState state;
  late MockStore store;

  setUp(() {
    store = MockStore.empty(DateTime(2026, 9, 1));
    store.targets.add(
      DailyTarget(
        id: 'initial-target',
        habit: Habit.cigarette,
        limit: 5,
        startsOn: DateTime(2026, 9, 1),
      ),
    );
    state = AppState(clock: () => now, store: store, autoTick: false);
  });
  tearDown(() => state.dispose());
  Consumption add(int amount, {DateTime? at, Habit habit = Habit.cigarette}) =>
      state.saveConsumption(habit: habit, amount: amount, at: at ?? seventh);

  test('5/5 succeeds, sum of separate entries at 6/5 exceeds', () {
    add(3);
    add(2);
    expect(state.progress.total(seventh, Habit.cigarette), 5);
    expect(state.progress.status(seventh, now), DayStatus.achieved);
    add(1);
    expect(state.progress.total(seventh, Habit.cigarette), 6);
    expect(state.progress.status(seventh, now), DayStatus.exceeded);
  });

  test(
    'editing 6 to 5 recalculates status, totals and streaks with one notification',
    () {
      final entry = add(6);
      expect(state.progress.currentStreak(now), 4);
      var updates = 0;
      state.addListener(() => updates++);
      state.saveConsumption(
        id: entry.id,
        habit: entry.habit,
        amount: 5,
        at: entry.at,
      );
      expect(state.progress.status(seventh, now), DayStatus.achieved);
      expect(
        state.progress.totalInRange(DateTime(2026, 9, 1), now, Habit.cigarette),
        5,
      );
      expect(state.progress.currentStreak(now), 11);
      expect(state.progress.bestStreak(now), 11);
      expect(state.recordCount, 1);
      expect(updates, 1);
    },
  );

  test('latest target never changes the historical 6/5 comparison', () {
    add(6);
    state.setTarget(habit: Habit.cigarette, limit: 10, startsOn: now);
    expect(state.progress.targetOn(seventh, Habit.cigarette)!.limit, 5);
    expect(state.progress.targetOn(now, Habit.cigarette)!.limit, 10);
    expect(state.progress.status(seventh, now), DayStatus.exceeded);
    expect(state.targets.length, 2);
  });

  test('target periods have an exclusive end, including deactivation', () {
    final original = state.targets.single;
    state.deactivateTarget(original, shiftDay(now, 1));
    expect(state.progress.targetOn(now, Habit.cigarette), isNotNull);
    expect(state.progress.targetOn(shiftDay(now, 1), Habit.cigarette), isNull);
    expect(state.progress.targetOn(seventh, Habit.cigarette)!.limit, 5);
  });

  test('scheduled target can end on the selected final day', () {
    state.setTarget(
      habit: Habit.cigarette,
      limit: 3,
      startsOn: now,
      endsOn: shiftDay(now, 3),
    );
    expect(state.progress.targetOn(now, Habit.cigarette)!.limit, 3);
    expect(
      state.progress.targetOn(shiftDay(now, 2), Habit.cigarette)!.limit,
      3,
    );
    expect(state.progress.targetOn(shiftDay(now, 3), Habit.cigarette), isNull);
  });

  test('retroactive target edits are rejected', () {
    expect(
      () =>
          state.setTarget(habit: Habit.cigarette, limit: 9, startsOn: seventh),
      throwsArgumentError,
    );
    expect(state.targets.single.limit, 5);
  });

  test(
    'cigarettes and vape have separate units and both active targets must pass',
    () {
      store.targets.add(
        DailyTarget(
          id: 'vape-target',
          habit: Habit.vape,
          limit: 20,
          startsOn: DateTime(2026, 9, 1),
        ),
      );
      add(5);
      final vape = add(20, habit: Habit.vape);
      expect(state.progress.status(seventh, now), DayStatus.achieved);
      state.saveConsumption(
        id: vape.id,
        habit: Habit.vape,
        amount: 21,
        at: seventh,
      );
      expect(state.progress.total(seventh, Habit.cigarette), 5);
      expect(state.progress.total(seventh, Habit.vape), 21);
      expect(state.progress.exceeds(seventh, Habit.cigarette), isFalse);
      expect(state.progress.exceeds(seventh, Habit.vape), isTrue);
      expect(state.progress.status(seventh, now), DayStatus.exceeded);
    },
  );

  test('today is unfinished, future days are unassessed', () {
    add(5, at: now);
    expect(state.progress.status(now, now), DayStatus.inProgress);
    expect(state.progress.status(shiftDay(now, 1), now), DayStatus.unassessed);
    expect(state.progress.successfulDays(now), 11);
    add(1, at: now);
    expect(state.progress.status(now, now), DayStatus.exceeded);
    expect(state.progress.currentStreak(now), 0);
    expect(state.progress.bestStreak(now), 11);
    expect(state.progress.successfulDays(now), 11);
  });

  test('selection changes neither timer nor current/best streak', () {
    add(6);
    final elapsed = state.progress.elapsed(now);
    final current = state.progress.currentStreak(now);
    final best = state.progress.bestStreak(now);
    state.selectDate(seventh, openCalendar: true);
    state.selectDate(DateTime(2026, 12, 1));
    state.selectTab(2);
    expect(state.progress.elapsed(now), elapsed);
    expect(state.progress.currentStreak(now), current);
    expect(state.progress.bestStreak(now), best);
    expect(state.progress.status(seventh, now), DayStatus.exceeded);
  });

  test(
    'historical input and edits/deletes derive timer from actual occurrence',
    () {
      final recent = add(1, at: now.subtract(const Duration(hours: 2)));
      final old = add(1);
      expect(state.progress.elapsed(now), const Duration(hours: 2));
      state.saveConsumption(
        id: recent.id,
        habit: recent.habit,
        amount: 1,
        at: now.subtract(const Duration(hours: 3)),
      );
      expect(state.progress.elapsed(now), const Duration(hours: 3));
      state.deleteConsumption(recent.id);
      expect(state.progress.elapsed(now), now.difference(old.at));
      state.deleteConsumption(old.id);
      expect(
        state.progress.elapsed(now),
        now.difference(store.profile.startedAt),
      );
    },
  );

  test(
    'wall clock change after background is reflected without accumulated ticks',
    () {
      final at = now.subtract(const Duration(hours: 2));
      add(1, at: at);
      expect(
        state.progress.elapsed(now.add(const Duration(days: 2, minutes: 8))),
        const Duration(days: 2, hours: 2, minutes: 8),
      );
    },
  );

  test('craving CRUD does not create consumption or reset timer', () {
    add(1);
    final before = state.progress.elapsed(now);
    final entry = state.saveCraving(
      habit: Habit.vape,
      at: now,
      intensity: Intensity.medium,
      triggers: ['Stres'],
      coping: '',
      resisted: false,
    );
    expect(state.consumption.length, 1);
    expect(state.progress.elapsed(now), before);
    state.saveCraving(
      id: entry.id,
      habit: Habit.vape,
      at: now,
      intensity: Intensity.heavy,
      triggers: ['Bosan'],
      coping: 'Minum air',
      resisted: true,
    );
    expect(state.cravings.length, 1);
    expect(state.progress.resistedInRange(seventh, now), 1);
    state.deleteCraving(entry.id);
    expect(state.cravings, isEmpty);
    expect(state.progress.elapsed(now), before);
  });

  test(
    'invalid consumption and future timestamps are rejected without mutation',
    () {
      expect(() => add(0), throwsArgumentError);
      expect(() => add(-1), throwsArgumentError);
      expect(
        () => add(1, at: now.add(const Duration(seconds: 1))),
        throwsArgumentError,
      );
      expect(
        () => state.saveCraving(
          habit: Habit.cigarette,
          at: shiftDay(now, 1),
          intensity: Intensity.light,
          triggers: [],
          coping: '',
          resisted: true,
        ),
        throwsArgumentError,
      );
      expect(state.recordCount, 0);
    },
  );

  test('midnight boundaries do not combine adjacent day totals', () {
    add(5, at: DateTime(2026, 9, 7, 23, 59, 59));
    add(1, at: DateTime(2026, 9, 8));
    expect(state.progress.total(seventh, Habit.cigarette), 5);
    expect(state.progress.total(DateTime(2026, 9, 8), Habit.cigarette), 1);
  });

  test('zero target and no-target states work', () {
    state.setTarget(habit: Habit.cigarette, limit: 0, startsOn: now);
    expect(state.progress.status(now, now), DayStatus.inProgress);
    add(1, at: now);
    expect(state.progress.status(now, now), DayStatus.exceeded);
    state.startNewUser();
    state.completeOnboarding('Alasan baru');
    expect(state.progress.status(now, now), DayStatus.unassessed);
    expect(state.progress.currentStreak(now), 0);
    expect(state.recordCount, 0);
  });

  test(
    'demo has 27 cigarettes, 34 entries, five completed successes and streak four',
    () {
      state.startDemo();
      expect(
        state.progress.totalInRange(shiftDay(now, -6), now, Habit.cigarette),
        27,
      );
      expect(state.progress.total(seventh, Habit.cigarette), 6);
      expect(state.progress.successfulDays(now), 5);
      expect(state.progress.currentStreak(now), 4);
      expect(state.progress.bestStreak(now), 4);
      expect(state.recordCount, 34);
      for (var i = 0; i < 5; i++) {
        state.selectTab(i % 3);
        state.refresh();
      }
      expect(state.recordCount, 34);
    },
  );

  test('new user, profile editing, logout and simulated account deletion', () {
    state.startNewUser(name: 'Sari');
    expect(state.needsOnboarding, isTrue);
    state.completeOnboarding('Untuk keluarga');
    state.updateProfile(name: 'Sari Putri', reason: 'Lebih sehat');
    expect(state.profile.initials, 'SP');
    expect(state.profile.reason, 'Lebih sehat');
    state.signOut();
    expect(state.signedIn, isFalse);
    state.signIn();
    expect(state.profile.name, 'Sari Putri');
    state.deleteAccount();
    expect(state.signedIn, isFalse);
    expect(state.recordCount, 0);
    expect(state.targets, isEmpty);
  });

  test('demo remains valid at midnight and across month/year boundaries', () {
    for (final date in [
      DateTime(2027, 1, 1),
      DateTime(2026, 3, 1, 1),
      DateTime(2026, 9, 12, 0, 1),
    ]) {
      final demo = MockStore.demo(date);
      expect(
        demo.consumption.every((entry) => !entry.at.isAfter(date)),
        isTrue,
      );
      expect(demo.cravings.every((entry) => !entry.at.isAfter(date)), isTrue);
      expect(
        demo.consumption.where((entry) => sameDay(entry.at, date)).length,
        2,
      );
    }
  });
}
