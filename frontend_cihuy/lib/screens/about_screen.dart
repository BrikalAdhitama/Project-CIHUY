import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../utils/app_theme.dart';
import '../widgets/common.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  String? _version;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  /// Versi dibaca dari metadata paket agar tidak pernah berbeda dengan build
  /// yang dipasang pengguna.
  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      final build = info.buildNumber.isEmpty ? '' : ' (${info.buildNumber})';
      setState(() => _version = 'Versi ${info.version}$build');
    } catch (_) {
      // Metadata tidak tersedia: baris versi disembunyikan.
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Tentang CIHUY')),
    body: SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(22, 28, 22, 28),
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const AppLogo(size: 84),
              const SizedBox(height: 16),
              const Text(
                'CIHUY',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: CihuyColors.ink,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Control It, Hold Yourself',
                style: TextStyle(
                  fontSize: 13,
                  color: CihuyColors.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (_version != null) ...[
                const SizedBox(height: 4),
                Text(
                  _version!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: CihuyColors.muted,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 24),
          const SurfaceCard(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TENTANG APLIKASI',
                  style: TextStyle(
                    fontSize: 12,
                    color: CihuyColors.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'CIHUY membantu kamu berhenti merokok: catat setiap konsumsi dan '
                  'keinginan merokok (craving) dengan jujur, tetapkan target harian, '
                  'dan pantau progresmu dari hari ke hari.',
                  style: TextStyle(fontSize: 13, height: 1.5),
                ),
                SizedBox(height: 12),
                Text(
                  'Fitur utama',
                  style: TextStyle(
                    fontSize: 12,
                    color: CihuyColors.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 6),
                _AboutItem(
                  'Catat konsumsi harian dan craving dengan satu ketukan',
                ),
                _AboutItem(
                  'Target harian dengan batas terlampaui yang terdeteksi',
                ),
                _AboutItem(
                  'Kalender status bulanan dan grafik progres mingguan',
                ),
                _AboutItem('Pengingat notifikasi harian untuk mencatat'),
                SizedBox(height: 12),
                Text(
                  'CIHUY bukan alat medis dan bukan pengganti nasihat dokter. '
                  'Jika muncul gejala berat saat berhenti merokok, hubungi tenaga '
                  'kesehatan.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: CihuyColors.muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
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

class _AboutItem extends StatelessWidget {
  const _AboutItem(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 2, bottom: 2),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 1),
          child: Icon(
            Icons.check_circle_outline,
            size: 15,
            color: CihuyColors.teal,
          ),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 12.5, height: 1.45),
          ),
        ),
      ],
    ),
  );
}
