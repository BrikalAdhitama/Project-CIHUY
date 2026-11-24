import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart'
    hide NotificationSettings;
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import '../models/notification_settings.dart';
import '../models/records.dart';
import '../services/daily_limit_notification.dart';
import '../services/notification_api.dart';
import '../services/notification_service.dart';
import 'app_state.dart';

class NotificationController extends ChangeNotifier {
  NotificationController(this.app);
  final AppState app;
  final service = NotificationService();
  late final _limits = DailyLimitNotification(service.preferences);
  final _secure = const FlutterSecureStorage();
  NotificationSettings settings = const NotificationSettings();
  String? error;
  bool busy = false;
  bool linked = false;
  String? _owner;
  String? _pendingTap;
  bool _disposed = false;
  bool _ready = false;
  bool _hasBound = false;
  Future<void> _accountQueue = Future.value();
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  String? get owner => app.signedIn && app.hasAccount ? app.accountId : null;

  Future<void> initialize() async {
    try {
      await service.initialize(onTap: route);
      final launch = await service.plugin.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp == true) {
        _pendingTap = launch?.notificationResponse?.payload;
      }
      if (PushConfiguration.configured) {
        try {
          await PushConfiguration.initialize();
          _subscriptions.add(
            FirebaseMessaging.onMessage.listen((message) {
              unawaited(_receive(message));
            }),
          );
          _subscriptions.add(
            FirebaseMessaging.onMessageOpenedApp.listen(
              (message) => _routeRemote(message),
            ),
          );
          // Admin SDK token sends are retained for compatibility with existing FCM projects.
          // ignore: deprecated_member_use
          _subscriptions.add(
            // ignore: deprecated_member_use
            FirebaseMessaging.instance.onTokenRefresh.listen((_) {
              unawaited(refresh());
            }),
          );
          final initial = await FirebaseMessaging.instance.getInitialMessage();
          if (initial != null) _routeRemote(initial);
        } catch (_) {
          error =
              'Push belum dapat dihubungkan. Pengingat lokal tetap tersedia.';
        }
      }
      _ready = true;
      app.addListener(_accountChanged);
      _accountChanged();
    } catch (_) {
      error =
          'Notifikasi belum dapat disiapkan. Periksa konfigurasi dan izin perangkat.';
      _notify();
    }
  }

  Future<void> _receive(RemoteMessage message) async {
    try {
      await service.receive(message.data);
    } catch (_) {
      error = 'Notifikasi belum dapat ditampilkan.';
      _notify();
    }
  }

  void _routeRemote(RemoteMessage message) {
    // Our backend uses data-only payloads; retain this for SDK tap events too.
    if (!PushConfiguration.ready ||
        message.data['uid'] != FirebaseAuth.instance.currentUser?.uid) {
      return;
    }
    route(jsonEncode({'owner': owner, 'kind': message.data['kind']}));
  }

  void route(String? payload) {
    if (payload == null) return;
    if (owner == null || app.needsOnboarding) {
      _pendingTap = payload;
      return;
    }
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      if (data['owner'] != owner) {
        _pendingTap = null;
        return;
      }
      final destination = notificationDestination(data['kind'] as String?);
      _pendingTap = null;
      if (destination == 'calendar') {
        final day = data['kind'] == 'exceeded'
            ? DateTime.tryParse(data['day'] as String? ?? '')
            : null;
        app.selectDate(day ?? app.now, openCalendar: true);
      }
      if (destination == 'home') app.selectTab(0);
    } catch (_) {
      _pendingTap = null;
    }
  }

  void _accountChanged() {
    if (app.authLoading) return;
    final next = owner;
    if (_hasBound && next == _owner) {
      if (next != null) unawaited(_checkLimits(next));
      if (_pendingTap != null && next != null && !app.needsOnboarding) {
        route(_pendingTap);
      }
      return;
    }
    _hasBound = true;
    _owner = next;
    linked = false;
    if (next != null) unawaited(_checkLimits(next));
    _accountQueue = _accountQueue
        .then((_) async {
          busy = true;
          _notify();
          await service.preferences.setString('notification_active_uid', '');
          await service.preferences.setString(
            'notification_active_owner',
            next ?? '',
          );
          await service.cancel();
          final binding = await _binding();
          if (binding != null && binding['owner'] != next) await _disconnect();
          if (next != _owner || _disposed) {
            busy = false;
            return;
          }
          final raw = next == null
              ? null
              : await service.preferences.getString(
                  'notification_settings_$next',
                );
          settings = raw == null
              ? const NotificationSettings()
              : NotificationSettings.fromJson(jsonDecode(raw));
          if (next != null) await _sync();
          if (next != null) await _checkLimits(next);
          busy = false;
          _notify();
          if (_pendingTap != null && next != null) route(_pendingTap);
        })
        .catchError((Object _) {
          busy = false;
          error =
              'Pengaturan notifikasi belum dapat dimuat. Coba sinkronkan lagi.';
          _notify();
        });
  }

  Future<Map<String, dynamic>?> _binding() async {
    final raw = await _secure.read(key: 'notification_binding');
    return raw == null ? null : jsonDecode(raw) as Map<String, dynamic>;
  }

  NotificationApi _api() => NotificationApi(
    PushConfiguration.apiUrl,
    () async => FirebaseAuth.instance.currentUser?.getIdToken(),
  );

  Future<void> _sync() async {
    final activeOwner = _owner;
    if (activeOwner == null) return;
    final zone = await FlutterTimezone.getLocalTimezone();
    if (activeOwner != _owner || _disposed) return;
    settings = settings.copyWith(timezone: normalizeTimezone(zone.identifier));
    if (settings.enabled && !(await service.allowed())) {
      settings = settings.copyWith(enabled: false);
      error =
          'Izin notifikasi Android dinonaktifkan. Aktifkan izin lalu nyalakan kembali pengingat.';
      await service.cancel();
    }
    await service.preferences.setString(
      'notification_settings_$activeOwner',
      jsonEncode(settings.toJson()),
    );
    final binding = await _binding();
    if (activeOwner != _owner || _disposed) return;
    linked =
        PushConfiguration.ready &&
        binding?['owner'] == _owner &&
        binding?['uid'] == FirebaseAuth.instance.currentUser?.uid;
    if (linked) {
      // ignore: deprecated_member_use
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) {
        throw StateError('Token perangkat belum tersedia. Coba lagi.');
      }
      await _secure.write(key: 'notification_fcm_token', value: token);
      final api = _api();
      try {
        await api.request('PUT', '/v1/device', {
          'deviceId': binding!['deviceId'],
          'token': token,
          'settings': settings.toJson(),
        });
      } finally {
        api.close();
      }
      if (activeOwner != _owner || _disposed) return;
      await service.preferences.setString(
        'notification_active_uid',
        binding['uid'],
      );
    } else if (settings.enabled && settings.mode == 'push') {
      throw StateError('Hubungkan akun Firebase untuk mengaktifkan push.');
    }
    if (activeOwner == _owner) await service.schedule(activeOwner, settings);
  }

  Future<void> refresh() async {
    if (busy || _disposed) return;
    if (!_ready) {
      await initialize();
      return;
    }
    if (_owner == null) return;
    await _run(_sync);
  }

  Future<void> save(NotificationSettings value) => _run(() async {
    if (_owner == null) {
      throw StateError('Masuk dengan akun lokal terlebih dahulu.');
    }
    if (value.enabled && !(await service.permission())) {
      throw StateError(
        'Izin notifikasi ditolak. Aktifkan melalui pengaturan Android.',
      );
    }
    if (value.enabled && value.mode == 'push' && !linked) {
      throw StateError('Hubungkan akun Firebase terlebih dahulu.');
    }
    settings = value;
    // Persist opt-out before network calls, so delayed pushes are suppressed.
    await service.preferences.setString(
      'notification_settings_$_owner',
      jsonEncode(settings.toJson()),
    );
    await service.cancel();
    await _sync();
  });

  Future<void> connect(String password) => _run(() async {
    if (app.usesCloudAuth) {
      throw StateError(
        'Push untuk akun Supabase belum tersedia. Gunakan pengingat di perangkat.',
      );
    }
    if (!PushConfiguration.configured) {
      throw StateError(
        'Push belum dikonfigurasi. Pengingat lokal tetap tersedia.',
      );
    }
    final localOwner = owner;
    if (localOwner == null || localOwner == 'hardcoded-account') {
      throw StateError('Gunakan akun terdaftar, bukan akun demo.');
    }
    await PushConfiguration.initialize();
    await _disconnect();
    final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: app.profile.email,
      password: password,
    );
    if (owner != localOwner) {
      await FirebaseAuth.instance.signOut();
      return;
    }
    final bytes = List.generate(16, (_) => Random.secure().nextInt(256));
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    final id =
        '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
    await _secure.write(
      key: 'notification_binding',
      value: jsonEncode({
        'owner': localOwner,
        'uid': credential.user!.uid,
        'deviceId': id,
      }),
    );
    await FirebaseMessaging.instance.setAutoInitEnabled(true);
    linked = true;
    await _sync();
  });
  Future<void> disconnect() => _run(_disconnect);
  Future<void> _disconnect() async {
    linked = false;
    await service.preferences.setString('notification_active_uid', '');
    final binding = await _binding();
    if (PushConfiguration.ready) {
      if (binding != null &&
          FirebaseAuth.instance.currentUser?.uid == binding['uid']) {
        final api = _api();
        try {
          await api.request('DELETE', '/v1/device/${binding['deviceId']}');
        } catch (_) {
          error =
              'Perangkat dinonaktifkan lokal; penghapusan di server belum terkonfirmasi.';
        } finally {
          api.close();
        }
      }
      try {
        // ignore: deprecated_member_use
        await FirebaseMessaging.instance.deleteToken();
      } catch (_) {
        /* Local opt-out still applies. */
      }
      await FirebaseMessaging.instance.setAutoInitEnabled(false);
      await FirebaseAuth.instance.signOut();
    }
    await _secure.delete(key: 'notification_binding');
    await _secure.delete(key: 'notification_fcm_token');
  }

  Future<void> testPush() => _run(() async {
    if (!linked || !settings.enabled || settings.mode != 'push') {
      throw StateError(
        'Aktifkan mode push dan hubungkan akun terlebih dahulu.',
      );
    }
    final api = _api();
    try {
      await api.request('POST', '/v1/test');
    } finally {
      api.close();
    }
  });
  Future<void> _checkLimits(String activeOwner) async {
    final day = app.now;
    // Hanya jenis yang masih bisa dicatat; vape tersisa di riwayat lama saja.
    const habits = Habit.tracked;
    final totals = {
      for (final habit in habits) habit: app.progress.total(day, habit),
    };
    final limits = {
      for (final habit in habits)
        habit: app.progress.targetOn(day, habit)?.limit,
    };
    try {
      for (final habit in habits) {
        final show = await _limits.shouldNotify(
          owner: activeOwner,
          day: day,
          habit: habit,
          total: totals[habit]!,
          limit: limits[habit],
          enabled: settings.enabled && settings.exceeded,
        );
        if (show &&
            owner == activeOwner &&
            !_disposed &&
            settings.enabled &&
            settings.exceeded) {
          await service.showLimit(activeOwner, day, habit.index);
        }
      }
    } catch (_) {
      error = 'Pemberitahuan progres belum dapat ditampilkan.';
      _notify();
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (busy || _disposed) return;
    busy = true;
    error = null;
    _notify();
    try {
      await action();
    } on FirebaseAuthException {
      error =
          'Akun Firebase belum dapat dihubungkan. Periksa email, kata sandi, dan koneksi.';
    } on StateError catch (e) {
      error = e.message;
    } catch (_) {
      error =
          'Notifikasi belum berhasil disinkronkan. Periksa koneksi, izin, dan konfigurasi.';
    } finally {
      busy = false;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    app.removeListener(_accountChanged);
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    super.dispose();
  }
}
