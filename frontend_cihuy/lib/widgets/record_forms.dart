import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/records.dart';
import '../providers/app_state.dart';
import '../utils/app_theme.dart';
import '../utils/dates.dart';
import 'common.dart';

Future<void> showRecordChooser(BuildContext context) async {
  final choice = await showModalBottomSheet<int>(
    context: context,
    backgroundColor: Colors.transparent,
    elevation: 0,
    barrierColor: Colors.black.withValues(alpha: .42),
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 78),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(17),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'Pilih jenis catatan',
                  style: TextStyle(fontSize: 12, color: CihuyColors.muted),
                ),
              ),
              const Divider(),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 5,
                ),
                leading: const IconTile(Icons.add_circle_outline, size: 40),
                title: const Text(
                  'Catat Konsumsi',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Rokok atau vape yang baru dikonsumsi',
                  style: TextStyle(fontSize: 12, color: CihuyColors.muted),
                ),
                onTap: () => Navigator.pop(context, 0),
              ),
              const Divider(),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 5,
                ),
                leading: const IconTile(
                  Icons.bolt_outlined,
                  size: 40,
                  background: Color(0xFFFFF3C7),
                  color: Color(0xFFDC9000),
                ),
                title: const Text(
                  'Catat Craving',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Dorongan merokok yang kamu rasakan',
                  style: TextStyle(fontSize: 12, color: CihuyColors.muted),
                ),
                onTap: () => Navigator.pop(context, 1),
              ),
              const Divider(),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Batal',
                    style: TextStyle(color: CihuyColors.muted),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  if (!context.mounted || choice == null) return;
  if (choice == 0) {
    await showConsumptionForm(context);
  } else {
    await showCravingForm(context);
  }
}

DateTime _initialTime(AppState state, DateTime? date) => date == null
    ? state.now
    : DateTime(
        date.year,
        date.month,
        date.day,
        state.now.hour,
        state.now.minute,
      );

Future<void> showConsumptionForm(
  BuildContext context, {
  Consumption? entry,
  DateTime? date,
  DateTime? at,
  Habit? habit,
}) async {
  final state = context.read<AppState>();
  final result = await openSheet<Consumption>(
    context,
    ConsumptionForm(
      entry: entry,
      initialTime: entry?.at ?? at ?? _initialTime(state, date),
      initialHabit: entry?.habit ?? habit ?? Habit.cigarette,
    ),
  );
  if (context.mounted && result != null) {
    showMessage(
      context,
      entry == null
          ? 'Catatan konsumsi disimpan.'
          : 'Catatan konsumsi diperbarui.',
    );
  }
}

Future<void> showCravingForm(
  BuildContext context, {
  Craving? entry,
  DateTime? date,
}) async {
  final state = context.read<AppState>();
  final result = await openSheet<Craving>(
    context,
    CravingForm(
      entry: entry,
      initialTime: entry?.at ?? _initialTime(state, date),
    ),
  );
  if (!context.mounted || result == null) return;
  showMessage(
    context,
    entry == null ? 'Catatan craving disimpan.' : 'Catatan craving diperbarui.',
  );
  if (!result.resisted && (entry == null || entry.resisted)) {
    final add = await confirmAction(
      context,
      title: 'Catat konsumsinya juga?',
      message:
          'Craving sudah disimpan. Jika kamu mengonsumsi rokok atau vape, catat jumlahnya agar progres tetap akurat.',
      confirm: 'Catat konsumsi',
      destructive: false,
    );
    if (add && context.mounted) {
      await showConsumptionForm(context, at: result.at, habit: result.habit);
    }
  }
}

