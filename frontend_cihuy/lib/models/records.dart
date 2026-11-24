import 'dart:typed_data';

enum Habit {
  cigarette,

  /// Tidak lagi ditawarkan untuk catatan baru. Nilainya dipertahankan agar
  /// catatan lama tetap terbaca dan statistik historis tidak rusak.
  vape;

  /// Jenis kebiasaan yang bisa dicatat lewat aplikasi.
  static const List<Habit> tracked = [Habit.cigarette];

  bool get isLegacy => this == Habit.vape;
}

extension HabitLabels on Habit {
  String get label => this == Habit.cigarette ? 'Rokok' : 'Vape';
  String get unit => this == Habit.cigarette ? 'batang' : 'hisapan';

  /// Label jenis untuk catatan lama agar jelas tidak bisa dipilih lagi.
  String get legacyLabel => isLegacy ? 'Vape (lama)' : label;
}

/// Jumlah rokok dalam batang, ditambah padanan bungkus bila habis dibagi.
/// Contoh: 24 batang dengan isi 12 per bungkus menjadi
/// "24 batang (2 bungkus)".
String cigaretteAmountLabel(int amount, int sticksPerPack) {
  final packs = sticksPerPack > 0 ? amount ~/ sticksPerPack : 0;
  if (packs < 1 || amount % sticksPerPack != 0) {
    return '$amount batang';
  }
  return '$amount batang ($packs bungkus)';
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

  Map<String, dynamic> toJson() => {
    'id': id,
    'habit': habit.name,
    'amount': amount,
    'at': at.toIso8601String(),
    'note': note,
  };

  factory Consumption.fromJson(Map<String, dynamic> json) {
    final habit = Habit.values.asNameMap()[json['habit']];
    final id = json['id'];
    final amount = json['amount'];
    final at = DateTime.tryParse(json['at'] as String? ?? '');
    if (id is! String ||
        id.isEmpty ||
        habit == null ||
        amount is! int ||
        amount < 1 ||
        at == null) {
      throw const FormatException('Catatan konsumsi tidak valid.');
    }
    return Consumption(
      id: id,
      habit: habit,
      amount: amount,
      at: at,
      note: json['note'] as String? ?? '',
    );
  }
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

  Map<String, dynamic> toJson() => {
    'id': id,
    'habit': habit.name,
    'at': at.toIso8601String(),
    'intensity': intensity.name,
    'triggers': triggers,
    'coping': coping,
    'resisted': resisted,
  };

  factory Craving.fromJson(Map<String, dynamic> json) {
    final habit = Habit.values.asNameMap()[json['habit']];
    final intensity = Intensity.values.asNameMap()[json['intensity']];
    final id = json['id'];
    final at = DateTime.tryParse(json['at'] as String? ?? '');
    final triggers = json['triggers'];
    final resisted = json['resisted'];
    if (id is! String ||
        id.isEmpty ||
        habit == null ||
        intensity == null ||
        at == null ||
        triggers is! List ||
        resisted is! bool) {
      throw const FormatException('Catatan craving tidak valid.');
    }
    return Craving(
      id: id,
      habit: habit,
      at: at,
      intensity: intensity,
      triggers: triggers.whereType<String>().toList(),
      coping: json['coping'] as String? ?? '',
      resisted: resisted,
    );
  }
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

  DailyTarget endingOn(DateTime day) => withEnd(day);

  /// Salinan dengan tanggal selesai baru; `null` berarti berlaku seterusnya.
  DailyTarget withEnd(DateTime? day) => DailyTarget(
    id: id,
    habit: habit,
    limit: limit,
    startsOn: startsOn,
    endsOn: day,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'habit': habit.name,
    'limit': limit,
    'startsOn': startsOn.toIso8601String(),
    if (endsOn != null) 'endsOn': endsOn!.toIso8601String(),
  };

  factory DailyTarget.fromJson(Map<String, dynamic> json) {
    final habit = Habit.values.asNameMap()[json['habit']];
    final id = json['id'];
    final limit = json['limit'];
    final startsOn = DateTime.tryParse(json['startsOn'] as String? ?? '');
    final endsOnRaw = json['endsOn'];
    final endsOn = endsOnRaw == null
        ? null
        : DateTime.tryParse(endsOnRaw as String? ?? '');
    if (id is! String ||
        id.isEmpty ||
        habit == null ||
        limit is! int ||
        limit < 0 ||
        startsOn == null ||
        (endsOnRaw != null && endsOn == null)) {
      throw const FormatException('Target harian tidak valid.');
    }
    return DailyTarget(
      id: id,
      habit: habit,
      limit: limit,
      startsOn: startsOn,
      endsOn: endsOn,
    );
  }
}

/// Membersihkan daftar target dari versi yang tidak pernah berlaku
/// (`endsOn == startsOn`) dan versi ganda dengan jenis serta tanggal mulai
/// yang sama. Versi terakhir dianggap yang berlaku, sehingga penyimpanan
/// berulang tidak lagi menampilkan target ganda.
List<DailyTarget> normalizedTargets(Iterable<DailyTarget> targets) {
  final order = <String>[];
  final latest = <String, DailyTarget>{};
  for (final target in targets) {
    final endsOn = target.endsOn;
    if (endsOn != null && !endsOn.isAfter(target.startsOn)) continue;
    final key = '${target.habit.name}|${target.startsOn.toIso8601String()}';
    if (!latest.containsKey(key)) order.add(key);
    latest[key] = target;
  }
  return [for (final key in order) latest[key]!];
}

class UserProfile {
  const UserProfile({
    required this.name,
    required this.email,
    required this.reason,
    required this.startedAt,
    this.photo,
    this.avatarPath,
  });
  final String name;
  final String email;
  final String reason;
  final DateTime startedAt;
  final Uint8List? photo;

  /// Relative object path in the private photo-profil bucket.
  final String? avatarPath;

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
    avatarPath: avatarPath,
  );

  UserProfile withPhoto(Uint8List? bytes, {String? avatarPath}) => UserProfile(
    name: name,
    email: email,
    reason: reason,
    startedAt: startedAt,
    avatarPath: bytes == null ? null : avatarPath ?? this.avatarPath,
    photo: bytes == null
        ? null
        : Uint8List.fromList(bytes).asUnmodifiableView(),
  );
}
