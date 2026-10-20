import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/records.dart';
import '../providers/app_state.dart';
import '../utils/app_theme.dart';
import '../utils/dates.dart';
import '../widgets/common.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _register = false;
  bool _obscurePassword = true;
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _form = GlobalKey<FormState>();
  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final state = context.read<AppState>();
    if (_register) {
      await state.register(
        name: _name.text,
        email: _email.text,
        password: _password.text,
      );
      if (!mounted || state.recoveryCode == null) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Kode pemulihan akun'),
          content: Text(
            'Simpan kode ini di tempat aman. Kode hanya ditampilkan sekarang dan diperlukan untuk mengatur ulang kata sandi secara offline.\n\n${state.recoveryCode}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Saya sudah menyimpannya'),
            ),
          ],
        ),
      );
      state.clearRecoveryCode();
    } else {
      await state.authenticate(email: _email.text, password: _password.text);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(26),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppLogo(),
                  const SizedBox(height: 20),
                  const Text(
                    'CIHUY',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      color: CihuyColors.tealInk,
                    ),
                  ),
                  const Text(
                    'Control It, Hold Yourself',
                    style: TextStyle(color: CihuyColors.muted),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    _register
                        ? 'Mulai langkah pertamamu'
                        : 'Selamat datang kembali',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: CihuyColors.paleTeal,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Akun disimpan hanya di perangkat ini. Tidak ada email, server, atau koneksi eksternal yang digunakan.',
                      style: TextStyle(
                        color: CihuyColors.tealInk,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_register) ...[
                    const FieldLabel('Nama lengkap'),
                    TextFormField(
                      controller: _name,
                      maxLength: 60,
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Nama wajib diisi'
                          : null,
                    ),
                    const SizedBox(height: 12),
                  ],
                  const FieldLabel('Email'),
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) =>
                        _validEmail(value) ? null : 'Masukkan email yang valid',
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.mail_outline),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const FieldLabel('Kata sandi'),
                  TextFormField(
                    controller: _password,
                    obscureText: _obscurePassword,
                    validator: (value) => (value?.length ?? 0) < 8
                        ? 'Kata sandi minimal 8 karakter'
                        : null,
                    decoration: InputDecoration(
                      prefixIcon: Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.visibility_outlined),
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                      ),
                    ),
                  ),
                  if (_register) ...[
                    const SizedBox(height: 16),
                    const FieldLabel('Konfirmasi kata sandi'),
                    TextFormField(
                      controller: _confirm,
                      obscureText: _obscurePassword,
                      validator: (value) => value != _password.text
                          ? 'Konfirmasi kata sandi belum sama'
                          : null,
                      decoration: InputDecoration(
                        prefixIcon: Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.visibility_outlined),
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (context.watch<AppState>().authError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        context.watch<AppState>().authError!,
                        style: const TextStyle(color: CihuyColors.red),
                      ),
                    ),
                  if (!_register)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => _showRecovery(context),
                        child: const Text('Lupa kata sandi?'),
                      ),
                    ),
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: context.watch<AppState>().authLoading
                        ? null
                        : _submit,
                    child: Text(
                      context.watch<AppState>().authLoading
                          ? 'Memproses...'
                          : _register
                          ? 'Daftar akun'
                          : 'Masuk',
                    ),
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: TextButton(
                      onPressed: () {
                      // Pesan galat tidak boleh menggantung saat pindah mode.
                      context.read<AppState>().clearAuthError();
                      setState(() => _register = !_register);
                    },
                      child: Text(
                        _register ? 'Sudah punya akun? Masuk' : 'Buat akun',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Center(
                    child: Text(
                      'Akun dan sesi tersimpan lokal di perangkat ini. Catatan tracking tersimpan selama aplikasi berjalan.',
                      style: TextStyle(fontSize: 11, color: CihuyColors.muted),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

bool _validEmail(String? value) =>
    RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value?.trim() ?? '');

/// Dialog pemulihan memantau AppState lewat listener lokal, bukan [watch],
/// agar dependensi inherited di dalam modal tidak ikut ter-tardown saat
/// dialog ditutup (mencegah assertion `_dependents.isEmpty`).
class _RecoveryDialog extends StatefulWidget {
  const _RecoveryDialog({required this.state});
  final AppState state;
  @override
  State<_RecoveryDialog> createState() => _RecoveryDialogState();
}

class _RecoveryDialogState extends State<_RecoveryDialog> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  late final AppState _state = widget.state;
  bool _loading = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _error = _state.authError;
    _loading = _state.authLoading;
    _state.addListener(_onStateChanged);
  }

  void _onStateChanged() {
    if (!mounted) return;
    setState(() {
      _loading = _state.authLoading;
      _error = _state.authError;
    });
  }

  @override
  void dispose() {
    _state.removeListener(_onStateChanged);
    _email.dispose();
    _code.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    await _state.resetPassword(
      email: _email.text,
      code: _code.text,
      password: _password.text,
    );
    if (!mounted) return;
    if (_error == null) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Pulihkan kata sandi'),
    content: Form(
      key: _form,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Masukkan email, kode pemulihan yang disimpan saat registrasi, dan kata sandi baru.',
            ),
            TextFormField(
              controller: _email,
              decoration: const InputDecoration(labelText: 'Email'),
              validator: (value) =>
                  _validEmail(value) ? null : 'Email tidak valid',
            ),
            TextFormField(
              controller: _code,
              decoration: const InputDecoration(labelText: 'Kode pemulihan'),
              keyboardType: TextInputType.number,
            ),
            TextFormField(
              controller: _password,
              decoration: const InputDecoration(labelText: 'Kata sandi baru'),
              obscureText: true,
              validator: (value) =>
                  (value?.length ?? 0) < 8 ? 'Minimal 8 karakter' : null,
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  _error!,
                  style: const TextStyle(color: CihuyColors.red),
                ),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Batal'),
      ),
      FilledButton(
        onPressed: _loading ? null : _submit,
        child: Text(_loading ? 'Memproses...' : 'Atur ulang'),
      ),
    ],
  );
}

