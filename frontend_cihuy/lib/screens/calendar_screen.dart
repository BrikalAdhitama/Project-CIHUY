import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/records.dart';
import '../providers/app_state.dart';
import '../utils/app_theme.dart';
import '../utils/dates.dart';
import '../widgets/common.dart';
import '../widgets/record_forms.dart';
import '../widgets/record_details.dart';
import 'progress_screen.dart';

class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return ListView(
      key: const PageStorageKey('calendar-scroll'),
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
      children: [
        Text('Kalender', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _MonthButton(
              icon: Icons.chevron_left,
              label: 'Bulan sebelumnya',
              onTap: () => state.changeMonth(-1),
            ),
            Text(
              monthLabel(state.visibleMonth),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            _MonthButton(
              icon: Icons.chevron_right,
              label: 'Bulan berikutnya',
              onTap: () => state.changeMonth(1),
            ),
          ],
        ),
        const SizedBox(height: 10),
        const MonthGrid(),
        const SizedBox(height: 12),
        const Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            _Legend('Target tercapai', CihuyColors.green),
            _Legend('Batas terlampaui', CihuyColors.pink),
            _Legend('Hari ini', CihuyColors.teal),
            _Legend('Belum dinilai', CihuyColors.surface),
          ],
        ),
        const SizedBox(height: 16),
        const ConsumptionChart(),
        const SizedBox(height: 14),
        const DailyDetails(),
        const SizedBox(height: 10),
        TextButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute<void>(builder: (_) => const ProgressScreen()),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Lihat detail progres'),
              SizedBox(width: 4),
              Icon(Icons.arrow_forward, size: 16),
            ],
          ),
        ),
      ],
    );
  }
}

