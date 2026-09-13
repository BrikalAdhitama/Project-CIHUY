import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/records.dart';
import '../providers/app_state.dart';
import '../utils/app_theme.dart';
import '../utils/dates.dart';
import '../widgets/common.dart';

void openTargets(BuildContext context) => Navigator.push(
  context,
  MaterialPageRoute<void>(builder: (_) => const TargetsScreen()),
);

class TargetsScreen extends StatelessWidget {
  const TargetsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final today = dayOnly(state.now);
    final current = state.targets
        .where(
          (target) => target.endsOn == null || target.endsOn!.isAfter(today),
        )
        .toList();
    final history =
        state.targets
            .where(
              (target) =>
                  target.endsOn != null && !target.endsOn!.isAfter(today),
            )
            .toList()
          ..sort((a, b) => b.startsOn.compareTo(a.startsOn));
    return Scaffold(
      appBar: AppBar(title: const Text('Target harian')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            const Text(
              'Langkah kecil, setiap hari',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            const Text(
              'Atur batas rokok dan vape secara terpisah. Setiap perubahan memiliki tanggal berlaku; target masa lalu tetap tersimpan.',
              style: TextStyle(color: CihuyColors.muted),
            ),
            const SizedBox(height: 20),
            const SectionTitle('Target aktif & terjadwal'),
            const SizedBox(height: 12),
            if (current.isEmpty)
              const SurfaceCard(
                child: Center(
                  child: EmptyMessage(
                    'Belum ada target.\nMulai dengan batas yang sesuai untukmu.',
                    icon: Icons.flag_outlined,
                  ),
                ),
              ),
            for (final target in current)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _TargetCard(target: target),
              ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: () => openSheet(context, const TargetForm()),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Tambah target'),
            ),
            const SizedBox(height: 28),
            const SectionTitle('Riwayat target'),
            const SizedBox(height: 12),
            if (history.isEmpty)
              const EmptyMessage('Belum ada perubahan target.'),
            for (final target in history)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _TargetCard(target: target, history: true),
              ),
            const SizedBox(height: 12),
            const Text(
              'Jika kedua jenis memiliki target, satu hari berhasil ketika kedua batas terpenuhi. Hari mendatang dan hari ini yang belum selesai belum dihitung sebagai keberhasilan.',
              style: TextStyle(fontSize: 12, color: CihuyColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _TargetCard extends StatelessWidget {
  const _TargetCard({required this.target, this.history = false});
  final DailyTarget target;
  final bool history;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final today = dayOnly(state.now);
    final replaced = target.endsOn == target.startsOn;
    final effective = replaced
        ? 'Digantikan sebelum berlaku'
        : '${shortDate(target.startsOn)} – ${target.endsOn == null ? 'seterusnya' : shortDate(shiftDay(target.endsOn!, -1))}';
    return SurfaceCard(
      onTap: () => openSheet(
        context,
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SheetHeading('Target ${target.habit.label}'),
            Text(
              '${target.limit} ${target.habit.unit} per hari',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            Text('Periode: $effective'),
            const SizedBox(height: 16),
            const Text(
              'Status harian membandingkan jumlah konsumsi dengan target yang berlaku pada tanggal kejadian.',
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Tutup'),
            ),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconTile.child(habitIcon(target.habit)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      target.habit.label,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '${target.limit} ${target.habit.unit} per hari',
                      style: const TextStyle(color: CihuyColors.muted),
                    ),
                  ],
                ),
              ),
              Text(
                history
                    ? 'Selesai'
                    : target.startsOn.isAfter(today)
                    ? 'Terjadwal'
                    : 'Aktif',
                style: TextStyle(
                  fontSize: 11,
                  color: history ? CihuyColors.muted : CihuyColors.tealInk,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(effective, style: Theme.of(context).textTheme.bodySmall),
          if (!history) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                TextButton(
                  onPressed: () =>
                      openSheet(context, TargetForm(target: target)),
                  child: const Text('Edit target'),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () async {
                    final tomorrow = shiftDay(today, 1);
                    final end = target.startsOn.isAfter(tomorrow)
                        ? target.startsOn
                        : tomorrow;
                    final confirm = await confirmAction(
                      context,
                      title: 'Nonaktifkan target?',
                      message:
                          'Target ${target.habit.label} tidak berlaku mulai ${shortDate(end)}. Periode sebelumnya tetap ada dalam riwayat.',
                      confirm: 'Nonaktifkan',
                    );
                    if (confirm && context.mounted) {
                      state.deactivateTarget(target, end);
                      showMessage(
                        context,
                        'Target dinonaktifkan mulai ${shortDate(end)}.',
                      );
                    }
                  },
                  child: const Text(
                    'Nonaktifkan',
                    style: TextStyle(color: CihuyColors.red),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class TargetForm extends StatefulWidget {
  const TargetForm({super.key, this.target});
  final DailyTarget? target;
  @override
  State<TargetForm> createState() => _TargetFormState();
}

class _TargetFormState extends State<TargetForm> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _limit;
  late Habit _habit;
  late DateTime _start;
  DateTime? _end;
  String? _error;
  @override
  void initState() {
    super.initState();
    final state = context.read<AppState>();
    _habit = widget.target?.habit ?? Habit.cigarette;
    _limit = TextEditingController(text: '${widget.target?.limit ?? 5}');
    final latest = state.targets
        .where((target) => target.habit == _habit)
        .map((target) => target.startsOn)
        .fold(dayOnly(state.now), (a, b) => a.isAfter(b) ? a : b);
    final proposed = widget.target == null
        ? dayOnly(state.now)
        : shiftDay(state.now, 1);
    _start = latest.isAfter(proposed) ? latest : proposed;
    _end = widget.target?.endsOn == null
      ? null
      : shiftDay(widget.target!.endsOn!, -1);
  }

  @override
  void dispose() {
    _limit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Form(
    key: _form,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SheetHeading(
          widget.target == null ? 'Tambah target harian' : 'Edit target harian',
          subtitle: 'Perubahan disimpan sebagai periode baru.',
        ),
        const FieldLabel('Jenis kebiasaan'),
        if (widget.target == null)
          HabitSelector(
            value: _habit,
            onChanged: (habit) => setState(() => _habit = habit),
          )
        else
          Text(
            _habit.label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        const SizedBox(height: 18),
        FieldLabel('Batas harian (${_habit.unit})'),
        TextFormField(
          key: const Key('target-limit'),
          controller: _limit,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            suffixText: _habit.unit,
            helperText: 'Batas 0 berarti berhenti sepenuhnya.',
          ),
          validator: (value) =>
              int.tryParse(value ?? '') == null || int.parse(value!) < 0
              ? 'Isi bilangan bulat 0 atau lebih'
              : null,
        ),
        const SizedBox(height: 18),
        const FieldLabel('Berlaku mulai'),
        OutlinedButton(
          onPressed: () async {
            final now = context.read<AppState>().now;
            final date = await showDatePicker(
              context: context,
              initialDate: _start,
              firstDate: dayOnly(now),
              lastDate: DateTime(now.year + 5),
            );
            if (date != null) setState(() => _start = date);
          },
          child: Row(
            children: [
              Expanded(child: Text(shortDate(_start))),
              const Icon(Icons.calendar_today_outlined, size: 17),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const FieldLabel('Berlaku sampai (opsional)'),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () async {
                  final now = context.read<AppState>().now;
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _end ?? _start,
                    firstDate: _start,
                    lastDate: DateTime(now.year + 5),
                  );
                  if (date != null) setState(() => _end = date);
                },
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _end == null ? 'Sampai seterusnya' : shortDate(_end!),
                      ),
                    ),
                    const Icon(Icons.calendar_today_outlined, size: 17),
                  ],
                ),
              ),
            ),
            if (_end != null)
              IconButton(
                tooltip: 'Hapus tanggal selesai',
                onPressed: () => setState(() => _end = null),
                icon: const Icon(Icons.clear),
              ),
          ],
        ),
        const Text(
          'Kosongkan jika target berlaku tanpa batas waktu.',
          style: TextStyle(fontSize: 12, color: CihuyColors.muted),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              _error!,
              style: const TextStyle(color: CihuyColors.red),
            ),
          ),
        const SizedBox(height: 22),
        FilledButton(
          onPressed: () {
            if (!_form.currentState!.validate()) return;
            try {
              context.read<AppState>().setTarget(
                habit: _habit,
                limit: int.parse(_limit.text),
                startsOn: _start,
                endsOn: _end == null ? null : shiftDay(_end!, 1),
              );
              Navigator.pop(context);
            } on ArgumentError catch (error) {
              setState(() => _error = '${error.message}');
            }
          },
          child: const Text('Simpan target'),
        ),
      ],
    ),
  );
}
