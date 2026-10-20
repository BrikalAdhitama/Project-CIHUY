import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalAccount {
  const LocalAccount({
    required this.id,
    required this.name,
    required this.email,
    required this.passwordHash,
    required this.passwordSalt,
    required this.recoveryHash,
    required this.recoverySalt,
    required this.onboardingCompleted,
    required this.reason,
    required this.startedAt,
    this.baselineCigarette,
    this.baselineVape,
  });

  final String id;
  final String name;
  final String email;
  final String passwordHash;
  final String passwordSalt;
  final String recoveryHash;
  final String recoverySalt;
  final bool onboardingCompleted;
  final String reason;
  final DateTime startedAt;

  /// Rata-rata konsumsi awal (baseline) per jenis kebiasaan.
  final int? baselineCigarette;
  final int? baselineVape;

  LocalAccount copyWith({
    String? name,
    String? passwordHash,
    String? passwordSalt,
    String? recoveryHash,
    String? recoverySalt,
    bool? onboardingCompleted,
    String? reason,
    int? baselineCigarette,
    int? baselineVape,
  }) => LocalAccount(
    id: id,
    name: name ?? this.name,
    email: email,
    passwordHash: passwordHash ?? this.passwordHash,
    passwordSalt: passwordSalt ?? this.passwordSalt,
    recoveryHash: recoveryHash ?? this.recoveryHash,
    recoverySalt: recoverySalt ?? this.recoverySalt,
    onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
    reason: reason ?? this.reason,
    startedAt: startedAt,
    baselineCigarette: baselineCigarette ?? this.baselineCigarette,
    baselineVape: baselineVape ?? this.baselineVape,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'passwordHash': passwordHash,
    'passwordSalt': passwordSalt,
    'recoveryHash': recoveryHash,
    'recoverySalt': recoverySalt,
    'onboardingCompleted': onboardingCompleted,
    'reason': reason,
    'startedAt': startedAt.toIso8601String(),
    'baselineCigarette': baselineCigarette,
    'baselineVape': baselineVape,
  };

  factory LocalAccount.fromJson(Map<String, dynamic> json) => LocalAccount(
    id: json['id'] as String,
    name: json['name'] as String,
    email: json['email'] as String,
    passwordHash: json['passwordHash'] as String,
    passwordSalt: json['passwordSalt'] as String,
    recoveryHash: json['recoveryHash'] as String,
    recoverySalt: json['recoverySalt'] as String,
    onboardingCompleted: json['onboardingCompleted'] as bool,
    reason: json['reason'] as String,
    startedAt: DateTime.parse(json['startedAt'] as String),
    baselineCigarette: json['baselineCigarette'] as int?,
    baselineVape: json['baselineVape'] as int?,
  );
}

class LocalAuthException implements Exception {
  const LocalAuthException(this.message);
  final String message;
  @override
  String toString() => message;
}

class RecoveryCodeResult {
  const RecoveryCodeResult(this.account, this.code);
  final LocalAccount account;
  final String code;
}

class LocalAuthRepository {
  LocalAuthRepository({
    SharedPreferencesAsync? preferences,
    FlutterSecureStorage? secureStorage,
  }) : _preferences = preferences ?? SharedPreferencesAsync(),
       _secureStorage = secureStorage ?? const FlutterSecureStorage();

  static const _accountsKey = 'local_auth_accounts';
  static const _sessionKey = 'local_auth_session';
  final SharedPreferencesAsync _preferences;
  final FlutterSecureStorage _secureStorage;

  Future<List<LocalAccount>> _accounts() async {
    final raw = await _preferences.getString(_accountsKey);
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      throw const LocalAuthException('Data akun lokal rusak.');
    }
    return decoded
        .map((item) => LocalAccount.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> _saveAccounts(List<LocalAccount> accounts) =>
      _preferences.setString(
        _accountsKey,
        jsonEncode(accounts.map((account) => account.toJson()).toList()),
      );

  Future<LocalAccount?> currentAccount() async {
    final id = await _secureStorage.read(key: _sessionKey);
    if (id == null) return null;
    final account = (await _accounts()).where((item) => item.id == id);
    return account.isEmpty ? null : account.first;
  }

  Future<RecoveryCodeResult> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final normalizedEmail = normalizeEmail(email);
    final accounts = await _accounts();
    if (accounts.any((account) => account.email == normalizedEmail)) {
      throw const LocalAuthException('Email tersebut sudah terdaftar.');
    }
    final passwordSalt = _randomBytes(16);
    final recoverySalt = _randomBytes(16);
    final recoveryCode = _randomCode();
    final account = LocalAccount(
      id: _randomId(),
      name: name.trim(),
      email: normalizedEmail,
      passwordHash: _encode(_derive(password, passwordSalt)),
      passwordSalt: _encode(passwordSalt),
      recoveryHash: _encode(_derive(recoveryCode, recoverySalt)),
      recoverySalt: _encode(recoverySalt),
      onboardingCompleted: false,
      reason: 'Saya ingin hidup lebih sehat.',
      startedAt: DateTime.now(),
    );
    accounts.add(account);
    await _saveAccounts(accounts);
    await _secureStorage.write(key: _sessionKey, value: account.id);
    return RecoveryCodeResult(account, recoveryCode);
  }

