import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/records.dart';
import '../providers/app_state.dart';
import '../utils/app_theme.dart';
import '../utils/dates.dart';
import '../widgets/common.dart';

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final end = state.selectedDay;
    final start = shiftDay(end, -6);
    final previousEnd = shiftDay(start, -1);
    final previousStart = shiftDay(start, -7);
    final triggers = <String, int>{};
    for (final entry in state.cravings.where(
      (entry) =>
          !entry.at.isBefore(start) && entry.at.isBefore(shiftDay(end, 1)),
    )) {
      for (final trigger in entry.triggers) {
        triggers.update(trigger, (count) => count + 1, ifAbsent: () => 1);
      }
    }
    final sorted = triggers.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Scaffold(
      appBar: AppBar(title: const Text('Detail progres')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            Text(
              dateRange(start, end),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            for (final habit in Habit.values)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: SurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionTitle(habit.label),
                      const SizedBox(height: 12),
                      Text(
                        '${state.progress.totalInRange(start, end, habit)} ${habit.unit}',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '7 hari sebelumnya (${dateRange(previousStart, previousEnd)}): '
                        '${state.progress.totalInRange(previousStart, previousEnd, habit)} ${habit.unit}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionTitle('Pola craving'),
                  const SizedBox(height: 12),
                  Text(
                    '${state.progress.resistedInRange(start, end)} craving berhasil ditahan',
                  ),
                  const SizedBox(height: 12),
                  if (sorted.isEmpty)
                    const EmptyMessage(
                      'Belum ada pemicu yang dicatat pada periode ini.',
                    ),
                  for (final entry in sorted)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Expanded(child: Text(entry.key)),
                          Text(
                            '${entry.value} kali',
                            style: const TextStyle(color: CihuyColors.muted),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Hari ini baru dihitung sebagai hari berhasil setelah selesai. Rokok dan vape dihitung dengan satuan masing-masing.',
              style: TextStyle(fontSize: 12, color: CihuyColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}
