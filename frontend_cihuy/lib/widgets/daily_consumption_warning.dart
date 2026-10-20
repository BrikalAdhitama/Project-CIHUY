import 'package:flutter/material.dart';
import '../models/records.dart';
import '../utils/app_theme.dart';
import 'common.dart';

/// Mulai memperingatkan saat konsumsi mencapai 80% dari batas harian.
const double _approachThreshold = 0.80;

enum DailyLimitStatus { safe, approaching, reached, exceeded }

DailyLimitStatus _statusFor(int current, int limit) {
  if (limit <= 0) {
    return current > 0
        ? DailyLimitStatus.exceeded
        : DailyLimitStatus.safe;
  }
  if (current > limit) return DailyLimitStatus.exceeded;
  if (current == limit) return DailyLimitStatus.reached;
  if (current >= limit * _approachThreshold) return DailyLimitStatus.approaching;
  return DailyLimitStatus.safe;
}

/// Kartu peringatan batas konsumsi harian. Menghilang sendiri saat status
/// masih aman, dan menyusut menjadi kosong saat pengguna menekan
/// "Dimengerti" sampai status konsumsi berubah.
class DailyConsumptionWarning extends StatefulWidget {
  const DailyConsumptionWarning({
    super.key,
    required this.habit,
    required this.currentConsumption,
    required this.dailyLimit,
  });

  final Habit habit;
  final int currentConsumption;
  final int dailyLimit;

  @override
  State<DailyConsumptionWarning> createState() =>
      _DailyConsumptionWarningState();
}

class _DailyConsumptionWarningState extends State<DailyConsumptionWarning> {
  DailyLimitStatus? _dismissedStatus;

  @override
  Widget build(BuildContext context) {
    final status = _statusFor(widget.currentConsumption, widget.dailyLimit);
    if (status == DailyLimitStatus.safe || status == _dismissedStatus) {
      return const SizedBox.shrink();
    }
    final (Color background, Color ink, IconData icon, String title, String
    message) = switch (status) {
      DailyLimitStatus.approaching => (
        CihuyColors.amber,
        CihuyColors.amberInk,
        Icons.schedule_rounded,
        'Hampir mencapai batas harian',
        'Konsumsi hari ini sudah mendekati target maksimalmu.',
      ),
      DailyLimitStatus.reached => (
        CihuyColors.amber,
        CihuyColors.amberInk,
        Icons.warning_amber_rounded,
        'Batas harian tercapai',
        'Kamu sudah mencapai batas konsumsi harian yang telah ditentukan.',
      ),
      _ => (
        CihuyColors.pink,
        CihuyColors.red,
        Icons.error_outline_rounded,
        'Batas harian terlewati',
        'Konsumsi hari ini sudah melewati batas harianmu. '
            'Coba tahan konsumsi berikutnya dan catat craving jika muncul.',
      ),
    };
    final progressValue = widget.dailyLimit <= 0
        ? (widget.currentConsumption > 0 ? 1.0 : 0.0)
        : (widget.currentConsumption / widget.dailyLimit).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: ink.withValues(alpha: .14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconTile(icon, color: ink, background: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(color: ink),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(message, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: LinearProgressIndicator(
                  minHeight: 9,
                  borderRadius: BorderRadius.circular(8),
                  value: progressValue,
                  backgroundColor: Colors.white,
                  color: ink,
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  '${widget.currentConsumption}/${widget.dailyLimit} '
                  '${widget.habit.unit}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: ink,
                  ),
                ),
              ),
            ],
          ),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(
              onPressed: () => setState(() => _dismissedStatus = status),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
              ),
              child: const Text('Dimengerti'),
            ),
          ),
        ],
      ),
    );
  }
}