Future<void> _showRecovery(BuildContext context) async {
  final state = context.read<AppState>();
  // Bersihkan sisa galat sebelum dialog agar pesan lama tidak menempel
  // di form login di belakangnya.
  state.clearAuthError();
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => _RecoveryDialog(state: state),
  );
  if (!context.mounted) return;
  final state2 = state; // sudah di-cache sebelum dialog.
  if (state2.recoveryCode != null && state2.authError == null) {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kode pemulihan baru'),
        content: Text(
          'Kode lama sudah tidak berlaku. Simpan kode baru ini:\n\n${state2.recoveryCode}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Selesai'),
          ),
        ],
      ),
    );
  }
  if (!context.mounted) return;
  // Galat dari percobaan gagal di dalam dialog tidak boleh ikut tampil
  // di form login setelah dialog ditutup.
  context.read<AppState>()
    ..clearRecoveryCode()
    ..clearAuthError();
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _form = GlobalKey<FormState>();
  final _reason = TextEditingController(text: 'Saya ingin hidup lebih sehat.');
  final _limit = TextEditingController(text: '5');
  final _baseline = TextEditingController();
  Habit _habit = Habit.cigarette;
  @override
  void dispose() {
    _reason.dispose();
    _limit.dispose();
    _baseline.dispose();
    super.dispose();
  }

  void _complete(bool target) {
    if (target && !_form.currentState!.validate()) return;
    final state = context.read<AppState>();
    final baselineValue = int.tryParse(_baseline.text);
    if (target) {
      state.setTarget(
        habit: _habit,
        limit: int.parse(_limit.text),
        startsOn: dayOnly(state.now),
      );
    }
    state.completeOnboarding(
      _reason.text,
      baselineHabit: _habit,
      baselineValue: baselineValue,
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Selamat datang di CIHUY')),
    body: SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppLogo(size: 60),
              const SizedBox(height: 20),
              const Text(
                'Mulai dari alasanmu.',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text(
                'Perjalanan ini milikmu. Catat dengan jujur dan tentukan target harian yang ingin kamu jalani.',
                style: TextStyle(color: CihuyColors.muted),
              ),
              const SizedBox(height: 24),
              const FieldLabel('Alasan ingin berhenti'),
              TextFormField(controller: _reason, maxLines: 3, maxLength: 500),
              const SizedBox(height: 16),
              const FieldLabel('Jenis kebiasaan'),
              HabitSelector(
                value: _habit,
                onChanged: (habit) => setState(() => _habit = habit),
              ),
              const SizedBox(height: 16),
              const FieldLabel('Rata-rata konsumsi awal', optional: true),
              TextFormField(
                controller: _baseline,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  suffixText: '${_habit.unit}/hari',
                  helperText:
                      'Berapa banyak yang biasanya kamu konsumsi per hari sebelum mulai berhenti?',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return null;
                  final parsed = int.tryParse(value);
                  if (parsed == null || parsed < 0) {
                    return 'Isi bilangan bulat 0 atau lebih';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              const FieldLabel('Target pertama'),
              TextFormField(
                controller: _limit,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  suffixText: '${_habit.unit}/hari',
                  helperText: '0 untuk berhenti sepenuhnya.',
                ),
                validator: (value) => (int.tryParse(value ?? '') ?? -1) < 0
                    ? 'Isi bilangan bulat 0 atau lebih'
                    : null,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => _complete(true),
                child: const Text('Simpan & mulai'),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: () => _complete(false),
                  child: const Text('Mulai tanpa target dulu'),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Akun baru dimulai tanpa catatan. Semua data hanya tersimpan selama aplikasi berjalan.',
                style: TextStyle(fontSize: 12, color: CihuyColors.muted),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class PasswordForm extends StatefulWidget {
  const PasswordForm({super.key});
  @override
  State<PasswordForm> createState() => _PasswordFormState();
}

class _PasswordFormState extends State<PasswordForm> {
  final _form = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;
  late final AppState _state;

  @override
  void initState() {
    super.initState();
    // Pantau AppState lewat listener lokal, bukan [watch], agar subtree sheet
    // tidak lagi bergantung pada inherited provider saat route menutup
    // (mencegah assertion `_dependents.isEmpty`).
    _state = context.read<AppState>();
    _error = _state.authError;
    _loading = _state.authLoading;
    _state.addListener(_onStateChanged);
  }

  void _onStateChanged() {
    if (!mounted) return;
    setState(() {
      _loading = _state.authLoading;
      _error = _state.authError;
    });
  }

  @override
  void dispose() {
    _state.removeListener(_onStateChanged);
    _current.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    // Tangkap messenger sebelum menunggu agar tidak menambah dependensi
    // context setelah proses asinkron selesai.
    final messenger = ScaffoldMessenger.of(context);
    final success = await _state.changePassword(
      currentPassword: _current.text,
      newPassword: _password.text,
    );
    if (!mounted) return;
    if (success) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Kata sandi berhasil diubah.')),
        );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SheetHeading(
            'Ubah kata sandi',
            subtitle:
                'Gunakan kata sandi yang saat ini aktif untuk membuat yang baru.',
          ),
          const FieldLabel('Kata sandi saat ini'),
          TextFormField(
            controller: _current,
            obscureText: _obscure,
            autofocus: true,
            validator: (value) =>
                value == null || value.isEmpty ? 'Wajib diisi' : null,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const FieldLabel('Kata sandi baru'),
          TextFormField(
            controller: _password,
            obscureText: _obscure,
            validator: (value) => (value?.length ?? 0) < 8
                ? 'Kata sandi minimal 8 karakter'
                : null,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.lock_outline),
            ),
          ),
          const SizedBox(height: 16),
          const FieldLabel('Ulangi kata sandi baru'),
          TextFormField(
            controller: _confirm,
            obscureText: _obscure,
            validator: (value) =>
                value != _password.text ? 'Kata sandi belum sama' : null,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.lock_outline),
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
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _loading ? null : _submit,
            child: Text(_loading ? 'Menyimpan...' : 'Simpan kata sandi'),
          ),
        ],
      ),
    );
  }
}
