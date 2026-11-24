import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/records.dart';

/// Seluruh catatan milik satu akun pada satu waktu.
class RecordsSnapshot {
  const RecordsSnapshot({
    required this.consumption,
    required this.cravings,
    required this.targets,
  });

  final List<Consumption> consumption;
  final List<Craving> cravings;
  final List<DailyTarget> targets;

  bool get isEmpty =>
      consumption.isEmpty && cravings.isEmpty && targets.isEmpty;
}

/// Penyimpanan lokal catatan konsumsi, craving, dan target.
///
/// Data disimpan per akun (kunci memuat identitas akun) supaya catatan satu
/// akun tidak pernah muncul di akun lain. Mode demo/tanpa akun tidak memakai
/// penyimpanan ini.
class RecordsStore {
  RecordsStore({SharedPreferencesAsync? preferences}) : _override = preferences;

  final SharedPreferencesAsync? _override;
  static const _prefix = 'cihuy_records_v1';
  static const _version = 1;

  /// Dibuat saat pertama kali dipakai agar pengujian tanpa platform
  /// shared_preferences tidak gagal saat konstruksi.
  late final SharedPreferencesAsync _preferences =
      _override ?? SharedPreferencesAsync();

  String _key(String owner) => '${_prefix}_$owner';

  Future<RecordsSnapshot?> load(String owner) async {
    final raw = await _preferences.getString(_key(owner));
    if (raw == null || raw.isEmpty) return null;
    try {
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic> || json['version'] != _version) {
        return null;
      }
      return RecordsSnapshot(
        consumption: _decode(json['consumption'], Consumption.fromJson),
        cravings: _decode(json['cravings'], Craving.fromJson),
        targets: _decode(json['targets'], DailyTarget.fromJson),
      );
    } catch (_) {
      // Data rusak tidak boleh menghalangi aplikasi dibuka.
      return null;
    }
  }

  Future<void> save(String owner, RecordsSnapshot snapshot) =>
      _preferences.setString(
        _key(owner),
        jsonEncode({
          'version': _version,
          'consumption': [
            for (final entry in snapshot.consumption) entry.toJson(),
          ],
          'cravings': [for (final entry in snapshot.cravings) entry.toJson()],
          'targets': [for (final entry in snapshot.targets) entry.toJson()],
        }),
      );

  Future<void> clear(String owner) => _preferences.remove(_key(owner));

  static List<T> _decode<T>(
    Object? raw,
    T Function(Map<String, dynamic>) fromJson,
  ) => [
    if (raw is List)
      for (final entry in raw)
        if (entry is Map) fromJson(entry.cast<String, dynamic>()),
  ];
}
