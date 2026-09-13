import '../models/records.dart';
import '../utils/dates.dart';
import 'mock_store.dart';

class ProgressCalculator {
  const ProgressCalculator(this.store);
  final MockStore store;

  int total(DateTime day, Habit habit) => store.consumption
      .where((entry) => entry.habit == habit && sameDay(entry.at, day))
      .fold(0, (sum, entry) => sum + entry.amount);

  DailyTarget? targetOn(DateTime date, Habit habit) {
    final day = dayOnly(date);
    final matches =
        store.targets
            .where((target) => target.habit == habit && target.appliesOn(day))
            .toList()
          ..sort((a, b) => a.startsOn.compareTo(b.startsOn));
    return matches.isEmpty ? null : matches.last;
  }

  bool exceeds(DateTime day, Habit habit) {
    final target = targetOn(day, habit);
    return target != null && total(day, habit) > target.limit;
  }

  DayStatus status(DateTime date, DateTime now) {
    final day = dayOnly(date);
    if (day.isAfter(dayOnly(now)) ||
        day.isBefore(dayOnly(store.profile.startedAt))) {
      return DayStatus.unassessed;
    }
    final active = Habit.values.where((habit) => targetOn(day, habit) != null);
    if (active.isEmpty) return DayStatus.unassessed;
    if (active.any((habit) => exceeds(day, habit))) return DayStatus.exceeded;
    return sameDay(day, now) ? DayStatus.inProgress : DayStatus.achieved;
  }

  DateTime get lastConsumption {
    // Historical entry time, never insertion time. Deleting or editing a record
    // automatically changes this result; there is no separately stored timer.
    if (store.consumption.isEmpty) return store.profile.startedAt;
    return store.consumption
        .map((entry) => entry.at)
        .reduce((a, b) => a.isAfter(b) ? a : b);
  }

  Duration elapsed(DateTime now) {
    final result = now.difference(lastConsumption);
    return result.isNegative ? Duration.zero : result;
  }

  int currentStreak(DateTime now) {
    if (status(now, now) == DayStatus.exceeded) return 0;
    var streak = 0;
    var date = shiftDay(now, -1);
    while (!date.isBefore(dayOnly(store.profile.startedAt)) &&
        status(date, now) == DayStatus.achieved) {
      streak++;
      date = shiftDay(date, -1);
    }
    return streak;
  }

  int bestStreak(DateTime now) {
    var best = 0;
    var run = 0;
    for (
      var date = dayOnly(store.profile.startedAt);
      date.isBefore(dayOnly(now));
      date = shiftDay(date, 1)
    ) {
      run = status(date, now) == DayStatus.achieved ? run + 1 : 0;
      if (run > best) best = run;
    }
    return best;
  }

  int successfulDays(DateTime now, {DateTime? from, DateTime? through}) {
    var count = 0;
    final end = dayOnly(through ?? now);
    for (
      var date = dayOnly(from ?? store.profile.startedAt);
      !date.isAfter(end);
      date = shiftDay(date, 1)
    ) {
      if (status(date, now) == DayStatus.achieved) count++;
    }
    return count;
  }

  int totalInRange(DateTime from, DateTime through, Habit habit) => store
      .consumption
      .where(
        (entry) =>
            entry.habit == habit &&
            !entry.at.isBefore(dayOnly(from)) &&
            entry.at.isBefore(shiftDay(through, 1)),
      )
      .fold(0, (sum, entry) => sum + entry.amount);

  int resistedInRange(DateTime from, DateTime through) => store.cravings
      .where(
        (entry) =>
            entry.resisted &&
            !entry.at.isBefore(dayOnly(from)) &&
            entry.at.isBefore(shiftDay(through, 1)),
      )
      .length;
}
