import 'package:flutter/material.dart';
import 'privacy_screen.dart';
import 'package:provider/provider.dart';
import '../models/records.dart';
import '../providers/app_state.dart';
import '../utils/app_theme.dart';
import '../utils/dates.dart';
import '../widgets/auth_ui.dart';
import '../widgets/common.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _register = false;
  bool _submitting = false;
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
    if (_submitting) return;
    FocusScope.of(context).unfocus();
    if (!_form.currentState!.validate()) return;
    final state = context.read<AppState>();
    setState(() => _submitting = true);
    try {
      if (_register) {
        await state.register(
          name: _name.text,
          email: _email.text,
          password: _password.text,
        );
        if (!mounted || state.recoveryCode == null) return;
        await _showRecoveryCodeDialog(
          context,
          state.recoveryCode!,
          title: 'Kode pemulihan akun',
          description:
              'Simpan kode ini di tempat aman. Kode hanya ditampilkan sekarang dan diperlukan untuk mengatur ulang kata sandi secara offline.',
          actionLabel: 'Saya sudah menyimpannya',
        );
        state.clearRecoveryCode();
      } else {
        await state.authenticate(email: _email.text, password: _password.text);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _changeMode(bool register) {
    if (_register == register) return;
    context.read<AppState>().clearAuthError();
    final email = _email.text;
    final name = _name.text;
    _form.currentState?.reset();
    _email.text = email;
    _name.text = name;
    _password.clear();
    _confirm.clear();
    setState(() => _register = register);
  }

  Future<void> _googleLogin() async {
    final state = context.read<AppState>();
    if (!state.googleConfigured) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 6),
            content: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Login Google belum tersedia pada versi aplikasi ini.',
                ),
                const SizedBox(height: 4),
                Text(
                  'Konfigurasi OAuth belum terbaca. Jalankan ulang dengan '
                  '--dart-define-from-file=supabase.local.json.',
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.4,
                    color: Colors.white.withValues(alpha: .78),
                  ),
                ),
              ],
            ),
          ),
        );
      return;
    }
    FocusScope.of(context).unfocus();
    await state.signInWithGoogle();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final busy = _submitting || state.authLoading || state.googleBusy;
    final viewInsets = MediaQuery.viewInsetsOf(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF4FAFA),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final minHeight = constraints.maxHeight > 48
                ? constraints.maxHeight - 48
                : 0.0;
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                24 + viewInsets.bottom * .15,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: 440,
                    minHeight: minHeight,
                  ),
                  child: AutofillGroup(
                    child: Form(
                      key: _form,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const AppLogo(size: 44),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'CIHUY',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: .2,
                                        color: CihuyColors.ink,
                                      ),
                                    ),
                                    SizedBox(height: 1),
                                    Text(
                                      'Control It, Hold Yourself',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        height: 1.25,
                                        letterSpacing: .2,
                                        color: CihuyColors.muted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 26),
                          AuthModeSwitch(
                            key: const ValueKey('auth-mode'),
                            register: _register,
                            enabled: !busy,
                            onChanged: _changeMode,
                          ),
                          const SizedBox(height: 26),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 180),
                            child: SizedBox(
                              key: ValueKey(_register),
                              width: double.infinity,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _register
                                        ? 'Buat akun CIHUY'
                                        : 'Masuk ke CIHUY',
                                    textAlign: TextAlign.left,
                                    style: const TextStyle(
                                      fontSize: 30,
                                      height: 1.15,
                                      letterSpacing: -.45,
                                      fontWeight: FontWeight.w800,
                                      color: CihuyColors.ink,
                                    ),
                                  ),
                                  const SizedBox(height: 7),
                                  Text(
                                    _register
                                        ? 'Mulai catat progresmu hari ini.'
                                        : 'Lanjutkan catatan dan progresmu.',
                                    textAlign: TextAlign.left,
                                    style: const TextStyle(
                                      fontSize: 13.5,
                                      height: 1.5,
                                      color: CihuyColors.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 22),
                          GoogleSignInButton(
                            onPressed: _googleLogin,
                            loading: state.googleBusy,
                            enabled: !busy,
                          ),
                          const SizedBox(height: 18),
                          const AuthDivider('atau dengan email'),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.shield_outlined,
                                size: 15,
                                color: CihuyColors.muted,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  _register
                                      ? 'Verifikasi email dengan kode OTP setelah mendaftar.'
                                      : 'Masuk menggunakan email yang sudah terverifikasi.',
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    height: 1.4,
                                    color: CihuyColors.muted,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (_register) ...[
                            AuthTextField(
                              label: 'Nama lengkap',
                              fieldKey: const ValueKey('auth-name'),
                              controller: _name,
                              hint: 'Nama yang tampil di profil',
                              enabled: !busy,
                              textCapitalization: TextCapitalization.words,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.name],
                              maxLength: 60,
                              prefixIcon: Icons.person_outline_rounded,
                              validator: (value) =>
                                  value == null || value.trim().isEmpty
                                  ? 'Nama wajib diisi'
                                  : null,
                            ),
                            const SizedBox(height: 14),
                          ],
                          AuthTextField(
                            label: 'Email',
                            fieldKey: const ValueKey('auth-email'),
                            controller: _email,
                            hint: 'nama@email.com',
                            enabled: !busy,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.email],
                            prefixIcon: Icons.mail_outline_rounded,
                            validator: (value) => _validEmail(value)
                                ? null
                                : 'Masukkan email yang valid',
                          ),
                          const SizedBox(height: 14),
                          AuthPasswordField(
                            label: 'Kata sandi',
                            fieldKey: const ValueKey('auth-password'),
                            controller: _password,
                            hint: _register
                                ? 'Buat kata sandi minimal 8 karakter'
                                : 'Masukkan kata sandi',
                            enabled: !busy,
                            textInputAction: _register
                                ? TextInputAction.next
                                : TextInputAction.done,
                            autofillHints: [
                              _register
                                  ? AutofillHints.newPassword
                                  : AutofillHints.password,
                            ],
                            onFieldSubmitted: busy || _register
                                ? null
                                : (_) => _submit(),
                            validator: (value) => (value?.length ?? 0) < 8
                                ? 'Kata sandi minimal 8 karakter'
                                : null,
                          ),
                          if (_register) ...[
                            const SizedBox(height: 14),
                            AuthPasswordField(
                              label: 'Konfirmasi kata sandi',
                              fieldKey: const ValueKey('auth-confirm'),
                              controller: _confirm,
                              hint: 'Ulangi kata sandi',
                              enabled: !busy,
                              autofillHints: const [AutofillHints.newPassword],
                              onFieldSubmitted: busy ? null : (_) => _submit(),
                              validator: (value) => value != _password.text
                                  ? 'Konfirmasi kata sandi belum sama'
                                  : null,
                            ),
                          ],
                          if (state.authError != null) ...[
                            const SizedBox(height: 14),
                            AuthErrorBanner(state.authError!),
                          ],
                          if (!_register)
                            Align(
                              alignment: Alignment.centerRight,
                              child: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: TextButton(
                                  onPressed: busy
                                      ? null
                                      : () => _showRecovery(context),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 6,
                                    ),
                                    minimumSize: const Size(0, 32),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: const Text('Lupa kata sandi?'),
                                ),
                              ),
                            ),
                          const SizedBox(height: 16),
                          AuthPrimaryButton(
                            buttonKey: const ValueKey('auth-submit'),
                            label: _register ? 'Daftar akun' : 'Masuk',
                            loading: state.authLoading || _submitting,
                            onPressed: _submit,
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const PrivacyScreen(),
                              ),
                            ),
                            child: const Text('Privasi dan data'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
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
    if (_loading) return;
    FocusScope.of(context).unfocus();
    if (!_form.currentState!.validate()) return;
    setState(() => _loading = true);
    await _state.resetPassword(
      email: _email.text,
      code: _code.text,
      password: _password.text,
    );
    if (!mounted) return;
    if (_error == null) Navigator.pop(context);
  }

  Widget _actions() => LayoutBuilder(
    builder: (context, constraints) {
      final compact =
          constraints.maxWidth < 300 ||
          MediaQuery.textScalerOf(context).scale(1) > 1.25;
      final cancel = OutlinedButton(
        key: const ValueKey('recovery-cancel'),
        onPressed: _loading ? null : () => Navigator.pop(context),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          foregroundColor: CihuyColors.ink,
          side: const BorderSide(color: CihuyColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        child: const Text('Batal'),
      );
      final reset = AuthPrimaryButton(
        key: const ValueKey('recovery-submit'),
        buttonKey: const ValueKey('recovery-submit-button'),
        label: 'Atur ulang',
        loading: _loading,
        onPressed: _submit,
      );
      if (compact) {
        return Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [reset, const SizedBox(height: 10), cancel],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Expanded(child: cancel),
          const SizedBox(width: 12),
          Expanded(flex: 2, child: reset),
        ],
      );
    },
  );

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_loading,
    child: AuthDialogShell(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthDialogHeading(
            title: 'Pulihkan kata sandi',
            description:
                'Masukkan email, kode pemulihan yang disimpan saat registrasi, dan kata sandi baru.',
            icon: Icons.lock_reset_rounded,
            onClose: () => Navigator.pop(context),
            closeEnabled: !_loading,
          ),
          const SizedBox(height: 20),
          AutofillGroup(
            child: Form(
              key: _form,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AuthTextField(
                    label: 'Email',
                    fieldKey: const ValueKey('recovery-email'),
                    controller: _email,
                    hint: 'nama@email.com',
                    enabled: !_loading,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.email],
                    prefixIcon: Icons.mail_outline_rounded,
                    validator: (value) =>
                        _validEmail(value) ? null : 'Email tidak valid',
                  ),
                  const SizedBox(height: 14),
                  AuthTextField(
                    label: 'Kode pemulihan',
                    fieldKey: const ValueKey('recovery-code'),
                    controller: _code,
                    hint: 'Kode yang disimpan saat registrasi',
                    enabled: !_loading,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    prefixIcon: Icons.key_outlined,
                    validator: (value) => (value?.trim().isEmpty ?? true)
                        ? 'Kode pemulihan wajib diisi'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  AuthPasswordField(
                    label: 'Kata sandi baru',
                    fieldKey: const ValueKey('recovery-password'),
                    controller: _password,
                    hint: 'Minimal 8 karakter',
                    enabled: !_loading,
                    autofillHints: const [AutofillHints.newPassword],
                    onFieldSubmitted: _loading ? null : (_) => _submit(),
                    validator: (value) => (value?.length ?? 0) < 8
                        ? 'Kata sandi minimal 8 karakter'
                        : null,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    AuthErrorBanner(_error!),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          _actions(),
        ],
      ),
    ),
  );
}