class _MonthButton extends StatelessWidget {
  const _MonthButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => IconButton.outlined(
    tooltip: label,
    onPressed: onTap,
    style: IconButton.styleFrom(
      side: const BorderSide(color: CihuyColors.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    icon: Icon(icon, size: 20),
  );
}

class MonthGrid extends StatelessWidget {
  const MonthGrid({super.key});
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final month = state.visibleMonth;
    final offset = month.weekday % 7;
    final days = DateTime(month.year, month.month + 1, 0).day;
    final cells = ((offset + days) / 7).ceil() * 7;
    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(10, 16, 10, 14),
      child: Column(
        children: [
          Row(
            children: [
              for (final day in [
                'Min',
                'Sen',
                'Sel',
                'Rab',
                'Kam',
                'Jum',
                'Sab',
              ])
                Expanded(
                  child: Text(
                    day,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      color: CihuyColors.muted,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: cells,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              crossAxisSpacing: 3,
              mainAxisSpacing: 4,
              childAspectRatio: .97,
            ),
            itemBuilder: (context, index) {
              final number = index - offset + 1;
              if (number < 1 || number > days) return const SizedBox.shrink();
              final date = DateTime(month.year, month.month, number);
              return CalendarDay(
                date: date,
                status: state.progress.status(date, state.now),
                selected: sameDay(date, state.selectedDay),
                today: sameDay(date, state.now),
                future: date.isAfter(dayOnly(state.now)),
                onTap: () => state.selectDate(date),
              );
            },
          ),
        ],
      ),
    );
  }
}

class CalendarDay extends StatelessWidget {
  const CalendarDay({
    super.key,
    required this.date,
    required this.status,
    required this.selected,
    required this.today,
    required this.future,
    required this.onTap,
  });
  final DateTime date;
  final DayStatus status;
  final bool selected;
  final bool today;
  final bool future;
  final VoidCallback onTap;

  Color get background => status == DayStatus.exceeded
      ? CihuyColors.pink
      : today
      ? CihuyColors.teal
      : status == DayStatus.achieved
      ? CihuyColors.green
      : Colors.white;
  Color get foreground => status == DayStatus.exceeded
      ? CihuyColors.red
      : today
      ? Colors.white
      : status == DayStatus.achieved
      ? CihuyColors.greenInk
      : future
      ? const Color(0xFFBBC5D3)
      : CihuyColors.ink;
  Color get outline =>
      status == DayStatus.exceeded ? CihuyColors.red : CihuyColors.teal;

  @override
  Widget build(BuildContext context) => Semantics(
    label:
        '${fullDate(date)}${today ? ', hari ini' : ''}, ${switch (status) {
          DayStatus.exceeded => 'batas terlampaui',
          DayStatus.achieved => 'target tercapai',
          DayStatus.inProgress => 'masih berlangsung',
          DayStatus.unassessed => 'belum dinilai',
        }}',
    selected: selected,
    button: true,
    child: Container(
      key: Key('calendar-${DateFormat('yyyy-MM-dd').format(date)}'),
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selected ? outline : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(11),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Text(
                '${date.day}',
                style: TextStyle(
                  fontSize: 13,
                  color: foreground,
                  fontWeight: today || selected
                      ? FontWeight.w700
                      : FontWeight.w500,
                ),
              ),
              if (today && status == DayStatus.exceeded)
                Positioned(
                  bottom: 3,
                  child: Container(
                    width: 4,
                    height: 4,
                    decoration: const BoxDecoration(
                      color: CihuyColors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _Legend extends StatelessWidget {
  const _Legend(this.label, this.color);
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 11,
        height: 11,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      const SizedBox(width: 5),
      Text(
        label,
        style: const TextStyle(fontSize: 11, color: CihuyColors.muted),
      ),
    ],
  );
}

class ConsumptionChart extends StatefulWidget {
  const ConsumptionChart({super.key});
  @override
  State<ConsumptionChart> createState() => _ConsumptionChartState();
}

class _ConsumptionChartState extends State<ConsumptionChart> {
  int _days = 7;
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final end = state.chartEnd;
    final selectedDay = state.selectedDay;
    final from = shiftDay(end, -(_days - 1));
    final habit = state.chartHabit;
    final dates = List.generate(_days, (index) => shiftDay(from, index));
    final values = dates
        .map((day) => state.progress.total(day, habit))
        .toList();
    final total = values.fold(0, (sum, value) => sum + value);
    final maximum = math.max(1, values.reduce(math.max));
    final showHabit =
        state.consumption.any((entry) => entry.habit == Habit.vape) ||
        state.targets.any((target) => target.habit == Habit.vape);
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(
            'Konsumsi $_days Hari Terakhir',
            trailing: Text(
              dateRange(from, end),
              key: const Key('chart-range'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 7, label: Text('7 Hari')),
                    ButtonSegment(value: 30, label: Text('30 Hari')),
                  ],
                  selected: {_days},
                  showSelectedIcon: false,
                  onSelectionChanged: (selection) =>
                      setState(() => _days = selection.first),
                  style: ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  'Jumlah ${habit.unit}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10, color: CihuyColors.muted),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
          if (showHabit) ...[
            const SizedBox(height: 10),
            HabitSelector(value: habit, onChanged: state.selectHabit),
          ],
          const SizedBox(height: 10),
          if (_days == 7)
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var index = 0; index < _days; index++)
                  Expanded(
                    child: ChartBar(
                      date: dates[index],
                      amount: values[index],
                      maximum: maximum,
                      habit: habit,
                      exceeded: state.progress.exceeds(dates[index], habit),
                      selected: sameDay(dates[index], selectedDay),
                      onTap: () => state.selectDate(
                        dates[index],
                        keepChartRange: true,
                      ),
                    ),
                  ),
              ],
            )
          else
            SizedBox(
              height: 140,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var index = 0; index < _days; index++)
                      SizedBox(
                        width: 40,
                        child: ChartBar(
                          date: dates[index],
                          amount: values[index],
                          maximum: maximum,
                          habit: habit,
                          exceeded: state.progress.exceeds(
                            dates[index],
                            habit,
                          ),
                          selected: sameDay(dates[index], selectedDay),
                          onTap: () => state.selectDate(
                            dates[index],
                            keepChartRange: true,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          if (total == 0)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Belum ada catatan konsumsi pada rentang ini.',
                style: TextStyle(fontSize: 12, color: CihuyColors.muted),
              ),
            ),
        ],
      ),
    );
  }
}

