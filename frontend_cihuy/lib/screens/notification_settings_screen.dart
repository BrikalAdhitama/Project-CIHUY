import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/notification_controller.dart';
import '../providers/app_state.dart';
import '../services/notification_service.dart';
import '../utils/app_theme.dart';
import '../widgets/common.dart';

class NotificationSettingsScreen extends StatelessWidget {
  const NotificationSettingsScreen({super.key});
  Future<void> _time(BuildContext context, bool progress) async {
    final controller = context.read<NotificationController>();
    final value = progress
        ? controller.settings.progressTime
        : controller.settings.motivationTime;
    final parts = value.split(':').map(int.parse).toList();
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: parts[0], minute: parts[1]),
    );
    if (time == null || !context.mounted) return;
    final text =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    await controller.save(
      controller.settings.copyWith(
        progressTime: progress ? text : null,
        motivationTime: progress ? null : text,
      ),
    );
  }

  Future<void> _connect(BuildContext context) async {
    final controller = context.read<NotificationController>();
    final password = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hubungkan akun notifikasi'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Gunakan akun Firebase dengan email yang sama dengan profilmu. Kata sandi tidak disimpan aplikasi.',
              ),
              TextField(
                controller: password,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Kata sandi Firebase',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hubungkan'),
          ),
        ],
      ),
    );
    final value = password.text;
    password.dispose();
    if (accepted == true) await controller.connect(value);
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<NotificationController>();
    final settings = controller.settings;
    final googleAccount = context.watch<AppState>().usesCloudAuth;
    // Pengaturan turunan hanya bisa diubah saat notifikasi utama aktif.
    final canEdit = settings.enabled && !controller.busy;
    final canTestPush =
        !googleAccount &&
        canEdit &&
        settings.mode == 'push' &&
        controller.linked;
    return Scaffold(
      appBar: AppBar(title: const Text('Notifikasi')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
              children: [
                const Text(
                  'Atur pengingat harianmu. Isi notifikasi tidak menampilkan catatan pribadi.',
                  style: TextStyle(color: CihuyColors.muted, height: 1.5),
                ),
                const SizedBox(height: 16),
                if (controller.busy) ...[
                  const LinearProgressIndicator(),
                  const SizedBox(height: 16),
                ],
                if (controller.error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: CihuyColors.pink,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 18,
                          color: CihuyColors.red,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            controller.error!,
                            style: const TextStyle(
                              color: CihuyColors.red,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                SurfaceCard(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Aktifkan notifikasi'),
                        subtitle: const Text(
                          'Pengingat harian di perangkat ini.',
                        ),
                        value: settings.enabled,
                        onChanged: controller.busy
                            ? null
                            : (value) => controller.save(
                                settings.copyWith(enabled: value),
                              ),
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Batas harian terlampaui'),
                        subtitle: const Text(
                          'Sekali sehari per jenis konsumsi, saat pertama melewati target.',
                        ),
                        value: settings.exceeded,
                        onChanged: canEdit
                            ? (value) => controller.save(
                                settings.copyWith(exceeded: value),
                              )
                            : null,
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        key: ValueKey('${settings.mode}-${controller.busy}'),
                        initialValue: settings.mode,
                        decoration: const InputDecoration(
                          labelText: 'Jenis pengiriman',
                          helperText:
                              'Pengingat di perangkat tetap aktif tanpa internet.',
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: 'local',
                            child: Text('Pengingat di perangkat'),
                          ),
                          if (!googleAccount)
                            const DropdownMenuItem(
                              value: 'push',
                              child: Text('Push dari server'),
                            ),
                        ],
                        onChanged: canEdit
                            ? (value) {
                                if (value != null) {
                                  controller.save(
                                    settings.copyWith(mode: value),
                                  );
                                }
                              }
                            : null,
                      ),
                      const SizedBox(height: 10),
                      const Divider(height: 1),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        enabled: canEdit,
                        title: const Text('Isi progres harian'),
                        trailing: _TimeChip(
                          settings.progressTime,
                          enabled: canEdit,
                        ),
                        onTap: canEdit ? () => _time(context, true) : null,
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        enabled: canEdit,
                        title: const Text('Pesan motivasi'),
                        trailing: _TimeChip(
                          settings.motivationTime,
                          enabled: canEdit,
                        ),
                        onTap: canEdit ? () => _time(context, false) : null,
                      ),
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.public,
                              size: 15,
                              color: CihuyColors.muted,
                            ),
                            const SizedBox(width: 7),
                            const Expanded(
                              child: Text(
                                'Zona waktu perangkat',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: CihuyColors.muted,
                                ),
                              ),
                            ),
                            Flexible(
                              child: Text(
                                timezoneLabel(settings.timezone),
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: CihuyColors.muted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (!settings.enabled) ...[
                  const SizedBox(height: 12),
                  const _Hint(
                    icon: Icons.info_outline,
                    text:
                        'Nyalakan "Aktifkan notifikasi" untuk mengubah jadwal dan jenis pengiriman.',
                  ),
                ],
                const SizedBox(height: 16),
                if (googleAccount)
                  const _Hint(
                    icon: Icons.phone_android,
                    text:
                        'Pengingat di perangkat tersedia. Push untuk akun Google belum diaktifkan.',
                  )
                else
                  FilledButton.icon(
                    onPressed: controller.busy
                        ? null
                        : controller.linked
                        ? controller.disconnect
                        : () => _connect(context),
                    icon: Icon(controller.linked ? Icons.link_off : Icons.link),
                    label: Text(
                      controller.linked
                          ? 'Putuskan akun notifikasi'
                          : 'Hubungkan akun Firebase',
                    ),
                  ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: controller.busy ? null : controller.refresh,
                  icon: const Icon(Icons.sync, size: 18),
                  label: const Text('Sinkronkan / coba lagi'),
                ),
                if (!googleAccount &&
                    settings.mode == 'push' &&
                    controller.linked)
                  TextButton.icon(
                    onPressed: canTestPush ? controller.testPush : null,
                    icon: const Icon(Icons.send_outlined, size: 18),
                    label: const Text('Kirim notifikasi uji'),
                  ),
                const SizedBox(height: 4),
                const Text(
                  'Pengingat lokal tidak membutuhkan koneksi. Push memerlukan internet. Penghematan baterai dan izin Android dapat menunda pengiriman.',
                  style: TextStyle(
                    fontSize: 12,
                    color: CihuyColors.muted,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TimeChip extends StatelessWidget {
  const _TimeChip(this.value, {required this.enabled});
  final String value;
  final bool enabled;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: enabled ? CihuyColors.paleTeal : CihuyColors.surface,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      value,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: enabled ? CihuyColors.tealInk : CihuyColors.muted,
      ),
    ),
  );
}

class _Hint extends StatelessWidget {
  const _Hint({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: CihuyColors.surface,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 17, color: CihuyColors.muted),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              color: CihuyColors.muted,
              height: 1.45,
            ),
          ),
        ),
      ],
    ),
  );
}