  Future<LocalAccount> signIn({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = normalizeEmail(email);
    final accounts = await _accounts();
    LocalAccount? account;
    for (final candidate in accounts) {
      if (candidate.email == normalizedEmail) account = candidate;
    }
    if (account == null ||
        !_constantTimeEquals(
          _derive(password, _decode(account.passwordSalt)),
          _decode(account.passwordHash),
        )) {
      throw const LocalAuthException('Email atau kata sandi tidak sesuai.');
    }
    await _secureStorage.write(key: _sessionKey, value: account.id);
    return account;
  }

  Future<RecoveryCodeResult> resetPassword({
    required String email,
    required String code,
    required String password,
  }) async {
    final normalizedEmail = normalizeEmail(email);
    final accounts = await _accounts();
    final index = accounts.indexWhere((item) => item.email == normalizedEmail);
    if (index < 0) {
      throw const LocalAuthException('Email atau kode pemulihan tidak sesuai.');
    }
    final account = accounts[index];
    if (!_constantTimeEquals(
      _derive(code.trim(), _decode(account.recoverySalt)),
      _decode(account.recoveryHash),
    )) {
      throw const LocalAuthException('Email atau kode pemulihan tidak sesuai.');
    }
    final salt = _randomBytes(16);
    final recoverySalt = _randomBytes(16);
    final newCode = _randomCode();
    final updated = account.copyWith(
      passwordHash: _encode(_derive(password, salt)),
      passwordSalt: _encode(salt),
      recoveryHash: _encode(_derive(newCode, recoverySalt)),
      recoverySalt: _encode(recoverySalt),
    );
    accounts[index] = updated;
    await _saveAccounts(accounts);
    await _secureStorage.write(key: _sessionKey, value: updated.id);
    return RecoveryCodeResult(updated, newCode);
  }

  /// Mengganti kata sandi akun yang sedang masuk. Kode pemulihan yang
  /// sudah disimpan pengguna tetap berlaku. Mengembalikan akun yang telah
  /// diperbarui agar pemanggil menyimpan kredensial terbaru, bukan yang lama.
  Future<LocalAccount> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final id = await _secureStorage.read(key: _sessionKey);
    final accounts = await _accounts();
    final index = id == null
        ? -1
        : accounts.indexWhere((item) => item.id == id);
    if (index < 0) {
      throw const LocalAuthException('Tidak ada sesi akun yang aktif.');
    }
    final account = accounts[index];
    final currentMatches = _constantTimeEquals(
      _derive(currentPassword, _decode(account.passwordSalt)),
      _decode(account.passwordHash),
    );
    if (!currentMatches) {
      throw const LocalAuthException('Kata sandi saat ini tidak sesuai.');
    }
    if (newPassword == currentPassword) {
      throw const LocalAuthException(
        'Kata sandi baru harus berbeda dari yang sekarang.',
      );
    }
    final salt = _randomBytes(16);
    final updated = account.copyWith(
      passwordHash: _encode(_derive(newPassword, salt)),
      passwordSalt: _encode(salt),
    );
    accounts[index] = updated;
    await _saveAccounts(accounts);
    return updated;
  }

  Future<void> updateAccount(LocalAccount updated) async {
    final accounts = await _accounts();
    final index = accounts.indexWhere((item) => item.id == updated.id);
    if (index < 0) {
      throw const LocalAuthException('Akun lokal tidak ditemukan.');
    }
    accounts[index] = updated;
    await _saveAccounts(accounts);
  }

  /// Menghapus permanen satu akun terdaftar beserta sesinya. Akun lain di
  /// perangkat tidak terpengaruh.
  Future<void> deleteAccount({required String id}) async {
    final accounts = await _accounts();
    if (!accounts.any((item) => item.id == id)) {
      throw const LocalAuthException('Akun lokal tidak ditemukan.');
    }
    accounts.removeWhere((item) => item.id == id);
    await _saveAccounts(accounts);
    await _secureStorage.delete(key: _sessionKey);
  }

  Future<void> signOut() => _secureStorage.delete(key: _sessionKey);

  static String normalizeEmail(String value) => value.trim().toLowerCase();

  static Uint8List _derive(String value, List<int> salt) {
    const iterations = 120000;
    const length = 32;
    final output = Uint8List(length);
    final key = utf8.encode(value);
    final blocks = (length / 32).ceil();
    for (var block = 1; block <= blocks; block++) {
      var u = Uint8List.fromList([
        ...salt,
        (block >> 24) & 0xff,
        (block >> 16) & 0xff,
        (block >> 8) & 0xff,
        block & 0xff,
      ]);
      u = Uint8List.fromList(Hmac(sha256, key).convert(u).bytes);
      var t = Uint8List.fromList(u);
      for (var iteration = 1; iteration < iterations; iteration++) {
        u = Uint8List.fromList(Hmac(sha256, key).convert(u).bytes);
        for (var i = 0; i < t.length; i++) {
          t[i] ^= u[i];
        }
      }
      output.setRange((block - 1) * 32, min(block * 32, length), t);
    }
    return output;
  }

  static bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var difference = 0;
    for (var i = 0; i < a.length; i++) {
      difference |= a[i] ^ b[i];
    }
    return difference == 0;
  }

  static Uint8List _randomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => random.nextInt(256)),
    );
  }

  static String _randomId() => base64UrlEncode(_randomBytes(18));

  static String _randomCode() {
    final random = Random.secure();
    return List.generate(12, (_) => random.nextInt(10)).join();
  }

  static String _encode(List<int> bytes) => base64UrlEncode(bytes);
  static Uint8List _decode(String value) =>
      Uint8List.fromList(base64Url.decode(value));
}
