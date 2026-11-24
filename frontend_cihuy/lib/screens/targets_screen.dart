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
          (target) =>
              !target.habit.isLegacy &&
              (target.endsOn == null || target.endsOn!.isAfter(today)),
        )
        .toList();
    final legacy = state.targets
        .where(
          (target) =>
              target.habit.isLegacy &&
              (target.endsOn == null || target.endsOn!.isAfter(today)),
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
              'Atur batas rokok harian dalam batang atau bungkus. Setiap perubahan memiliki tanggal berlaku; target masa lalu tetap tersimpan.',
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
            if (legacy.isNotEmpty) ...[
              const SizedBox(height: 28),
              const SectionTitle('Target vape lama'),
              const SizedBox(height: 6),
              const Text(
                'Vape tidak lagi tersedia untuk catatan baru. Target lama tetap dipakai untuk statistik historis; nonaktifkan bila sudah tidak dipakai.',
                style: TextStyle(fontSize: 12, color: CihuyColors.muted),
              ),
              const SizedBox(height: 12),
              for (final target in legacy)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _TargetCard(target: target, legacy: true),
                ),
            ],
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
              'Satu hari dihitung berhasil ketika konsumsi tidak melewati batas yang berlaku. Hari ini dan hari mendatang belum dihitung sebagai keberhasilan.',
              style: TextStyle(fontSize: 12, color: CihuyColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _TargetCard extends StatelessWidget {
  const _TargetCard({
    required this.target,
    this.history = false,
    this.legacy = false,
  });
  final DailyTarget target;
  final bool history;
  final bool legacy;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final today = dayOnly(state.now);
    final tomorrow = shiftDay(today, 1);
    final scheduled = target.startsOn.isAfter(today);
    final replaced = target.endsOn == target.startsOn;
    final limitLabel = target.habit.isLegacy
        ? '${target.limit} ${target.habit.unit} per hari'
        : '${cigaretteAmountLabel(target.limit, state.sticksPerPack)} per hari';
    final effective = replaced
        ? 'Digantikan sebelum berlaku'
        : '${shortDate(target.startsOn)} – ${target.endsOn == null ? 'seterusnya' : shortDate(shiftDay(target.endsOn!, -1))}';
    return SurfaceCard(
      onTap: () => openSheet(
        context,
        Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SheetHeading('Target ${target.habit.legacyLabel}'),
            Text(limitLabel, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            Text('Periode: $effective'),
            const SizedBox(height: 16),
            const Text(
              'Status harian membandingkan jumlah konsumsi dengan target yang berlaku pada tanggal kejadian.',
            ),
            const SizedBox(height: 8),
            const Text(
              'Menonaktifkan target tidak menghapus riwayat; periode lama tetap dipakai untuk statistik hari sebelum tanggal nonaktifnya.',
              style: TextStyle(fontSize: 12, color: CihuyColors.muted),
            ),
            const SizedBox(height: 20),
            if (!history && target.startsOn.isAfter(today)) ...[
              OutlinedButton(
                onPressed: () async {
                  final confirm = await confirmAction(
                    context,
                    title: 'Hapus target terjadwal?',
                    message:
                        'Target belum pernah berjalan sehingga dapat dihapus permanen tanpa memengaruhi statistik historis.',
                    confirm: 'Hapus',
                  );
                  if (confirm && context.mounted) {
                    state.removeScheduledTarget(target);
                    Navigator.pop(context);
                    showMessage(context, 'Target terjadwal dihapus.');
                  }
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: CihuyColors.red,
                ),
                child: const Text('Hapus permanen'),
              ),
              const SizedBox(height: 12),
            ],
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Tutup'),
            ),
          ],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              IconTile.child(habitIcon(target.habit)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      target.habit.legacyLabel,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      limitLabel,
                      style: const TextStyle(color: CihuyColors.muted),
                    ),
                  ],
                ),
              ),
              Text(
                history
                    ? 'Selesai'
                    : scheduled
                    ? 'Terjadwal'
                    : target.endsOn == null
                    ? 'Aktif'
                    : 'Berakhir',
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
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                if (!legacy)
                  TextButton(
                    onPressed: () =>
                        openSheet(context, TargetForm(target: target)),
                    child: Text(scheduled ? 'Edit jadwal' : 'Edit target'),
                  ),
                if (scheduled)
                  TextButton(
                    onPressed: () async {
                      final confirm = await confirmAction(
                        context,
                        title: 'Batalkan jadwal?',
                        message:
                            'Target ${target.habit.legacyLabel} yang dijadwalkan mulai ${shortDate(target.startsOn)} dihapus permanen. Target sebelumnya kembali berlaku bila ada.',
                        confirm: 'Batalkan',
                      );
                      if (confirm && context.mounted) {
                        state.removeScheduledTarget(target);
                        showMessage(context, 'Jadwal target dibatalkan.');
                      }
                    },
                    child: const Text(
                      'Batalkan jadwal',
                      style: TextStyle(color: CihuyColors.red),
                    ),
                  )
                else if (target.endsOn == null ||
                    target.endsOn!.isAfter(tomorrow))
                  TextButton(
                    onPressed: () async {
                      final confirm = await confirmAction(
                        context,
                        title: 'Nonaktifkan target?',
                        message:
                            'Target ${target.habit.legacyLabel} tidak berlaku mulai ${shortDate(tomorrow)}. Hari sebelum tanggal itu tetap tersimpan dalam riwayat.',
                        confirm: 'Nonaktifkan',
                      );
                      if (confirm && context.mounted) {
                        state.deactivateTarget(target, tomorrow);
                        showMessage(
                          context,
                          'Target dinonaktifkan mulai ${shortDate(tomorrow)}.',
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

  /// Batas diisi dalam bungkus? Nilai tetap disimpan dalam batang.
  bool _usePacks = false;

  @override
  void initState() {
    super.initState();
    final state = context.read<AppState>();
    _habit = widget.target?.habit ?? Habit.cigarette;
    _limit = TextEditingController(text: '${widget.target?.limit ?? 5}');
    final today = dayOnly(state.now);
    // Target yang belum berjalan diedit pada tanggal mulainya; target yang
    // sedang berjalan diedit mulai hari ini supaya hanya ada satu target aktif
    // (periode sebelumnya pindah ke riwayat). Tanggal tidak digeser diam-diam
    // ke jadwal lain; benturan jadwal dilaporkan saat menyimpan.
    _start = widget.target == null || !widget.target!.startsOn.isAfter(today)
        ? today
        : widget.target!.startsOn;
    _end = widget.target?.endsOn == null
        ? null
        : shiftDay(widget.target!.endsOn!, -1);
  }

  @override
  void dispose() {
    _limit.dispose();
    super.dispose();
  }

  int get _sticksPerPack => context.read<AppState>().sticksPerPack;
  int get _entered => int.tryParse(_limit.text.trim()) ?? 0;

  /// Nilai batang yang akan disimpan; bungkus hanya satuan masukan.
  int get _total => _usePacks ? _entered * _sticksPerPack : _entered;

  String get _unitLabel => _usePacks ? 'bungkus' : _habit.unit;

  void _setUnit(bool packs) {
    if (packs == _usePacks) return;
    setState(() {
      _usePacks = packs;
      // Angka lama tidak dikonversi diam-diam agar nilainya tidak berubah
      // berkali-kali lipat; pengguna melihat padanan batang di bawah kolom.
      _limit.text = '1';
      _error = null;
    });
  }

  String get _limitHelper {
    if (_habit.isLegacy) return 'Batas 0 berarti berhenti sepenuhnya.';
    if (_usePacks) {
      return '= $_total batang per hari · 0 berarti berhenti sepenuhnya.';
    }
    return '${cigaretteAmountLabel(_total, _sticksPerPack)} per hari · '
        '0 berarti berhenti sepenuhnya.';
  }

  @override
  Widget build(BuildContext context) => Form(
    key: _form,
    child: Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SheetHeading(
          widget.target == null ? 'Tambah target harian' : 'Edit target harian',
          subtitle: 'Perubahan disimpan sebagai periode baru.',
        ),
        if (_habit.isLegacy) ...[
          Text(
            'Target vape (lama)',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 18),
        ],
        if (!_habit.isLegacy) ...[
          const FieldLabel('Satuan'),
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: ChoiceButton(
                  selected: !_usePacks,
                  label: 'Batang',
                  icon: habitIcon(Habit.cigarette),
                  onTap: () => _setUnit(false),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ChoiceButton(
                  selected: _usePacks,
                  label: 'Bungkus',
                  icon: const Icon(Icons.inventory_2_outlined),
                  onTap: () => _setUnit(true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '1 bungkus = $_sticksPerPack batang. Isi per bungkus bisa diubah di Profil.',
            style: const TextStyle(fontSize: 11, color: CihuyColors.muted),
          ),
          const SizedBox(height: 16),
        ],
        FieldLabel('Batas harian ($_unitLabel)'),
        TextFormField(
          key: const Key('target-limit'),
          controller: _limit,
          keyboardType: TextInputType.number,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            suffixText: _unitLabel,
            helperText: _limitHelper,
          ),
          validator: (value) {
            final amount = int.tryParse((value ?? '').trim());
            return amount == null || amount < 0
                ? 'Isi bilangan bulat 0 atau lebih'
                : null;
          },
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
              lastDate: DateTime(now.year + 5, 12, 31),
            );
            if (date != null) {
              setState(() {
                _start = date;
                // Tanggal selesai yang jadi lebih awal dari tanggal mulai
                // dibuang agar tidak menyisakan kombinasi yang tidak valid.
                if (_end != null && !_end!.isAfter(_start)) _end = null;
              });
            }
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: Text(shortDate(_start))),
              const Icon(Icons.calendar_today_outlined, size: 17),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const FieldLabel('Berlaku sampai (opsional)'),
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () async {
                  final now = context.read<AppState>().now;
                  final first = shiftDay(_start, 1);
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _end == null || !_end!.isAfter(_start)
                        ? first
                        : _end!,
                    firstDate: first,
                    lastDate: DateTime(now.year + 6, 12, 31),
                  );
                  if (date != null) setState(() => _end = date);
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.center,
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
                limit: _total,
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
