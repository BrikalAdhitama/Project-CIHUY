import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../utils/app_theme.dart';
import '../widgets/auth_ui.dart';
import '../widgets/common.dart';

class SignupOtpScreen extends StatefulWidget {
  const SignupOtpScreen({super.key});

  @override
  State<SignupOtpScreen> createState() => _SignupOtpScreenState();
}

class _SignupOtpScreenState extends State<SignupOtpScreen> {
  final _code = TextEditingController();
  final _form = GlobalKey<FormState>();
  Timer? _timer;
  String? _notice;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final state = context.read<AppState>();
    if (state.authLoading || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _notice = null);
    await state.verifySignup(_code.text);
  }

  Future<void> _resend() async {
    final state = context.read<AppState>();
    if (state.authLoading || state.resendSeconds > 0) return;
    setState(() => _notice = null);
    await state.resendSignup();
    if (!mounted || state.authError != null) return;
    _code.clear();
    setState(
      () => _notice =
          'Permintaan terkirim. Periksa inbox dan folder spam untuk kode terbaru.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final busy = state.authLoading || state.googleBusy;
    final seconds = state.resendSeconds;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !busy) state.cancelSignup();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF4FAFA),
        appBar: AppBar(
          backgroundColor: const Color(0xFFF4FAFA),
          title: const Text('Verifikasi email'),
          leading: IconButton(
            tooltip: 'Kembali ke login',
            onPressed: busy ? null : state.cancelSignup,
            icon: const Icon(Icons.arrow_back),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: AutofillGroup(
                  child: Form(
                    key: _form,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 24),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: AppLogo(size: 56),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Cek emailmu',
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            color: CihuyColors.ink,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Masukkan kode 6 digit untuk memverifikasi ${state.pendingSignupEmail ?? "emailmu"}.',
                          style: const TextStyle(fontSize: 15, height: 1.6),
                        ),
                        const SizedBox(height: 24),
                        TextFormField(
                          key: const ValueKey('signup-otp'),
                          controller: _code,
                          enabled: !busy,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.done,
                          autofillHints: const [AutofillHints.oneTimeCode],
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(6),
                          ],
                          maxLength: 6,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 28,
                            letterSpacing: 8,
                            fontWeight: FontWeight.w700,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Kode OTP',
                            hintText: '000000',
                            counterText: '',
                          ),
                          validator: (value) =>
                              RegExp(r'^\d{6}$').hasMatch(value ?? '')
                              ? null
                              : 'Masukkan kode OTP 6 digit',
                          onFieldSubmitted: busy ? null : (_) => _verify(),
                        ),
                        if (state.authError != null) ...[
                          const SizedBox(height: 16),
                          AuthErrorBanner(state.authError!),
                        ],
                        if (_notice != null) ...[
                          const SizedBox(height: 16),
                          Text(
                            _notice!,
                            style: const TextStyle(color: CihuyColors.tealInk),
                          ),
                        ],
                        const SizedBox(height: 24),
                        AuthPrimaryButton(
                          buttonKey: const ValueKey('signup-verify'),
                          label: 'Verifikasi email',
                          loading: busy,
                          onPressed: _verify,
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          key: const ValueKey('signup-resend'),
                          onPressed: busy || seconds > 0 ? null : _resend,
                          child: Text(
                            seconds > 0
                                ? 'Kirim ulang dalam ${seconds}s'
                                : 'Kirim ulang kode',
                          ),
                        ),
                        TextButton(
                          onPressed: busy ? null : state.cancelSignup,
                          child: const Text('Ganti email / kembali ke login'),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Belum menerima email? Periksa folder spam. Jika sudah memiliki akun terverifikasi, kembali ke halaman login.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.6,
                            color: CihuyColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
