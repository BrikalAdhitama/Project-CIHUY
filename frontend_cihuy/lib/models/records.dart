import 'dart:typed_data';

enum Habit { cigarette, vape }

extension HabitLabels on Habit {
  String get label => this == Habit.cigarette ? 'Rokok' : 'Vape';
  String get unit => this == Habit.cigarette ? 'batang' : 'hisapan';
}

enum Intensity { light, medium, heavy }

extension IntensityLabels on Intensity {
  String get label => switch (this) {
    Intensity.light => 'Ringan',
    Intensity.medium => 'Sedang',
    Intensity.heavy => 'Berat',
  };
}

enum DayStatus { unassessed, inProgress, achieved, exceeded }

class Consumption {
  const Consumption({
    required this.id,
    required this.habit,
    required this.amount,
    required this.at,
    this.note = '',
  });
  final String id;
  final Habit habit;
  final int amount;
  final DateTime at;
  final String note;
}

class Craving {
  Craving({
    required this.id,
    required this.habit,
    required this.at,
    this.intensity = Intensity.medium,
    List<String> triggers = const [],
    this.coping = '',
    this.resisted = true,
  }) : triggers = List.unmodifiable(triggers);
  final String id;
  final Habit habit;
  final DateTime at;
  final Intensity intensity;
  final List<String> triggers;
  final String coping;
  final bool resisted;
}

/// A version of a daily target. The end date is exclusive.
class DailyTarget {
  const DailyTarget({
    required this.id,
    required this.habit,
    required this.limit,
    required this.startsOn,
    this.endsOn,
  });
  final String id;
  final Habit habit;
  final int limit;
  final DateTime startsOn;
  final DateTime? endsOn;

  bool appliesOn(DateTime day) =>
      !day.isBefore(startsOn) && (endsOn == null || day.isBefore(endsOn!));

  DailyTarget endingOn(DateTime day) => DailyTarget(
    id: id,
    habit: habit,
    limit: limit,
    startsOn: startsOn,
    endsOn: day,
  );
}

class UserProfile {
  const UserProfile({
    required this.name,
    required this.email,
    required this.reason,
    required this.startedAt,
    this.photo,
  });
  final String name;
  final String email;
  final String reason;
  final DateTime startedAt;
  final Uint8List? photo;

  String get initials => name
      .trim()
      .split(RegExp(r'\s+'))
      .take(2)
      .map((part) => part.isEmpty ? '' : part[0].toUpperCase())
      .join();

  UserProfile updated({String? name, String? reason}) => UserProfile(
    name: name ?? this.name,
    email: email,
    reason: reason ?? this.reason,
    startedAt: startedAt,
    photo: photo,
  );

  UserProfile withPhoto(Uint8List? bytes) => UserProfile(
    name: name,
    email: email,
    reason: reason,
    startedAt: startedAt,
    photo: bytes == null
        ? null
        : Uint8List.fromList(bytes).asUnmodifiableView(),
  );
}
