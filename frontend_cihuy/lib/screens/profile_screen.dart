import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/records.dart';
import '../providers/app_state.dart';
import '../services/unit_settings.dart';
import '../utils/app_theme.dart';
import '../utils/dates.dart';
import '../widgets/asset_icon.dart';
import '../widgets/common.dart';
import '../widgets/profile_avatar.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final profile = state.profile;
    return ColoredBox(
      color: CihuyColors.surface,
      child: ListView(
        key: const PageStorageKey('profile-scroll'),
        padding: EdgeInsets.zero,
        children: [
          Container(
            clipBehavior: Clip.hardEdge,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF29BCBB), Color(0xFF54D2CD)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Stack(
              children: [
                Positioned(right: -50, top: -70, child: _circle(160)),
                Positioned(left: -50, bottom: -45, child: _circle(120)),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Profil',
                        style: TextStyle(
                          fontSize: 20,
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 23),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const ProfileAvatar(),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  profile.name,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  profile.email,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Mulai berhenti sejak ${shortDate(profile.startedAt)}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.white.withValues(alpha: .9),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (state.photoError != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Semantics(
                            liveRegion: true,
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                state.photoError!,
                                style: const TextStyle(
                                  color: CihuyColors.red,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: _ProfileStat(
                              '${state.progress.successfulDays(state.now)}',
                              'Hari berhasil',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _ProfileStat(
                              '${state.cravings.where((entry) => entry.resisted).length}',
                              'Craving ditahan',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _ProfileStat(
                              '${state.recordCount}',
                              'Total catatan',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _GroupLabel('INFORMASI AKUN'),
                SurfaceCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _InfoRow(
                        icon: const CihuyAssetIcon(CihuyAssetIcon.profile),
                        label: 'Nama',
                        value: profile.name,
                        onEdit: () => openSheet(
                          context,
                          const _EditProfileForm(isName: true),
                        ),
                      ),
                      const Divider(),
                      _InfoRow(
                        icon: const Icon(Icons.mail_outline),
                        label: 'Email',
                        value: profile.email,
                      ),
                      const Divider(),
                      _InfoRow(
                        icon: const CihuyAssetIcon(CihuyAssetIcon.profile),
                        label: 'Alasan berhenti',
                        value: profile.reason,
                        onEdit: () => openSheet(
                          context,
                          const _EditProfileForm(isName: false),
                        ),
                      ),
                      for (final habit in Habit.tracked) ...[
                        const Divider(),
                        _InfoRow(
                          icon: habitIcon(habit),
                          label: 'Rata-rata awal (${habit.label})',
                          value: state.baseline(habit) == null
                              ? 'Belum diisi'
                              : '${state.baseline(habit)} ${habit.unit}/hari',
                          onEdit: () =>
                              openSheet(context, _BaselineForm(habit: habit)),
                        ),
                      ],
                      const Divider(),
                      _InfoRow(
                        icon: const Icon(Icons.inventory_2_outlined),
                        label: 'Isi per bungkus',
                        value: '${state.sticksPerPack} batang',
                        onEdit: () => openSheet(context, const _PackSizeForm()),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const _GroupLabel('LAINNYA'),
                SurfaceCard(
                  padding: EdgeInsets.zero,
                  child: ListTile(
                    leading: const IconTile(Icons.settings_outlined),
                    title: const Text(
                      'Pengaturan',
                      style: TextStyle(fontSize: 13),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: CihuyColors.muted,
                    ),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const SettingsScreen(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                if (state.usesCloudAuth)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Text(
                      'Profil tersimpan di Supabase. Sinkronisasi catatan konsumsi, craving, target, dan foto belum tersedia.',
                      style: TextStyle(fontSize: 12, color: CihuyColors.muted),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _circle(double size) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white.withValues(alpha: .10),
    ),
  );
}

class _ProfileStat extends StatelessWidget {
  const _ProfileStat(this.value, this.label);
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 3),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .18),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 21,
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 11, color: Colors.white),
        ),
      ],
    ),
  );
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        color: CihuyColors.muted,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.onEdit,
  });
  final Widget icon;
  final String label;
  final String value;
  final VoidCallback? onEdit;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 13, 12, 13),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconTile.child(icon),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontSize: 12,
                        color: CihuyColors.muted,
                      ),
                    ),
                  ),
                  if (onEdit != null)
                    InkWell(
                      onTap: onEdit,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        child: Text(
                          'Edit',
                          semanticsLabel: 'Edit $label',
                          style: const TextStyle(
                            fontSize: 12,
                            color: CihuyColors.tealInk,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              Text(value, style: const TextStyle(fontSize: 13, height: 1.65)),
            ],
          ),
        ),
      ],
    ),
  );
}

class _EditProfileForm extends StatefulWidget {
  const _EditProfileForm({required this.isName});
  final bool isName;
  @override
  State<_EditProfileForm> createState() => _EditProfileFormState();
}

