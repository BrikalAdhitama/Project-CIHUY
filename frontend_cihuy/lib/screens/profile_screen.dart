import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../utils/app_theme.dart';
import '../utils/dates.dart';
import '../widgets/asset_icon.dart';
import '../widgets/common.dart';
import '../widgets/profile_avatar.dart';
import 'auth_screen.dart';
import 'targets_screen.dart';

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
                        children: [
                          const ProfileAvatar(),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _GroupLabel('INFORMASI AKUN'),
                SurfaceCard(
                  padding: EdgeInsets.zero,
                  child: Column(
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
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const _GroupLabel('KEAMANAN'),
                SurfaceCard(
                  padding: EdgeInsets.zero,
                  child: ListTile(
                    leading: const IconTile(Icons.lock_outline),
                    title: const Text(
                      'Ubah kata sandi',
                      style: TextStyle(fontSize: 13),
                    ),
                    trailing: const Icon(
                      Icons.expand_more,
                      size: 18,
                      color: CihuyColors.muted,
                    ),
                    onTap: () => openSheet(context, const PasswordForm()),
                  ),
                ),
                const SizedBox(height: 16),
                const _GroupLabel('LAINNYA'),
                SurfaceCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
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
                      const Divider(),
                      ListTile(
                        leading: const IconTile(
                          Icons.logout,
                          color: CihuyColors.red,
                          background: Color(0xFFFFF2F3),
                        ),
                        title: const Text(
                          'Keluar',
                          style: TextStyle(
                            fontSize: 13,
                            color: CihuyColors.red,
                          ),
                        ),
                        onTap: () async {
                          final yes = await confirmAction(
                            context,
                            title: 'Keluar dari demo?',
                            message:
                                'Data tetap tersedia selama aplikasi belum ditutup.',
                            confirm: 'Keluar',
                            destructive: false,
                          );
                          if (yes) state.signOut();
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                SurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Mode demo',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        'Data hanya disimpan selama aplikasi berjalan. Akun dan kata sandi disimulasikan; gunakan data contoh.',
                        style: TextStyle(
                          fontSize: 12,
                          color: CihuyColors.muted,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () async {
                          final yes = await confirmAction(
                            context,
                            title: 'Coba pengguna baru?',
                            message:
                                'Data demo sesi ini diganti dengan akun kosong dan onboarding.',
                            confirm: 'Mulai',
                            destructive: false,
                          );
                          if (yes) state.startNewUser();
                        },
                        child: const Text('Coba pengguna baru'),
                      ),
                      TextButton(
                        onPressed: () async {
                          final yes = await confirmAction(
                            context,
                            title: 'Muat ulang demo terisi?',
                            message:
                                'Perubahan sesi ini diganti dengan contoh catatan tujuh hari.',
                            confirm: 'Muat demo',
                            destructive: false,
                          );
                          if (yes) state.startDemo();
                        },
                        child: const Text('Muat ulang demo terisi'),
                      ),
                      TextButton(
                        onPressed: () async {
                          final yes = await confirmAction(
                            context,
                            title: 'Hapus akun simulasi?',
                            message:
                                'Profil, target, dan semua catatan dalam sesi demo ini akan dihapus. Tidak ada akun sungguhan yang dihapus.',
                            confirm: 'Hapus akun simulasi',
                          );
                          if (yes) state.deleteAccount();
                        },
                        child: const Text(
                          'Hapus akun (simulasi)',
                          style: TextStyle(color: CihuyColors.red),
                        ),
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconTile.child(icon),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
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
        FilledButton(
          onPressed: () {
            if (!_form.currentState!.validate()) return;
            context.read<AppState>().updateProfile(
              name: widget.isName ? _text.text : null,
              reason: widget.isName ? null : _text.text,
            );
            Navigator.pop(context);
          },
          child: const Text('Simpan perubahan'),
        ),
      ],
    ),
  );
}
