import 'package:shared_preferences/shared_preferences.dart';

/// Preferensi satuan rokok: berapa batang dalam satu bungkus.
///
/// Disimpan per perangkat, bukan per akun, karena nilainya hanya cara
/// memasukkan angka. Semua catatan tetap disimpan dalam satuan batang sehingga
/// target, streak, dan statistik tidak berubah saat nilainya diubah.
class UnitSettings {
  UnitSettings({SharedPreferencesAsync? preferences}) : _override = preferences;

  final SharedPreferencesAsync? _override;

  /// Dibuat saat pertama kali dipakai. Membuat [SharedPreferencesAsync] di
  /// konstruktor akan gagal pada pengujian yang tidak memasang platform
  /// shared_preferences, padahal sebagian besar pengujian tidak memakai
  /// preferensi ini.
  late final SharedPreferencesAsync _preferences =
      _override ?? SharedPreferencesAsync();

  static const defaultSticksPerPack = 12;
  static const presets = [12, 16, 20];
  static const _key = 'cigarette_sticks_per_pack';

  Future<int> load() async {
    final value = await _preferences.getInt(_key);
    return value == null || value < 1 ? defaultSticksPerPack : value;
  }

  Future<void> save(int value) async {
    if (value < 1) {
      throw ArgumentError('Isi per bungkus minimal 1 batang.');
    }
    await _preferences.setInt(_key, value);
  }
}
