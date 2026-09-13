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
  final _name = TextEditingController(text: 'Pengguna Baru');
  final _form = GlobalKey<FormState>();
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
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
                      'Ini simulasi akun. Gunakan data contoh, bukan kredensial sungguhan. Tidak ada email dikirim atau koneksi ke server.',
                      style: TextStyle(
                        color: CihuyColors.tealInk,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_register) ...[
                    const FieldLabel('Nama untuk demo'),
                    TextFormField(
                      controller: _name,
                      maxLength: 60,
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Isi nama'
                          : null,
                    ),
                    const SizedBox(height: 12),
                  ],
                  const FieldLabel('Email contoh'),
                  TextFormField(
                    initialValue: 'pengguna@contoh.test',
                    readOnly: true,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.mail_outline),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const FieldLabel('Kata sandi contoh'),
                  TextFormField(
                    initialValue: 'contoh123',
                    readOnly: true,
                    obscureText: true,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                  ),
                  if (!_register)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => showDialog<void>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Lupa kata sandi'),
                            content: const Text(
                              'Simulasi pemulihan berhasil. Tidak ada tautan yang dikirim. Kamu bisa langsung masuk menggunakan data contoh.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Mengerti'),
                              ),
                            ],
                          ),
                        ),
                        child: const Text('Lupa kata sandi?'),
                      ),
                    ),
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: () {
                      if (!_form.currentState!.validate()) return;
                      final state = context.read<AppState>();
                      if (_register) {
                        state.startNewUser(name: _name.text.trim());
                      } else {
                        state.signIn();
                      }
                    },
                    child: Text(
                      _register ? 'Daftar akun demo' : 'Masuk ke demo',
                    ),
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: TextButton(
                      onPressed: () => setState(() => _register = !_register),
                      child: Text(
                        _register
                            ? 'Sudah punya akun? Masuk'
                            : 'Buat akun demo',
                      ),
                    ),
                  ),
                  if (!_register)
                    Center(
                      child: TextButton(
                        onPressed: () => context.read<AppState>().startDemo(),
                        child: const Text('Jelajahi demo dengan data terisi'),
                      ),
                    ),
                  const SizedBox(height: 12),
                  const Center(
                    child: Text(
                      'Data demo hilang ketika aplikasi dimulai ulang.',
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

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _form = GlobalKey<FormState>();
  final _reason = TextEditingController(text: 'Saya ingin hidup lebih sehat.');
  final _limit = TextEditingController(text: '5');
  Habit _habit = Habit.cigarette;
  @override
  void dispose() {
    _reason.dispose();
    _limit.dispose();
    super.dispose();
  }

  void _complete(bool target) {
    if (target && !_form.currentState!.validate()) return;
    final state = context.read<AppState>();
    if (target) {
      state.setTarget(
        habit: _habit,
        limit: int.parse(_limit.text),
        startsOn: dayOnly(state.now),
      );
    }
    state.completeOnboarding(_reason.text);
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
                'Mode demo: akun baru dimulai tanpa catatan. Semua data hanya tersimpan selama aplikasi berjalan.',
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
  final _password = TextEditingController(text: 'contoh123');
  final _confirm = TextEditingController(text: 'contoh123');
  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Form(
    key: _form,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SheetHeading(
          'Ubah kata sandi',
          subtitle:
              'Simulasi saja. Gunakan kata sandi contoh, bukan kata sandi asli.',
        ),
        TextFormField(
          controller: _password,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Kata sandi demo baru'),
          validator: (value) => (value?.length ?? 0) < 6
              ? 'Minimal 6 karakter untuk simulasi'
              : null,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _confirm,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Ulangi kata sandi demo',
          ),
          validator: (value) =>
              value != _password.text ? 'Kata sandi belum sama' : null,
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: () {
            if (!_form.currentState!.validate()) return;
            showMessage(
              context,
              'Simulasi berhasil. Tidak ada kata sandi sungguhan yang diubah.',
            );
            Navigator.pop(context);
          },
          child: const Text('Simpan simulasi'),
        ),
      ],
    ),
  );
}