class _EditProfileFormState extends State<_EditProfileForm> {
  bool _saving = false;
  String? _error;
  final _form = GlobalKey<FormState>();
  late final TextEditingController _text;
  @override
  void initState() {
    super.initState();
    final profile = context.read<AppState>().profile;
    _text = TextEditingController(
      text: widget.isName ? profile.name : profile.reason,
    );
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Form(
    key: _form,
    child: Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SheetHeading(widget.isName ? 'Edit nama' : 'Edit alasan berhenti'),
        TextFormField(
          controller: _text,
          maxLines: widget.isName ? 1 : 4,
          maxLength: widget.isName ? 60 : 500,
          autofocus: true,
          decoration: InputDecoration(
            labelText: widget.isName ? 'Nama' : 'Alasan berhenti',
          ),
          validator: (value) => value == null || value.trim().isEmpty
              ? 'Isian tidak boleh kosong'
              : null,
        ),
        const SizedBox(height: 20),
        if (_error != null)
          Text(_error!, style: const TextStyle(color: CihuyColors.red)),
        FilledButton(
          onPressed: _saving
              ? null
              : () async {
                  if (!_form.currentState!.validate()) return;
                  setState(() {
                    _saving = true;
                    _error = null;
                  });
                  try {
                    await context.read<AppState>().updateProfile(
                      name: widget.isName ? _text.text : null,
                      reason: widget.isName ? null : _text.text,
                    );
                    if (context.mounted) Navigator.pop(context);
                  } catch (_) {
                    if (mounted) {
                      setState(
                        () => _error = 'Perubahan belum tersimpan. Coba lagi.',
                      );
                    }
                  } finally {
                    if (mounted) setState(() => _saving = false);
                  }
                },
          child: const Text('Simpan perubahan'),
        ),
      ],
    ),
  );
}

class _BaselineForm extends StatefulWidget {
  const _BaselineForm({required this.habit});
  final Habit habit;
  @override
  State<_BaselineForm> createState() => _BaselineFormState();
}

class _BaselineFormState extends State<_BaselineForm> {
  bool _saving = false;
  String? _error;
  final _form = GlobalKey<FormState>();
  late final TextEditingController _text;
  @override
  void initState() {
    super.initState();
    final value = context.read<AppState>().baseline(widget.habit);
    _text = TextEditingController(text: value == null ? '' : '$value');
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Form(
    key: _form,
    child: Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SheetHeading(
          'Rata-rata awal (${widget.habit.label})',
          subtitle:
              'Baseline adalah taksiran konsumsi sebelum berhenti. '
              'Berbeda dari target harian dan tidak mengubah catatan historis.',
        ),
        TextFormField(
          controller: _text,
          autofocus: true,
          keyboardType: TextInputType.number,
          maxLength: 4,
          decoration: InputDecoration(
            labelText: 'Rata-rata per hari sebelum mulai berhenti',
            suffixText: widget.habit.unit,
          ),
          validator: (value) {
            final parsed = int.tryParse(value ?? '');
            if (parsed == null || parsed < 0) {
              return 'Isi bilangan bulat 0 atau lebih';
            }
            return null;
          },
        ),
        const SizedBox(height: 20),
        if (_error != null)
          Text(_error!, style: const TextStyle(color: CihuyColors.red)),
        FilledButton(
          onPressed: _saving
              ? null
              : () async {
                  if (!_form.currentState!.validate()) return;
                  setState(() {
                    _saving = true;
                    _error = null;
                  });
                  try {
                    await context.read<AppState>().updateBaseline(
                      widget.habit,
                      int.parse(_text.text),
                    );
                    if (context.mounted) Navigator.pop(context);
                  } catch (_) {
                    if (mounted) {
                      setState(
                        () => _error = 'Baseline belum tersimpan. Coba lagi.',
                      );
                    }
                  } finally {
                    if (mounted) setState(() => _saving = false);
                  }
                },
          child: const Text('Simpan baseline'),
        ),
      ],
    ),
  );
}

class _PackSizeForm extends StatefulWidget {
  const _PackSizeForm();
  @override
  State<_PackSizeForm> createState() => _PackSizeFormState();
}

class _PackSizeFormState extends State<_PackSizeForm> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _text;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _text = TextEditingController(
      text: '${context.read<AppState>().sticksPerPack}',
    );
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await context.read<AppState>().setSticksPerPack(int.parse(_text.text));
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Isi per bungkus belum tersimpan. Coba lagi.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Form(
    key: _form,
    child: Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SheetHeading(
          'Isi per bungkus',
          subtitle:
              'Dipakai saat mencatat konsumsi dalam satuan bungkus. Semua '
              'catatan tetap disimpan dalam batang.',
        ),
        Wrap(
          spacing: 8,
          children: [
            for (final preset in UnitSettings.presets)
              ChoiceChip(
                label: Text('$preset batang'),
                selected: _text.text == '$preset',
                onSelected: (_) => setState(() => _text.text = '$preset'),
              ),
          ],
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _text,
          keyboardType: TextInputType.number,
          maxLength: 2,
          decoration: const InputDecoration(
            labelText: 'Batang per bungkus',
            suffixText: 'batang',
            counterText: '',
          ),
          onChanged: (_) => setState(() {}),
          validator: (value) {
            final parsed = int.tryParse(value ?? '');
            if (parsed == null || parsed < 1) return 'Isi minimal 1 batang';
            return null;
          },
        ),
        const SizedBox(height: 20),
        if (_error != null)
          Text(_error!, style: const TextStyle(color: CihuyColors.red)),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: const Text('Simpan'),
        ),
      ],
    ),
  );
}
