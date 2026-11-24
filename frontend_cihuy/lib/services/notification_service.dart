import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart'
    hide NotificationSettings;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import '../models/notification_settings.dart';

abstract final class PushConfiguration {
  static bool get ready => Firebase.apps.isNotEmpty;
  static const apiUrl = String.fromEnvironment('NOTIFICATION_API_URL');
  static const _apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const _appId = String.fromEnvironment('FIREBASE_APP_ID');
  static const _sender = String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
  static const _project = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static bool get configured =>
      [_apiKey, _appId, _sender, _project, apiUrl].every((s) => s.isNotEmpty);
  static Future<void> initialize() async {
    if (!configured) return;
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: _apiKey,
          appId: _appId,
          messagingSenderId: _sender,
          projectId: _project,
        ),
      );
    }
  }
}

@pragma('vm:entry-point')
Future<void> notificationBackground(RemoteMessage message) async {
  // Data-only FCM: check the active account before showing anything, even after
  // logout while offline. Never render arbitrary title/body supplied by a push.
  try {
    await PushConfiguration.initialize();
    final service = NotificationService();
    await service.initialize();
    await service.receive(message.data);
  } catch (_) {
    // Background delivery is best effort; retry/sync is available in settings.
  }
}

/// Nama zona yang dilaporkan perangkat tetapi tidak ada di basis data IANA.
/// Emulator dan sebagian perangkat mengembalikan "GMT"/"UTC", sedangkan
/// paket `timezone` hanya mengenal nama `Etc/GMT` dan `Etc/UTC`.
const Map<String, String> timezoneAliases = {
  'GMT': 'Etc/GMT',
  'GMT0': 'Etc/GMT',
  'Etc/GMT0': 'Etc/GMT',
  'UTC': 'Etc/UTC',
  'UCT': 'Etc/UTC',
  'Universal': 'Etc/UTC',
  'Zulu': 'Etc/UTC',
};

/// Memetakan alias zona perangkat ke nama yang dikenal basis data IANA.
String normalizeTimezone(String name) {
  final value = name.trim();
  return timezoneAliases[value] ?? value;
}

/// Nama zona yang ramah dibaca pada layar pengaturan (tanpa awalan `Etc/`).
String timezoneLabel(String name) {
  final normalized = normalizeTimezone(name);
  return normalized.startsWith('Etc/') ? normalized.substring(4) : normalized;
}

/// Mengubah nama zona tersimpan menjadi [tz.Location] tanpa pernah melempar
/// [tz.LocationNotFoundException].
///
/// Bila nama tetap tidak dikenal, dipakai zona tetap sebesar offset perangkat
/// saat ini supaya pengingat berbunyi pada jam lokal yang benar (bukan bergeser
/// ke UTC). Pendekatan ini mengabaikan perubahan DST, tetapi hanya berlaku
/// untuk nama zona yang memang tidak dapat dikenali.
tz.Location notificationZone(String name, {DateTime? at}) {
  final normalized = normalizeTimezone(name);
  try {
    return tz.getLocation(normalized);
  } on tz.LocationNotFoundException {
    final now = at ?? DateTime.now();
    return tz.Location(
      'device-${now.timeZoneOffset.inMinutes}',
      const [],
      const [],
      [
        tz.TimeZone(
          now.timeZoneOffset,
          isDst: false,
          abbreviation: now.timeZoneName.isEmpty ? 'LOCAL' : now.timeZoneName,
        ),
      ],
    );
  }
}

tz.TZDateTime nextNotification(tz.Location zone, DateTime now, String time) {
  final parts = time.split(':').map(int.parse).toList();
  final local = tz.TZDateTime.from(now, zone);
  var next = tz.TZDateTime(
    zone,
    local.year,
    local.month,
    local.day,
    parts[0],
    parts[1],
  );
  if (!next.isAfter(local)) {
    next = tz.TZDateTime(
      zone,
      local.year,
      local.month,
      local.day + 1,
      parts[0],
      parts[1],
    );
  }
  return next;
}

class NotificationService {
  final plugin = FlutterLocalNotificationsPlugin();
  late final preferences = SharedPreferencesAsync();
  static const details = NotificationDetails(
    android: AndroidNotificationDetails(
      'cihuy_reminders',
      'Pengingat CIHUY',
      channelDescription: 'Pengingat harian dan motivasi',
      importance: Importance.high,
      priority: Priority.high,
      visibility: NotificationVisibility.private,
      onlyAlertOnce: true,
    ),
  );

  Future<void> initialize({void Function(String?)? onTap}) async {
    tzdata.initializeTimeZones();
    await plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_notification'),
      ),
      onDidReceiveNotificationResponse: (response) =>
          onTap?.call(response.payload),
    );
    await plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            'cihuy_reminders',
            'Pengingat CIHUY',
            importance: Importance.high,
          ),
        );
  }

  Future<bool> permission() async =>
      await plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission() ??
      false;
  Future<bool> allowed() async =>
      await plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.areNotificationsEnabled() ??
      false;
  Future<void> cancel() => plugin.cancelAll();
  Future<void> showLimit(String owner, DateTime day, int habitIndex) async {
    if (await preferences.getString('notification_active_owner') != owner) {
      return;
    }
    final id =
        100 +
        (DateTime.utc(day.year, day.month, day.day).millisecondsSinceEpoch ~/
                86400000) *
            2 +
        habitIndex;
    await plugin.show(
      id: id,
      title: 'CIHUY',
      body: notificationBody('exceeded'),
      notificationDetails: details,
      payload: jsonEncode({
        'owner': owner,
        'kind': 'exceeded',
        'day':
            '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}',
      }),
    );
  }

  Future<void> schedule(String owner, NotificationSettings settings) async {
    await plugin.cancel(id: 1);
    await plugin.cancel(id: 2);
    if (!settings.enabled || settings.mode != 'local') return;
    final zone = notificationZone(settings.timezone);
    for (final kind in ['progress', 'motivation']) {
      final time = kind == 'progress'
          ? settings.progressTime
          : settings.motivationTime;
      await plugin.zonedSchedule(
        id: kind == 'progress' ? 1 : 2,
        title: 'CIHUY',
        body: notificationBody(kind),
        scheduledDate: nextNotification(zone, DateTime.now(), time),
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: jsonEncode({'owner': owner, 'kind': kind}),
      );
    }
  }

  Future<void> receive(Map<String, dynamic> data) async {
    final uid = await preferences.getString('notification_active_uid');
    final owner = await preferences.getString('notification_active_owner');
    final kind = data['kind'] as String?;
    final id = data['deliveryId'] as String?;
    if (uid == null ||
        uid.isEmpty ||
        owner == null ||
        owner.isEmpty ||
        data['uid'] != uid ||
        !['progress', 'motivation'].contains(kind) ||
        id == null ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(id)) {
      return;
    }
    final raw = await preferences.getString('notification_settings_$owner');
    if (raw == null) return;
    final settings = NotificationSettings.fromJson(jsonDecode(raw));
    if (!settings.enabled || settings.mode != 'push') return;
    final seen =
        await preferences.getStringList('notification_seen_$uid') ?? [];
    if (seen.contains(id)) return;
    await preferences.setStringList('notification_seen_$uid', [
      id,
      ...seen.take(99),
    ]);
    await plugin.show(
      id: 1000 + int.parse(id.substring(0, 7), radix: 16),
      title: 'CIHUY',
      body: notificationBody(kind!),
      notificationDetails: details,
      payload: jsonEncode({'owner': owner, 'kind': kind}),
    );
  }
}
