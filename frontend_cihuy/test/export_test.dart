import 'package:cihuy/models/records.dart';
import 'package:cihuy/providers/app_state.dart';
import 'package:cihuy/services/export.dart';
import 'package:cihuy/utils/dates.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  test('laporan ekspor memuat semua bagian dan isi catatan', () {
    final app = AppState(autoTick: false);
    addTearDown(app.dispose);
    final now = app.now;

    app.setTarget(habit: Habit.cigarette, limit: 5, startsOn: dayOnly(now));
    app.saveConsumption(
      habit: Habit.cigarette,
      amount: 3,
      at: now,
      note: 'Setelah makan',
    );
    app.saveCraving(
      habit: Habit.cigarette,
      at: now,
      intensity: Intensity.medium,
      triggers: const ['Stres'],
      coping: 'Minum air putih',
      resisted: true,
    );

    final report = buildExportReport(app, diEksporPada: now);

    expect(report, contains('LAPORAN DATA CIHUY'));
    expect(report, contains('PROFIL'));
    expect(report, contains('Pengguna Baru'));
    expect(report, contains('TARGET (1)'));
    expect(report, contains('CATATAN KONSUMSI (1)'));
    expect(report, contains('CATATAN CRAVING (1)'));
    expect(report, contains('RINGKASAN'));
    expect(report, contains('3 batang'));
    expect(report, contains('Setelah makan'));
    expect(report, contains('Stres'));
  });

  test('clearRecords mengosongkan konsumsi, craving, dan target', () {
    final app = AppState(autoTick: false);
    addTearDown(app.dispose);
    final now = app.now;

    app.setTarget(habit: Habit.cigarette, limit: 5, startsOn: dayOnly(now));
    app.saveConsumption(habit: Habit.cigarette, amount: 1, at: now);
    app.saveCraving(
      habit: Habit.cigarette,
      at: now,
      intensity: Intensity.light,
      triggers: const [],
      coping: '',
      resisted: false,
    );
    app.clearRecords();

    expect(app.consumption, isEmpty);
    expect(app.cravings, isEmpty);
    expect(app.targets, isEmpty);
  });
}
