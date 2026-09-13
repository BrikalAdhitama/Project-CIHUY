import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/records.dart';
import '../providers/app_state.dart';
import '../utils/app_theme.dart';
import '../utils/dates.dart';
import '../widgets/asset_icon.dart';
import '../widgets/common.dart';
import 'targets_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final today = dayOnly(state.now);
    final from = shiftDay(today, -6);
    final progress = state.progress;
    return ListView(
      key: const PageStorageKey('home-scroll'),
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
      children: [
        Text('Beranda', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        const QuitTimerCard(),
        const SizedBox(height: 16),
        SurfaceCard(
          onTap: () => state.selectDate(today, openCalendar: true),
          child: Column(
            children: [
              SectionTitle(
                'Rangkuman Mingguan',
                trailing: Text(
                  dateRange(from, today),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: SummaryStat(
                      icon: const Icon(Icons.calendar_today_outlined),
                      value:
                          '${progress.successfulDays(state.now, from: from)}',
                      label: 'Hari target tercapai',
                    ),
                  ),
                  Expanded(
                    child: SummaryStat(
                      icon: const CihuyAssetIcon(CihuyAssetIcon.smoking),
                      value:
                          '${progress.totalInRange(from, today, state.chartHabit)}',
                      label: 'Total konsumsi',
                    ),
                  ),
                  Expanded(
                    child: SummaryStat(
                      icon: const CihuyAssetIcon(
                        CihuyAssetIcon.cravingResisted,
                      ),
                      value: '${progress.resistedInRange(from, today)}',
                      label: 'Craving ditahan',
                    ),
                  ),
                ],
              ),
              if (progress.totalInRange(from, today, Habit.vape) > 0 ||
                  progress.targetOn(today, Habit.vape) != null) ...[
                const SizedBox(height: 12),
                Text(
                  'Rokok: ${progress.totalInRange(from, today, Habit.cigarette)} batang · '
                  'Vape: ${progress.totalInRange(from, today, Habit.vape)} hisapan',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionTitle('Motivasi'),
              const SizedBox(height: 9),
              Text(
                state.profile.reason,
                style: const TextStyle(color: CihuyColors.muted, height: 1.7),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        SectionTitle(
          'Riwayat',
          trailing: Text(
            monthLabel(today),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 46,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: 12,
            separatorBuilder: (_, _) => const SizedBox(width: 7),
            itemBuilder: (context, index) {
              final date = shiftDay(from, index);
              final status = progress.status(date, state.now);
              final red = status == DayStatus.exceeded;
              final achieved = status == DayStatus.achieved;
              final isToday = sameDay(date, today);
              return Semantics(
                label: fullDate(date),
                button: true,
                child: InkWell(
                  borderRadius: BorderRadius.circular(30),
                  onTap: () => state.selectDate(date, openCalendar: true),
                  child: Container(
                    width: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: red
                          ? CihuyColors.pink
                          : achieved
                          ? CihuyColors.teal
                          : isToday
                          ? CihuyColors.paleTeal
                          : CihuyColors.surface,
                      border: isToday
                          ? Border.all(
                              color: red ? CihuyColors.red : CihuyColors.teal,
                            )
                          : null,
                    ),
                    child: Text(
                      '${date.day}',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: red
                            ? CihuyColors.red
                            : achieved
                            ? Colors.white
                            : isToday
                            ? CihuyColors.tealInk
                            : CihuyColors.muted,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 18),
        SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionTitle(
                'Target Hari Ini',
                trailing: TextButton(
                  onPressed: () => openTargets(context),
                  child: const Text('Ubah'),
                ),
              ),
              if (Habit.values.every(
                (habit) => progress.targetOn(today, habit) == null,
              )) ...[
                const Text(
                  'Belum ada target aktif.',
                  style: TextStyle(color: CihuyColors.muted),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => openTargets(context),
                  child: const Text('+ Buat target harian'),
                ),
              ],
              for (final habit in Habit.values)
                if (progress.targetOn(today, habit) case final target?) ...[
                  if (habit == Habit.vape) const SizedBox(height: 14),
                  _TargetProgress(
                    habit: habit,
                    actual: progress.total(today, habit),
                    limit: target.limit,
                  ),
                ],
            ],
          ),
        ),
      ],
    );
  }
}

class QuitTimerCard extends StatefulWidget {
  const QuitTimerCard({super.key});
  @override
  State<QuitTimerCard> createState() => _QuitTimerCardState();
}

class _QuitTimerCardState extends State<QuitTimerCard>
    with WidgetsBindingObserver {
  Timer? _ticker;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<AppState>().refresh();
      setState(() {});
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final elapsed = state.progress.elapsed(state.now);
    final values = [
      if (elapsed.inDays > 0) (elapsed.inDays, 'Hari'),
      (elapsed.inHours % 24, 'Jam'),
      (elapsed.inMinutes % 60, 'Menit'),
      (elapsed.inSeconds % 60, 'Detik'),
    ];
    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconTheme(
                data: IconThemeData(size: 14, color: CihuyColors.muted),
                child: CihuyAssetIcon(CihuyAssetIcon.smokingBan),
              ),
              SizedBox(width: 6),
              Flexible(
                child: Text(
                  'BERHENTI SEJAK',
                  style: TextStyle(fontSize: 12, color: CihuyColors.muted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          SizedBox(
            width: values.length == 4 ? 290 : 228,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final value in values)
                  Expanded(
                    child: Column(
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '${value.$1}',
                            key: Key('timer-${value.$2}'),
                            style: TextStyle(
                              fontSize: values.length == 4 ? 40 : 48,
                              height: 1.15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          value.$2,
                          style: const TextStyle(
                            fontSize: 13,
                            color: CihuyColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 12),
          IntrinsicHeight(
            child: Row(
              children: [
                Expanded(
                  child: _Streak(
                    value: state.progress.currentStreak(state.now),
                    label: 'Streak saat ini',
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: _Streak(
                    value: state.progress.bestStreak(state.now),
                    label: 'Streak terbaik',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Streak extends StatelessWidget {
  const _Streak({required this.value, required this.label});
  final int value;
  final String label;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        '$value',
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 3),
      Text(label, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}

class SummaryStat extends StatelessWidget {
  const SummaryStat({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.unit,
  });
  final Widget icon;
  final String value;
  final String label;
  final String? unit;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      IconTheme(
        data: const IconThemeData(color: CihuyColors.teal, size: 22),
        child: icon,
      ),
      const SizedBox(height: 5),
      Text.rich(
        TextSpan(
          text: value,
          children: [
            if (unit != null)
              TextSpan(
                text: ' $unit',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w400,
                  color: CihuyColors.muted,
                ),
              ),
          ],
        ),
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 3),
      Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 10, color: CihuyColors.muted),
      ),
    ],
  );
}

class _TargetProgress extends StatelessWidget {
  const _TargetProgress({
    required this.habit,
    required this.actual,
    required this.limit,
  });
  final Habit habit;
  final int actual;
  final int limit;
  @override
  Widget build(BuildContext context) {
    final exceeded = actual > limit;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                habit.label,
                style: const TextStyle(color: CihuyColors.muted),
              ),
            ),
            Text(
              '$actual dari $limit ${habit.unit}',
              style: TextStyle(
                color: exceeded ? CihuyColors.red : CihuyColors.ink,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          minHeight: 9,
          borderRadius: BorderRadius.circular(8),
          value: limit == 0
              ? (actual > 0 ? 1 : 0)
              : (actual / limit).clamp(0, 1),
          backgroundColor: CihuyColors.surface,
          color: exceeded ? CihuyColors.red : CihuyColors.teal,
        ),
        const SizedBox(height: 6),
        Text(
          exceeded
              ? 'Melampaui batas · ${actual - limit} ${habit.unit} di atas target'
              : 'Sisa ${limit - actual} ${habit.unit} hari ini',
          style: TextStyle(
            fontSize: 12,
            color: exceeded ? CihuyColors.red : CihuyColors.muted,
          ),
        ),
      ],
    );
  }
}
