import '../models/records.dart';
import '../utils/dates.dart';

/// In-memory data only: no storage, network, auth SDK, or push service.
class MockStore {
  MockStore.empty(
    DateTime now, {
    String name = 'Pengguna Baru',
    String email = 'pengguna@contoh.test',
    String reason = 'Saya ingin hidup lebih sehat.',
  }) : profile = UserProfile(
         name: name,
         email: email,
         reason: reason,
         startedAt: now,
       );

  MockStore.demo(DateTime now)
    : profile = UserProfile(
        name: 'Budi Santoso',
        email: 'budi.santoso@contoh.test',
        reason:
            'Ingin hidup lebih sehat dan menghemat pengeluaran untuk keluarga.',
        startedAt: shiftDay(now, -7),
      ) {
    targets.add(
      DailyTarget(
        id: nextId(),
        habit: Habit.cigarette,
        limit: 5,
        startsOn: shiftDay(now, -6),
      ),
    );
    // Six completed days and today. On 12 September, -5 is 7 September.
    const amounts = [4, 6, 3, 5, 3, 4, 2];
    for (var index = 0; index < amounts.length; index++) {
      final date = shiftDay(now, index - 6);
      for (var number = 0; number < amounts[index]; number++) {
        final at = index == 6
            ? now.subtract(
                Duration(hours: number == 0 ? 7 : 5, minutes: 25, seconds: 14),
              )
            : date.add(Duration(hours: 7 + number * 2, minutes: 30));
        // During the first hours of a day, keep today's demo records in today.
        final safeAt = index == 6 && !sameDay(at, now)
            ? dayOnly(now).add(Duration(minutes: now.hour * 60 ~/ 3 + number))
            : at;
        consumption.add(
          Consumption(
            id: nextId(),
            habit: Habit.cigarette,
            amount: 1,
            at: safeAt.isAfter(now) ? now : safeAt,
            note: number == 0 ? 'Setelah sarapan' : 'Catatan harian',
          ),
        );
      }
      final at = index == 6
          ? now.subtract(const Duration(minutes: 10))
          : date.add(const Duration(hours: 16));
      cravings.add(
        Craving(
          id: nextId(),
          habit: Habit.cigarette,
          at: at,
          triggers: [index.isEven ? 'Setelah makan' : 'Stres'],
          coping: 'Menarik napas dan minum air putih.',
        ),
      );
    }
  }

  UserProfile profile;
  final List<Consumption> consumption = [];
  final List<Craving> cravings = [];
  final List<DailyTarget> targets = [];
  int _sequence = 0;
  String nextId() => 'mock-${++_sequence}';
}