class DateTimeFields extends StatelessWidget {
  const DateTimeFields({
    super.key,
    required this.value,
    required this.onChanged,
  });
  final DateTime value;
  final ValueChanged<DateTime> onChanged;
  @override
  Widget build(BuildContext context) {
    final now = context.read<AppState>().now;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const FieldLabel('Tanggal'),
              OutlinedButton(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: value.isAfter(now) ? now : value,
                    firstDate: DateTime(2000),
                    lastDate: dayOnly(now),
                    helpText: 'Tanggal kejadian',
                  );
                  if (picked != null) {
                    onChanged(
                      DateTime(
                        picked.year,
                        picked.month,
                        picked.day,
                        value.hour,
                        value.minute,
                      ),
                    );
                  }
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    const Icon(
                      Icons.calendar_today_outlined,
                      size: 15,
                      color: CihuyColors.muted,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const FieldLabel('Waktu'),
              OutlinedButton(
                onPressed: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.fromDateTime(value),
                    helpText: 'Waktu kejadian',
                    builder: (context, child) => MediaQuery(
                      data: MediaQuery.of(
                        context,
                      ).copyWith(alwaysUse24HourFormat: true),
                      child: child!,
                    ),
                  );
                  if (picked != null) {
                    onChanged(
                      DateTime(
                        value.year,
                        value.month,
                        value.day,
                        picked.hour,
                        picked.minute,
                      ),
                    );
                  }
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      clockLabel(value),
                      style: const TextStyle(fontSize: 13),
                    ),
                    const Icon(
                      Icons.schedule_outlined,
                      size: 16,
                      color: CihuyColors.muted,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class ConsumptionForm extends StatefulWidget {
  const ConsumptionForm({
    super.key,
    this.entry,
    required this.initialTime,
    required this.initialHabit,
  });
  final Consumption? entry;
  final DateTime initialTime;
  final Habit initialHabit;
  @override
  State<ConsumptionForm> createState() => _ConsumptionFormState();
}

class _ConsumptionFormState extends State<ConsumptionForm> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _amount;
  late final TextEditingController _note;
  late Habit _habit;
  late DateTime _at;
  String? _error;
  @override
  void initState() {
    super.initState();
    _habit = widget.initialHabit;
    _at = widget.initialTime;
    _amount = TextEditingController(text: '${widget.entry?.amount ?? 1}');
    _note = TextEditingController(text: widget.entry?.note ?? '');
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    try {
      final result = context.read<AppState>().saveConsumption(
        id: widget.entry?.id,
        habit: _habit,
        amount: int.parse(_amount.text),
        at: _at,
        note: _note.text,
      );
      Navigator.pop(context, result);
    } on ArgumentError catch (error) {
      setState(() => _error = '${error.message}');
    }
  }

  @override
  Widget build(BuildContext context) => Form(
    key: _form,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SheetHeading(
          widget.entry == null ? 'Catat Konsumsi' : 'Edit Konsumsi',
          subtitle: 'Catat setiap konsumsi secara jujur untuk hasil terbaik',
        ),
        const FieldLabel('Jenis konsumsi'),
        HabitSelector(
          value: _habit,
          onChanged: (value) => setState(() => _habit = value),
        ),
        const SizedBox(height: 18),
        FieldLabel('Jumlah (${_habit.unit})'),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconButton.filledTonal(
              key: const Key('quantity-minus'),
              tooltip: 'Kurangi jumlah',
              onPressed: (int.tryParse(_amount.text) ?? 0) > 1
                  ? () => setState(
                      () => _amount.text = '${int.parse(_amount.text) - 1}',
                    )
                  : null,
              icon: const Icon(Icons.remove),
              style: IconButton.styleFrom(backgroundColor: CihuyColors.surface),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                key: const Key('consumption-amount'),
                controller: _amount,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(fontSize: 20),
                decoration: InputDecoration(
                  suffixText: _habit.unit,
                  suffixStyle: const TextStyle(
                    fontSize: 13,
                    color: CihuyColors.muted,
                  ),
                ),
                validator: (value) => (int.tryParse(value ?? '') ?? 0) < 1
                    ? 'Isi bilangan bulat ≥ 1'
                    : null,
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              key: const Key('quantity-plus'),
              tooltip: 'Tambah jumlah',
              onPressed: () => setState(
                () => _amount.text = '${(int.tryParse(_amount.text) ?? 0) + 1}',
              ),
              style: IconButton.styleFrom(
                backgroundColor: CihuyColors.paleTeal,
                foregroundColor: CihuyColors.tealInk,
              ),
              icon: const Icon(Icons.add),
            ),
          ],
        ),
        const SizedBox(height: 18),
        DateTimeFields(
          value: _at,
          onChanged: (value) => setState(() {
            _at = value;
            _error = null;
          }),
        ),
        const SizedBox(height: 18),
        const FieldLabel('Catatan', optional: true),
        TextFormField(
          key: const Key('consumption-note'),
          controller: _note,
          scrollPadding: const EdgeInsets.only(bottom: 130),
          minLines: 2,
          maxLines: 4,
          maxLength: 500,
          decoration: const InputDecoration(
            hintText: 'Contoh: Setelah makan, saat stres kerja...',
            counterText: '',
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              _error!,
              style: const TextStyle(color: CihuyColors.red),
            ),
          ),
        const SizedBox(height: 28),
        FilledButton(
          key: const Key('save-consumption'),
          onPressed: _save,
          child: const Text('Simpan catatan'),
        ),
      ],
    ),
  );
}

class CravingForm extends StatefulWidget {
  const CravingForm({super.key, this.entry, required this.initialTime});
  final Craving? entry;
  final DateTime initialTime;
  @override
  State<CravingForm> createState() => _CravingFormState();
}

