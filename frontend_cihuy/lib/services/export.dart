import '../models/records.dart';
import '../providers/app_state.dart';
import '../utils/dates.dart';

/// Membangun laporan teks seluruh data pengguna: profil, target harian,
/// serta catatan konsumsi dan craving.
///
/// Sengaja berupa fungsi murni yang mengembalikan [String] agar mudah
/// diuji tanpa platform channel, serta bisa disalin langsung dari dialog
/// ekspor.
String buildExportReport(AppState state, {DateTime? diEksporPada}) {
  final at = diEksporPada ?? state.now;
  final profile = state.profile;
  final packs = state.sticksPerPack;
  final lines = <String>[];
  final divider = '═' * 40;

  void section(String title) {
    lines.add('');
    lines.add(title);
    lines.add('─' * title.length);
  }

  lines.add('LAPORAN DATA CIHUY');
  lines.add('Control It, Hold Yourself');
  lines.add('Diekspor: ${fullDate(at)} · ${clockLabel(at)}');
  lines.add(divider);

  section('PROFIL');
  lines.add('- Nama: ${profile.name}');
  lines.add('- Email: ${profile.email}');
  lines.add('- Alasan berhenti: ${profile.reason}');
  lines.add('- Bergabung sejak: ${shortDate(profile.startedAt)}');
  for (final habit in Habit.values) {
    final baseline = state.baseline(habit);
    if (baseline != null) {
      lines.add('- Baseline ${habit.label}: $baseline ${habit.unit}/hari');
    }
  }
  lines.add('- Isi per bungkus: $packs batang');

  final targets = [...state.targets]
    ..sort((a, b) => a.startsOn.compareTo(b.startsOn));
  section('TARGET (${targets.length})');
  if (targets.isEmpty) {
    lines.add('- Belum ada target.');
  } else {
    for (final target in targets) {
      final end = target.endsOn == null
          ? 'seterusnya'
          : 'berakhir ${shortDate(target.endsOn!)}';
      lines.add(
        '- ${target.habit.legacyLabel} · batas ${target.limit} ${target.habit.unit}/hari · mulai ${shortDate(target.startsOn)} · $end',
      );
    }
  }

  final consumption = [...state.consumption]
    ..sort((a, b) => b.at.compareTo(a.at));
  section('CATATAN KONSUMSI (${consumption.length})');
  if (consumption.isEmpty) {
    lines.add('- Belum ada catatan konsumsi.');
  } else {
    for (final entry in consumption) {
      final note = entry.note.trim();
      lines.add(
        '- ${shortDate(entry.at)} ${clockLabel(entry.at)} · ${entry.habit.legacyLabel} · ${cigaretteAmountLabel(entry.amount, packs)}${note.isEmpty ? '' : ' · $note'}',
      );
    }
  }

  final cravings = [...state.cravings]..sort((a, b) => b.at.compareTo(a.at));
  section('CATATAN CRAVING (${cravings.length})');
  if (cravings.isEmpty) {
    lines.add('- Belum ada catatan craving.');
  } else {
    for (final entry in cravings) {
      final triggers = entry.triggers.isEmpty ? '-' : entry.triggers.join(', ');
      final coping = entry.coping.trim();
      lines.add(
        '- ${shortDate(entry.at)} ${clockLabel(entry.at)} · ${entry.habit.legacyLabel} · intensitas ${entry.intensity.label} · pemicu: $triggers · melawan: ${entry.resisted ? 'ya' : 'tidak'}${coping.isEmpty ? '' : ' · cara: $coping'}',
      );
    }
  }

  final cigarette = consumption
      .where((entry) => entry.habit == Habit.cigarette)
      .fold(0, (sum, entry) => sum + entry.amount);
  final vape = consumption
      .where((entry) => entry.habit == Habit.vape)
      .fold(0, (sum, entry) => sum + entry.amount);
  final resisted = cravings.where((entry) => entry.resisted).length;
  section('RINGKASAN');
  lines.add(
    '- Total konsumsi rokok: ${cigaretteAmountLabel(cigarette, packs)}',
  );
  if (vape > 0) lines.add('- Total hisapan vape (lama): $vape hisapan');
  lines.add(
    '- Total craving: ${cravings.length} (berhasil melawan: $resisted)',
  );

  lines.add('');
  lines.add(divider);
  lines.add('Dibuat oleh CIHUY · Control It, Hold Yourself');
  return lines.join('\n');
}
