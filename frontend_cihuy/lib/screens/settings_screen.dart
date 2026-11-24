import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../services/export.dart';
import '../utils/app_theme.dart';
import '../widgets/common.dart';
import 'about_screen.dart';
import 'privacy_screen.dart';
import 'auth_screen.dart';
import 'notification_settings_screen.dart';
import 'targets_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _confirmDelete(BuildContext context) async {
    final app = context.read<AppState>();
    final cloud = app.usesCloudAuth;
    final yes = await confirmAction(
      context,
      title: 'Hapus akun?',
      message: cloud
          ? 'Akun, profil, dan foto di server serta catatan pada perangkat ini '
                'akan dihapus permanen. Salinan ekspor dan data di perangkat '
                'lain perlu kamu hapus sendiri. Tindakan ini tidak bisa dibatalkan.'
          : 'Akun terdaftar (email, kata sandi, dan pengaturan) dihapus '
                'permanen dari perangkat ini. Tindakan ini tidak bisa '
                'dibatalkan.',
      confirm: 'Hapus akun',
    );
    if (!yes || !context.mounted) return;
    try {
      await app.deleteAccount();
    } catch (error) {
      if (!context.mounted) return;
      final message = error is StateError
          ? error.message
          : 'Akun belum dapat dihapus. Coba lagi.';
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _confirmClear(BuildContext context) async {
    final yes = await confirmAction(
      context,
      title: 'Hapus semua data?',
      message:
          'Semua catatan konsumsi, craving, dan target harian dikosongkan. Profil dan akunmu tetap ada. Tindakan ini tidak bisa dibatalkan.',
      confirm: 'Hapus semua',
    );
    if (!yes || !context.mounted) return;
    context.read<AppState>().clearRecords();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Semua data berhasil dihapus.')),
      );
  }

  Future<void> _showExport(BuildContext context) async {
    final report = buildExportReport(context.read<AppState>());
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Ekspor data'),
        content: SizedBox(
          width: double.maxFinite,
          height: 340,
          child: SingleChildScrollView(
            child: SelectableText(
              report,
              style: const TextStyle(fontSize: 11, height: 1.4),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Tutup'),
          ),
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: report));
              if (!context.mounted) return;
              Navigator.of(dialogContext).pop();
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  const SnackBar(
                    content: Text('Laporan tersalin ke papan klip.'),
                  ),
                );
            },
            child: const Text('Salin'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final yes = await confirmAction(
      context,
      title: 'Keluar dari akun?',
      message:
          'Profil tersimpan di akunmu. Catatan konsumsi, craving, dan target '
          'tersimpan pada perangkat ini dan belum disinkronkan ke perangkat lain.',
      confirm: 'Keluar',
      destructive: false,
    );
    if (yes && context.mounted) {
      await context.read<AppState>().signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
          children: [
            const _GroupLabel('PREFERENSI'),
            SurfaceCard(
              padding: EdgeInsets.zero,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  ListTile(
                    leading: const IconTile(Icons.notifications_outlined),
                    title: const Text(
                      'Notifikasi',
                      style: TextStyle(fontSize: 13),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: CihuyColors.muted,
                    ),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const NotificationSettingsScreen(),
                      ),
                    ),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const IconTile(Icons.adjust),
                    title: const Text(
                      'Target harian',
                      style: TextStyle(fontSize: 13),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: CihuyColors.muted,
                    ),
                    onTap: () => openTargets(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const _GroupLabel('DATA SAYA'),
            SurfaceCard(
              padding: EdgeInsets.zero,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  ListTile(
                    leading: const IconTile(Icons.file_download_outlined),
                    title: const Text(
                      'Ekspor data',
                      style: TextStyle(fontSize: 13),
                    ),
                    subtitle: const Text(
                      'Salin laporan lengkap (teks)',
                      style: TextStyle(fontSize: 11, color: CihuyColors.muted),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: CihuyColors.muted,
                    ),
                    onTap: () => _showExport(context),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const IconTile(
                      Icons.delete_sweep_outlined,
                      color: CihuyColors.red,
                      background: Color(0xFFFFF2F3),
                    ),
                    title: const Text(
                      'Hapus semua data',
                      style: TextStyle(fontSize: 13, color: CihuyColors.red),
                    ),
                    onTap: () => _confirmClear(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const _GroupLabel('KEAMANAN'),
            SurfaceCard(
              padding: EdgeInsets.zero,
              child: ListTile(
                leading: const IconTile(Icons.lock_outline),
                title: Text(
                  state.usesGoogleAuth
                      ? 'Masuk melalui Google'
                      : 'Ubah kata sandi',
                  style: const TextStyle(fontSize: 13),
                ),
                trailing: const Icon(
                  Icons.expand_more,
                  size: 18,
                  color: CihuyColors.muted,
                ),
                onTap: state.usesGoogleAuth
                    ? null
                    : () => openSheet(context, const PasswordForm()),
              ),
            ),
            const SizedBox(height: 16),
            const _GroupLabel('LAINNYA'),
            SurfaceCard(
              padding: EdgeInsets.zero,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  ListTile(
                    leading: const IconTile(Icons.privacy_tip_outlined),
                    title: const Text('Privasi dan data'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const PrivacyScreen(),
                      ),
                    ),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const IconTile(Icons.info_outline),
                    title: const Text(
                      'Tentang CIHUY',
                      style: TextStyle(fontSize: 13),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: CihuyColors.muted,
                    ),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const AboutScreen(),
                      ),
                    ),
                  ),
                  if (state.hasAccount) ...[
                    const Divider(),
                    ListTile(
                      leading: const IconTile(
                        Icons.delete_outline,
                        color: CihuyColors.red,
                        background: Color(0xFFFFF2F3),
                      ),
                      title: const Text(
                        'Hapus akun',
                        style: TextStyle(fontSize: 13, color: CihuyColors.red),
                      ),
                      onTap: state.deletingAccount
                          ? null
                          : () => _confirmDelete(context),
                    ),
                  ],
                  const Divider(),
                  ListTile(
                    leading: const IconTile(
                      Icons.logout,
                      color: CihuyColors.red,
                      background: Color(0xFFFFF2F3),
                    ),
                    title: const Text(
                      'Keluar',
                      style: TextStyle(fontSize: 13, color: CihuyColors.red),
                    ),
                    onTap: () => _confirmSignOut(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const Center(
              child: Text(
                'CIHUY · Control It, Hold Yourself',
                style: TextStyle(fontSize: 11, color: CihuyColors.muted),
              ),
            ),
          ],
        ),
      ),
    );
  }
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