class ChartBar extends StatelessWidget {
  const ChartBar({
    super.key,
    required this.date,
    required this.amount,
    required this.maximum,
    required this.habit,
    required this.exceeded,
    required this.selected,
    required this.onTap,
  });
  final DateTime date;
  final int amount;
  final int maximum;
  final Habit habit;
  final bool exceeded;
  final bool selected;
  final VoidCallback onTap;
  Color get color => exceeded
      ? const Color(0xFFF49B9F)
      : selected
      ? CihuyColors.teal
      : const Color(0xFFA3E9E7);
  @override
  Widget build(BuildContext context) => Semantics(
    label:
        '${shortDate(date)}: $amount ${habit.unit}${exceeded ? ', batas terlampaui' : ''}',
    button: true,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 97,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    '$amount',
                    style: TextStyle(
                      fontSize: 10,
                      color: exceeded ? CihuyColors.red : CihuyColors.muted,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Container(
                    key: Key('bar-${DateFormat('yyyy-MM-dd').format(date)}'),
                    height: amount == 0 ? 2 : 76 * amount / maximum,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: amount == 0 ? CihuyColors.surface : color,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(6),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 7),
            Text(
              DateFormat('EEE', 'id_ID').format(date),
              style: TextStyle(
                fontSize: 10,
                color: exceeded
                    ? CihuyColors.red
                    : selected
                    ? CihuyColors.tealInk
                    : CihuyColors.muted,
              ),
            ),
            Text(
              '${date.day}',
              style: const TextStyle(fontSize: 10, color: CihuyColors.muted),
            ),
          ],
        ),
      ),
    ),
  );
}

class DailyDetails extends StatelessWidget {
  const DailyDetails({super.key});
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final day = state.selectedDay;
    final consumptions = state.consumptionOn(day);
    final cravings = state.cravingsOn(day);
    final isFuture = day.isAfter(dayOnly(state.now));
    void add(bool consumption) {
      if (isFuture) {
        showMessage(
          context,
          'Catatan hanya bisa dibuat untuk hari ini atau masa lalu.',
        );
        return;
      }
      if (consumption) {
        showConsumptionForm(context, date: day);
      } else {
        showCravingForm(context, date: day);
      }
    }

    return SurfaceCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fullDate(day),
                  key: const Key('daily-date'),
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                for (final habit in Habit.values)
                  if (state.progress.exceeds(day, habit))
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: ExceededBadge(
                        total: state.progress.total(day, habit),
                        limit: state.progress.targetOn(day, habit)!.limit,
                        habit: habit,
                      ),
                    ),
                if (state.progress.status(day, state.now) == DayStatus.achieved)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      '✓ Target tercapai',
                      style: TextStyle(
                        fontSize: 12,
                        color: CihuyColors.greenInk,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'CATATAN KONSUMSI',
                    style: TextStyle(fontSize: 12, color: CihuyColors.muted),
                  ),
                ),
                TextButton(
                  key: const Key('add-consumption'),
                  onPressed: () => add(true),
                  child: const Text('+ Tambah'),
                ),
              ],
            ),
          ),
          if (consumptions.isEmpty)
            const Center(child: EmptyMessage('Belum ada catatan konsumsi.')),
          for (final entry in consumptions)
            ListTile(
              key: Key('consumption-${entry.id}'),
              dense: true,
              leading: IconTile.child(
                habitIcon(entry.habit),
                size: 29,
                color: const Color(0xFFB49B48),
                background: const Color(0xFFFFF3C7),
              ),
              title: Text(
                '${entry.habit.label} · ${entry.amount} ${entry.habit.unit}',
                style: const TextStyle(fontSize: 13),
              ),
              trailing: Text(
                clockLabel(entry.at),
                style: const TextStyle(fontSize: 11, color: CihuyColors.muted),
              ),
              onTap: () => showConsumptionDetails(context, entry),
            ),
          const SizedBox(height: 10),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'CATATAN CRAVING',
                    style: TextStyle(fontSize: 12, color: CihuyColors.muted),
                  ),
                ),
                TextButton(
                  key: const Key('add-craving'),
                  onPressed: () => add(false),
                  child: const Text('+ Tambah'),
                ),
              ],
            ),
          ),
          if (cravings.isEmpty)
            const Center(
              child: EmptyMessage(
                'Belum ada catatan craving.',
                icon: Icons.bolt_outlined,
              ),
            ),
          for (final entry in cravings)
            ListTile(
              key: Key('craving-${entry.id}'),
              dense: true,
              leading: const IconTile(Icons.bolt_outlined, size: 29),
              title: Text(
                '${entry.habit.label} · ${entry.intensity.label}',
                style: const TextStyle(fontSize: 13),
              ),
              subtitle: Text(
                entry.resisted ? 'Berhasil ditahan' : 'Akhirnya konsumsi',
                style: TextStyle(
                  fontSize: 11,
                  color: entry.resisted
                      ? CihuyColors.greenInk
                      : CihuyColors.muted,
                ),
              ),
              trailing: Text(
                clockLabel(entry.at),
                style: const TextStyle(fontSize: 11, color: CihuyColors.muted),
              ),
              onTap: () => showCravingDetails(context, entry),
            ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