Future<void> _showRecovery(BuildContext context) async {
  final state = context.read<AppState>();
  if (!state.localAuthEnabled) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Pemulihan kata sandi melalui email belum tersedia pada versi ini.',
        ),
      ),
    );
    return;
  }
  // Bersihkan sisa galat sebelum dialog agar pesan lama tidak menempel
  // di form login di belakangnya.
  state.clearAuthError();
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => _RecoveryDialog(state: state),
  );
  if (!context.mounted) return;
  if (state.recoveryCode != null && state.authError == null) {
    await _showRecoveryCodeDialog(
      context,
      state.recoveryCode!,
      title: 'Kode pemulihan baru',
      description:
          'Kode lama sudah tidak berlaku. Simpan kode baru ini untuk pemulihan berikutnya.',
      actionLabel: 'Selesai',
    );
  }
  if (!context.mounted) return;
  // Galat dari percobaan gagal di dalam dialog tidak boleh ikut tampil
  // di form login setelah dialog ditutup.
  context.read<AppState>()
    ..clearRecoveryCode()
    ..clearAuthError();
}

Future<void> _showRecoveryCodeDialog(
  BuildContext context,
  String code, {
  required String title,
  required String description,
  required String actionLabel,
}) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (dialogContext) => AuthDialogShell(
    maxWidth: 400,
    child: Column(
      mainAxisAlignment: MainAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AuthDialogHeading(
          title: title,
          description: description,
          icon: Icons.key_rounded,
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
          decoration: BoxDecoration(
            color: CihuyColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: CihuyColors.border),
          ),
          child: SelectableText(
            code,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 22,
              letterSpacing: 2.4,
              height: 1.3,
              fontWeight: FontWeight.w700,
              color: CihuyColors.tealInk,
            ),
          ),
        ),
        const SizedBox(height: 20),
        AuthPrimaryButton(
          label: actionLabel,
          onPressed: () => Navigator.pop(dialogContext),
        ),
      ],
    ),
  ),
);

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
  bool _saving = false;
  String? _saveError;
  @override
  void dispose() {
    _reason.dispose();
    _limit.dispose();
    _baseline.dispose();
    super.dispose();
  }

  Future<void> _complete(bool target) async {
    if (_saving) return;
    if (target && !_form.currentState!.validate()) return;
    final state = context.read<AppState>();
    final baselineValue = int.tryParse(_baseline.text);
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      await state.completeOnboarding(
        _reason.text,
        baselineHabit: Habit.cigarette,
        baselineValue: baselineValue,
      );
      if (target && state.signedIn) {
        state.setTarget(
          habit: Habit.cigarette,
          limit: int.parse(_limit.text),
          startsOn: dayOnly(state.now),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _saveError =
              'Pengaturan belum tersimpan. Periksa koneksi dan coba lagi.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
            mainAxisAlignment: MainAxisAlignment.start,
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
              const FieldLabel('Rata-rata konsumsi awal', optional: true),
              TextFormField(
                controller: _baseline,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  suffixText: 'batang/hari',
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
                decoration: const InputDecoration(
                  suffixText: 'batang/hari',
                  helperText: '0 untuk berhenti sepenuhnya.',
                ),
                validator: (value) => (int.tryParse(value ?? '') ?? -1) < 0
                    ? 'Isi bilangan bulat 0 atau lebih'
                    : null,
              ),
              const SizedBox(height: 24),
              if (_saveError != null)
                Text(
                  _saveError!,
                  style: const TextStyle(color: CihuyColors.red),
                ),
              FilledButton(
                onPressed: _saving ? null : () => _complete(true),
                child: Text(_saving ? 'Menyimpan...' : 'Simpan & mulai'),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: _saving ? null : () => _complete(false),
                  child: const Text('Mulai tanpa target dulu'),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Catatan konsumsi, craving, dan target masih tersimpan selama sesi aplikasi. Profil akun tersimpan di Supabase.',
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
        mainAxisAlignment: MainAxisAlignment.start,
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
