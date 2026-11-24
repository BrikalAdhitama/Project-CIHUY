import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../utils/app_theme.dart';
import 'common.dart';

/// Segmented control Masuk/Daftar yang mengikuti bahasa visual CIHUY.
class AuthModeSwitch extends StatelessWidget {
  const AuthModeSwitch({
    super.key,
    required this.register,
    required this.onChanged,
    this.enabled = true,
  });

  final bool register;
  final ValueChanged<bool> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: CihuyColors.border),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: _AuthModeSegment(
            label: 'Masuk',
            selected: !register,
            enabled: enabled,
            onTap: () => onChanged(false),
          ),
        ),
        Expanded(
          child: _AuthModeSegment(
            label: 'Daftar',
            selected: register,
            enabled: enabled,
            onTap: () => onChanged(true),
          ),
        ),
      ],
    ),
  );
}

class _AuthModeSegment extends StatelessWidget {
  const _AuthModeSegment({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    child: InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? CihuyColors.tealInk : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected
                ? Colors.white
                : CihuyColors.muted.withValues(alpha: enabled ? 1 : .5),
          ),
        ),
      ),
    ),
  );
}

/// Input teks standar untuk seluruh layar autentikasi.
class AuthTextField extends StatelessWidget {
  const AuthTextField({
    super.key,
    required this.label,
    required this.controller,
    this.fieldKey,
    this.hint,
    this.validator,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.autofillHints,
    this.enabled = true,
    this.maxLength,
    this.prefixIcon,
    this.onFieldSubmitted,
    this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final Key? fieldKey;
  final String? hint;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final Iterable<String>? autofillHints;
  final bool enabled;
  final int? maxLength;
  final IconData? prefixIcon;
  final ValueChanged<String>? onFieldSubmitted;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisAlignment: MainAxisAlignment.start,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      FieldLabel(label),
      TextFormField(
        key: fieldKey,
        controller: controller,
        enabled: enabled,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        textCapitalization: textCapitalization,
        autofillHints: autofillHints,
        autocorrect: keyboardType != TextInputType.emailAddress,
        enableSuggestions: keyboardType != TextInputType.emailAddress,
        maxLength: maxLength,
        onFieldSubmitted: onFieldSubmitted,
        onChanged: onChanged,
        validator: validator,
        style: const TextStyle(fontSize: 14.5, color: CihuyColors.ink),
        decoration: InputDecoration(
          hintText: hint,
          counterText: maxLength == null ? null : '',
          prefixIcon: prefixIcon == null
              ? null
              : Icon(prefixIcon, size: 20, color: CihuyColors.muted),
        ),
      ),
    ],
  );
}

/// Input kata sandi dengan tombol tampil/sembunyi sendiri.
class AuthPasswordField extends StatefulWidget {
  const AuthPasswordField({
    super.key,
    required this.label,
    required this.controller,
    this.fieldKey,
    this.hint = 'Minimal 8 karakter',
    this.validator,
    this.textInputAction = TextInputAction.done,
    this.autofillHints,
    this.enabled = true,
    this.onFieldSubmitted,
  });

  final String label;
  final TextEditingController controller;
  final Key? fieldKey;
  final String hint;
  final String? Function(String?)? validator;
  final TextInputAction textInputAction;
  final Iterable<String>? autofillHints;
  final bool enabled;
  final ValueChanged<String>? onFieldSubmitted;

  @override
  State<AuthPasswordField> createState() => _AuthPasswordFieldState();
}

class _AuthPasswordFieldState extends State<AuthPasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisAlignment: MainAxisAlignment.start,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      FieldLabel(widget.label),
      TextFormField(
        key: widget.fieldKey,
        controller: widget.controller,
        enabled: widget.enabled,
        obscureText: _obscure,
        autocorrect: false,
        enableSuggestions: false,
        keyboardType: TextInputType.visiblePassword,
        textInputAction: widget.textInputAction,
        autofillHints: widget.autofillHints,
        onFieldSubmitted: widget.onFieldSubmitted,
        validator: widget.validator,
        style: const TextStyle(fontSize: 14.5, color: CihuyColors.ink),
        decoration: InputDecoration(
          hintText: widget.hint,
          prefixIcon: const Icon(
            Icons.lock_outline_rounded,
            size: 20,
            color: CihuyColors.muted,
          ),
          suffixIcon: IconButton(
            tooltip: _obscure
                ? 'Tampilkan kata sandi'
                : 'Sembunyikan kata sandi',
            onPressed: widget.enabled
                ? () => setState(() => _obscure = !_obscure)
                : null,
            icon: Icon(
              _obscure
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              size: 20,
              color: CihuyColors.muted,
            ),
          ),
        ),
      ),
    ],
  );
}

class AuthErrorBanner extends StatelessWidget {
  const AuthErrorBanner(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF3F4),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFF6CDD1)),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 1),
          child: Icon(
            Icons.error_outline_rounded,
            size: 18,
            color: CihuyColors.red,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.4,
              color: Color(0xFF9C1C27),
            ),
          ),
        ),
      ],
    ),
  );
}

