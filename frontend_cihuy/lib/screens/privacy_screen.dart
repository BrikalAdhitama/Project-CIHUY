import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  static const _developer = String.fromEnvironment('DEVELOPER_NAME');
  static const _email = String.fromEnvironment('SUPPORT_EMAIL');
  static const _privacyUrl = String.fromEnvironment('PRIVACY_POLICY_URL');
  static const _deletionUrl = String.fromEnvironment('ACCOUNT_DELETION_URL');

  Future<void> _open(BuildContext context, String value) async {
    final uri = Uri.tryParse(value);
    try {
      if (uri != null &&
          uri.scheme == 'https' &&
          uri.host.isNotEmpty &&
          await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        return;
      }
    } catch (_) {
      // Browser tidak tersedia: tampilkan pesan tanpa menutup halaman.
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Halaman belum dapat dibuka. Coba lagi.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Privasi dan data')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'Data akun',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'CIHUY menggunakan Supabase untuk autentikasi dan penyimpanan '
            'profil, alasan berhenti merokok, konsumsi awal, serta foto profil '
            'yang kamu pilih. Jika masuk dengan Google, Google memproses '
            'autentikasi akunmu.',
          ),
          const SizedBox(height: 20),
          const Text(
            'Catatan pada perangkat',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Catatan konsumsi, craving, dan target disimpan pada perangkat ini '
            'per akun. Catatan belum disinkronkan ke perangkat lain. '
            'Menghapus data aplikasi atau mencopot aplikasi dapat menghapus '
            'catatan tersebut. Kamu dapat menyalin laporan melalui '
            'Pengaturan > Ekspor data; jaga salinan laporanmu sendiri.',
          ),
          const SizedBox(height: 20),
          const Text(
            'Hapus akun dan data',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Gunakan Pengaturan > Hapus akun untuk menghapus akun, profil, '
            'dan foto di server serta catatan pada perangkat ini. '
            'Penghapusan akun tidak dapat dibatalkan. Salinan ekspor dan '
            'catatan pada perangkat lain perlu dihapus terpisah. '
            'Pengaturan > Hapus semua data mengosongkan catatan dan target '
            'pada perangkat ini tanpa menghapus akun.',
          ),
          if (_developer.isNotEmpty || _email.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text(
              'Pengelola dan kontak',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (_developer.isNotEmpty) const Text(_developer),
            if (_email.isNotEmpty) const SelectableText(_email),
          ],
          if (_privacyUrl.isNotEmpty) ...[
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => _open(context, _privacyUrl),
              child: const Text('Kebijakan privasi lengkap'),
            ),
          ],
          if (_deletionUrl.isNotEmpty)
            TextButton(
              onPressed: () => _open(context, _deletionUrl),
              child: const Text('Minta penghapusan akun melalui web'),
            ),
        ],
      ),
    ),
  );
}
