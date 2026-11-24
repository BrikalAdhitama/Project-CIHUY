import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/records.dart';
import '../providers/app_state.dart';
import '../utils/app_theme.dart';
import '../utils/dates.dart';
import 'common.dart';
import 'record_forms.dart';

Future<void> showConsumptionDetails(
  BuildContext context,
  Consumption entry,
) async {
  final sticksPerPack = context.read<AppState>().sticksPerPack;
  final action = await openSheet<String>(
    context,
    _RecordDetail(
      title: 'Detail Konsumsi',
      at: entry.at,
      lines: {
        'Jenis': entry.habit.legacyLabel,
        'Jumlah': entry.habit.isLegacy
            ? '${entry.amount} ${entry.habit.unit}'
            : cigaretteAmountLabel(entry.amount, sticksPerPack),
        'Catatan': entry.note.isEmpty
            ? 'Tidak ada catatan tambahan.'
            : entry.note,
      },
    ),
  );
  if (!context.mounted) return;
  if (action == 'edit') {
    await showConsumptionForm(context, entry: entry);
    return;
  }
  if (action == 'delete') {
    final confirm = await confirmAction(
      context,
      title: 'Hapus catatan konsumsi?',
      message:
          'Catatan ini akan dihapus. Timer, status harian, grafik, dan streak akan dihitung ulang.',
    );
    if (confirm && context.mounted) {
      context.read<AppState>().deleteConsumption(entry.id);
      showMessage(context, 'Catatan konsumsi dihapus.');
    }
  }
}

Future<void> showCravingDetails(BuildContext context, Craving entry) async {
  final action = await openSheet<String>(
    context,
    _RecordDetail(
      title: 'Detail Craving',
      at: entry.at,
      lines: {
        'Jenis': entry.habit.label,
        'Intensitas': entry.intensity.label,
        'Pemicu': entry.triggers.isEmpty
            ? 'Tidak dicatat'
            : entry.triggers.join(', '),
        'Cara mengatasi': entry.coping.isEmpty ? 'Tidak dicatat' : entry.coping,
        'Hasil': entry.resisted ? 'Berhasil ditahan' : 'Akhirnya konsumsi',
      },
    ),
  );
  if (!context.mounted) return;
  if (action == 'edit') {
    await showCravingForm(context, entry: entry);
    return;
  }
  if (action == 'delete') {
    final confirm = await confirmAction(
      context,
      title: 'Hapus catatan craving?',
      message: 'Catatan craving ini akan dihapus dari riwayat dan rangkuman.',
    );
    if (confirm && context.mounted) {
      context.read<AppState>().deleteCraving(entry.id);
      showMessage(context, 'Catatan craving dihapus.');
    }
  }
}

class _RecordDetail extends StatelessWidget {
  const _RecordDetail({
    required this.title,
    required this.at,
    required this.lines,
  });
  final String title;
  final DateTime at;
  final Map<String, String> lines;
  @override
  Widget build(BuildContext context) => Column(
    mainAxisAlignment: MainAxisAlignment.start,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SheetHeading(title, subtitle: '${fullDate(at)} · ${clockLabel(at)}'),
      for (final line in lines.entries)
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(line.key, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 3),
              Text(line.value),
            ],
          ),
        ),
      FilledButton(
        onPressed: () => Navigator.pop(context, 'edit'),
        child: const Text('Edit catatan'),
      ),
      const SizedBox(height: 8),
      Center(
        child: TextButton(
          onPressed: () => Navigator.pop(context, 'delete'),
          child: const Text(
            'Hapus catatan',
            style: TextStyle(color: CihuyColors.red),
          ),
        ),
      ),
    ],
  );
}