class AuthPrimaryButton extends StatelessWidget {
  const AuthPrimaryButton({
    super.key,
    required this.label,
    this.loading = false,
    this.loadingLabel = 'Memproses...',
    required this.onPressed,
    this.buttonKey,
  });

  final String label;
  final bool loading;
  final String loadingLabel;
  final VoidCallback? onPressed;
  final Key? buttonKey;

  @override
  Widget build(BuildContext context) => FilledButton(
    key: buttonKey,
    onPressed: loading ? null : onPressed,
    style: FilledButton.styleFrom(
      minimumSize: const Size.fromHeight(54),
      backgroundColor: CihuyColors.tealInk,
      disabledBackgroundColor: CihuyColors.tealInk.withValues(alpha: .55),
      foregroundColor: Colors.white,
      disabledForegroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
    ),
    child: AnimatedSwitcher(
      duration: const Duration(milliseconds: 150),
      child: loading
          ? Row(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              key: const ValueKey('auth-loading'),
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(loadingLabel, textAlign: TextAlign.center),
                ),
              ],
            )
          : Text(label, key: const ValueKey('auth-label')),
    ),
  );
}

class GoogleSignInButton extends StatelessWidget {
  const GoogleSignInButton({
    super.key,
    required this.onPressed,
    this.loading = false,
    this.enabled = true,
  });

  final VoidCallback? onPressed;
  final bool loading;
  final bool enabled;

  @override
  Widget build(BuildContext context) => OutlinedButton(
    key: const ValueKey('google-login'),
    onPressed: enabled && !loading ? onPressed : null,
    style: OutlinedButton.styleFrom(
      minimumSize: const Size.fromHeight(54),
      backgroundColor: Colors.white,
      foregroundColor: CihuyColors.ink,
      disabledForegroundColor: CihuyColors.muted,
      side: const BorderSide(color: Color(0xFFDDE4E8)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
    ),
    child: AnimatedSwitcher(
      duration: const Duration(milliseconds: 150),
      child: loading
          ? const Row(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              key: ValueKey('google-loading'),
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 10),
                Flexible(
                  child: Text('Menghubungkan...', textAlign: TextAlign.center),
                ),
              ],
            )
          : const Row(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              key: ValueKey('google-label'),
              mainAxisSize: MainAxisSize.min,
              children: [
                _GoogleMark(),
                SizedBox(width: 10),
                Flexible(child: Text('Lanjutkan dengan Google')),
              ],
            ),
    ),
  );
}

class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) => Container(
    width: 22,
    height: 22,
    decoration: BoxDecoration(
      color: Colors.white,
      shape: BoxShape.circle,
      border: Border.all(color: const Color(0xFFE3E8EC)),
    ),
    alignment: Alignment.center,
    child: const Text(
      'G',
      style: TextStyle(
        fontSize: 14,
        height: 1,
        fontWeight: FontWeight.w800,
        color: Color(0xFF4285F4),
      ),
    ),
  );
}

class AuthDivider extends StatelessWidget {
  const AuthDivider(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.start,
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      const Expanded(child: Divider(color: CihuyColors.border)),
      Flexible(
        flex: 2,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              height: 1.3,
              fontWeight: FontWeight.w500,
              color: CihuyColors.muted,
            ),
          ),
        ),
      ),
      const Expanded(child: Divider(color: CihuyColors.border)),
    ],
  );
}

/// Kerangka dialog autentikasi: lebar terbatas, sudut membulat, dan tetap
/// dapat digulir saat keyboard Android muncul.
class AuthDialogShell extends StatelessWidget {
  const AuthDialogShell({super.key, required this.child, this.maxWidth = 440});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final keyboard = media.viewInsets.bottom;
    // [Dialog] sendiri sudah menambahkan [MediaQuery.viewInsets] ke
    // insetPadding. Jangan menambah padding keyboard lagi di sini; cukup
    // batasi tinggi konten agar tetap dapat digulir di atas keyboard.
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth,
          maxHeight: math.max(0, media.size.height - keyboard - 48),
        ),
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
          child: child,
        ),
      ),
    );
  }
}

/// Judul + deskripsi singkat di dalam dialog.
class AuthDialogHeading extends StatelessWidget {
  const AuthDialogHeading({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    this.onClose,
    this.closeEnabled = true,
  });

  final String title;
  final String description;
  final IconData icon;
  final VoidCallback? onClose;
  final bool closeEnabled;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisAlignment: MainAxisAlignment.start,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: CihuyColors.paleTeal,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: CihuyColors.tealInk, size: 22),
          ),
          const Spacer(),
          if (onClose != null)
            IconButton(
              tooltip: 'Tutup',
              onPressed: closeEnabled ? onClose : null,
              icon: const Icon(Icons.close_rounded, size: 21),
              color: CihuyColors.muted,
            ),
        ],
      ),
      const SizedBox(height: 14),
      Text(
        title,
        style: const TextStyle(
          fontSize: 22,
          height: 1.25,
          fontWeight: FontWeight.w700,
          color: CihuyColors.ink,
        ),
      ),
      const SizedBox(height: 6),
      Text(
        description,
        style: const TextStyle(
          fontSize: 13,
          height: 1.5,
          color: CihuyColors.muted,
        ),
      ),
    ],
  );
}
