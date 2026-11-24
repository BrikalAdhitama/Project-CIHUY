import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/records.dart';
import '../providers/app_state.dart';
import '../utils/app_theme.dart';
import '../utils/dates.dart';
import 'common.dart';

/// Ringkasan pemicu dan intensitas craving dari catatan 30 hari terakhir.
/// Semua angka dihitung dari catatan nyata; tidak ada data tiruan.
class CravingPatternSummary extends StatelessWidget {
  const CravingPatternSummary({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final today = dayOnly(state.now);
    final from = shiftDay(today, -29);
    final recent = state.cravings
        .where((craving) => !craving.at.isBefore(from))
        .toList();
    final title = SectionTitle(
      'Pola Craving',
      trailing: Text(
        '30 hari terakhir',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );

    if (state.cravings.isEmpty) {
      return SurfaceCard(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            title,
            const SizedBox(height: 6),
            const EmptyMessage(
              'Belum ada craving tercatat.\n'
              'Craving yang kamu catat akan membentuk pola di sini.',
              icon: Icons.psychology_outlined,
            ),
          ],
        ),
      );
    }
    if (recent.isEmpty) {
      return SurfaceCard(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            title,
            const SizedBox(height: 6),
            const EmptyMessage(
              'Tidak ada craving dalam 30 hari terakhir.',
              icon: Icons.event_available_outlined,
            ),
          ],
        ),
      );
    }

    final triggerCounts = <String, int>{};
    for (final craving in recent) {
      for (final trigger in craving.triggers) {
        triggerCounts[trigger] = (triggerCounts[trigger] ?? 0) + 1;
      }
    }
    final triggers = triggerCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topTriggers = triggers.take(5).toList();
    final maxTrigger = topTriggers.isEmpty ? 1 : topTriggers.first.value;
    final intensityCounts = {
      for (final intensity in Intensity.values)
        intensity: recent
            .where((craving) => craving.intensity == intensity)
            .length,
    };
    final resisted = recent.where((craving) => craving.resisted).length;

    return SurfaceCard(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          title,
          const SizedBox(height: 12),
          if (topTriggers.isEmpty)
            const Text(
              'Belum ada pemicu yang dicatat pada craving-mu.',
              style: TextStyle(fontSize: 12, color: CihuyColors.muted),
            )
          else ...[
            Text(
              'Pemicu paling sering',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            for (final trigger in topTriggers) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      trigger.key,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '×${trigger.value}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: CihuyColors.tealInk,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              LinearProgressIndicator(
                minHeight: 6,
                borderRadius: BorderRadius.circular(6),
                value: trigger.value / maxTrigger,
                backgroundColor: CihuyColors.surface,
                color: CihuyColors.teal,
              ),
              const SizedBox(height: 8),
            ],
          ],
          const SizedBox(height: 4),
          Text(
            'Intensitas craving',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final intensity in Intensity.values)
                _IntensityChip(
                  label: intensity.label,
                  count: intensityCounts[intensity]!,
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Kamu menahan $resisted dari ${recent.length} craving tercatat.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _IntensityChip extends StatelessWidget {
  const _IntensityChip({required this.label, required this.count});
  final String label;
  final int count;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: CihuyColors.paleTeal,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      '$label · $count',
      style: const TextStyle(fontSize: 12, color: CihuyColors.tealInk),
    ),
  );
}
