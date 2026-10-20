import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../utils/app_theme.dart';
import 'common.dart';

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({super.key});

  Future<void> _edit(BuildContext context) async {
    final state = context.read<AppState>();
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(18, 0, 18, 12),
                child: Text(
                  'Foto profil',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
              ListTile(
                leading: const IconTile(Icons.photo_library_outlined),
                title: const Text('Pilih dari galeri'),
                onTap: () => Navigator.pop(context, 'pick'),
              ),
              if (state.profile.photo != null)
                ListTile(
                  leading: const Icon(
                    Icons.delete_outline,
                    color: CihuyColors.red,
                  ),
                  title: const Text(
                    'Hapus foto',
                    style: TextStyle(color: CihuyColors.red),
                  ),
                  onTap: () => Navigator.pop(context, 'remove'),
                ),
              const Padding(
                padding: EdgeInsets.fromLTRB(18, 8, 18, 8),
                child: Text(
                  'Foto hanya tersimpan selama sesi aplikasi ini.',
                  style: TextStyle(color: CihuyColors.muted, fontSize: 12),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Batal'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
    if (!context.mounted || action == null) return;
    if (action == 'remove') {
      state.removeProfilePhoto();
    } else {
      await state.changeProfilePhoto();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final profile = state.profile;
    final initials = Center(
      child: Text(
        profile.initials,
        style: const TextStyle(
          fontSize: 24,
          color: Colors.white,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
    return Tooltip(
      message: 'Ubah foto profil',
      child: Semantics(
        label: 'Ubah foto profil',
        button: true,
        enabled: !state.pickingPhoto,
        child: SizedBox(
          width: 68,
          height: 68,
          child: Stack(
            children: [
              Material(
                color: Colors.white.withValues(alpha: .25),
                borderRadius: BorderRadius.circular(17),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  key: const Key('edit-profile-photo'),
                  onTap: state.pickingPhoto ? null : () => _edit(context),
                  child: SizedBox(
                    width: 64,
                    height: 64,
                    child: state.pickingPhoto
                        ? const Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            ),
                          )
                        : profile.photo == null
                        ? initials
                        : Image.memory(
                            profile.photo!,
                            key: const Key('profile-photo'),
                            fit: BoxFit.cover,
                            gaplessPlayback: true,
                            excludeFromSemantics: true,
                            errorBuilder: (_, _, _) => initials,
                          ),
                  ),
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: IgnorePointer(
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Icon(
                      Icons.edit_outlined,
                      size: 13,
                      color: CihuyColors.teal,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