class _CravingFormState extends State<CravingForm> {
  static const _options = [
    'Stres',
    'Bosan',
    'Setelah makan',
    'Setelah kopi',
    'Sosial',
    'Kelelahan',
  ];
  late Habit _habit;
  late DateTime _at;
  late Intensity _intensity;
  late bool _resisted;
  final Set<String> _triggers = {};
  bool _other = false;
  final _form = GlobalKey<FormState>();
  late final TextEditingController _custom;
  late final TextEditingController _coping;
  String? _error;
  @override
  void initState() {
    super.initState();
    final entry = widget.entry;
    _habit = entry?.habit ?? Habit.cigarette;
    _at = widget.initialTime;
    _intensity = entry?.intensity ?? Intensity.medium;
    _resisted = entry?.resisted ?? true;
    _triggers.addAll(entry?.triggers.where(_options.contains) ?? []);
    final other =
        entry?.triggers
            .where((value) => !_options.contains(value))
            .join(', ') ??
        '';
    _other = other.isNotEmpty;
    _custom = TextEditingController(text: other);
    _coping = TextEditingController(text: entry?.coping ?? '');
  }

  @override
  void dispose() {
    _custom.dispose();
    _coping.dispose();
    super.dispose();
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    try {
      final result = context.read<AppState>().saveCraving(
        id: widget.entry?.id,
        habit: _habit,
        at: _at,
        intensity: _intensity,
        triggers: [..._triggers, if (_other) _custom.text.trim()],
        coping: _coping.text,
        resisted: _resisted,
      );
      Navigator.pop(context, result);
    } on ArgumentError catch (error) {
      setState(() => _error = '${error.message}');
    }
  }

  @override
  Widget build(BuildContext context) => Form(
    key: _form,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SheetHeading(widget.entry == null ? 'Catat Craving' : 'Edit Craving'),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: CihuyColors.paleTeal,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text(
            'Craving adalah dorongan kuat untuk merokok atau menggunakan vape.',
            style: TextStyle(fontSize: 12, color: CihuyColors.tealInk),
          ),
        ),
        const SizedBox(height: 20),
        const FieldLabel('Jenis kebiasaan'),
        HabitSelector(
          value: _habit,
          onChanged: (value) => setState(() => _habit = value),
        ),
        const SizedBox(height: 18),
        DateTimeFields(
          value: _at,
          onChanged: (value) => setState(() {
            _at = value;
            _error = null;
          }),
        ),
        const SizedBox(height: 18),
        const FieldLabel('Intensitas'),
        Row(
          children: [
            for (final intensity in Intensity.values) ...[
              if (intensity.index > 0) const SizedBox(width: 8),
              Expanded(
                child: ChoiceButton(
                  selected: _intensity == intensity,
                  label: intensity.label,
                  activeColor: const Color(0xFFFFF1DA),
                  activeText: const Color(0xFFB85A00),
                  onTap: () => setState(() => _intensity = intensity),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 16),
        const FieldLabel('Pemicu'),
        Wrap(
          spacing: 8,
          runSpacing: 0,
          children: [
            for (final trigger in [..._options, 'Lainnya'])
              FilterChip(
                label: Text(trigger, style: const TextStyle(fontSize: 12)),
                selected: trigger == 'Lainnya'
                    ? _other
                    : _triggers.contains(trigger),
                selectedColor: CihuyColors.paleTeal,
                backgroundColor: Colors.white,
                side: const BorderSide(color: CihuyColors.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(11),
                ),
                onSelected: (selected) => setState(() {
                  if (trigger == 'Lainnya') {
                    _other = selected;
                  } else if (selected) {
                    _triggers.add(trigger);
                  } else {
                    _triggers.remove(trigger);
                  }
                }),
              ),
          ],
        ),
        if (_other)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: TextFormField(
              controller: _custom,
              maxLength: 120,
              decoration: const InputDecoration(
                labelText: 'Pemicu lainnya',
                hintText: 'Ceritakan pemicunya',
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Isi pemicu lainnya'
                  : null,
            ),
          ),
        const SizedBox(height: 16),
        const FieldLabel('Cara mengatasi', optional: true),
        TextFormField(
          key: const Key('craving-coping'),
          controller: _coping,
          scrollPadding: const EdgeInsets.only(bottom: 220),
          minLines: 2,
          maxLines: 4,
          maxLength: 500,
          decoration: const InputDecoration(
            hintText: 'Apa yang kamu lakukan untuk mengatasinya?',
            counterText: '',
          ),
        ),
        const SizedBox(height: 22),
        const FieldLabel('Hasil'),
        Row(
          children: [
            Expanded(
              child: ChoiceButton(
                selected: _resisted,
                label: 'Berhasil ditahan',
                activeColor: CihuyColors.success,
                onTap: () => setState(() => _resisted = true),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ChoiceButton(
                selected: !_resisted,
                label: 'Akhirnya konsumsi',
                activeColor: const Color(0xFFFFF1DA),
                activeText: const Color(0xFFB85A00),
                onTap: () => setState(() => _resisted = false),
              ),
            ),
          ],
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              _error!,
              style: const TextStyle(color: CihuyColors.red),
            ),
          ),
        const SizedBox(height: 24),
        FilledButton(
          key: const Key('save-craving'),
          onPressed: _save,
          child: const Text('Simpan catatan'),
        ),
      ],
    ),
  );
}
