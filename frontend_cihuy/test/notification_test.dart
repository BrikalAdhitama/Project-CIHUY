import 'dart:convert';
import 'package:cihuy/models/notification_settings.dart';
import 'package:cihuy/services/notification_api.dart';
import 'package:cihuy/services/notification_service.dart';
import 'package:cihuy/services/daily_limit_notification.dart';
import 'package:cihuy/models/records.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('settings default to opt-out and reject invalid values', () {
    const settings = NotificationSettings();
    expect(settings.enabled, isFalse);
    expect(
      NotificationSettings.fromJson(settings.toJson()).progressTime,
      '20:00',
    );
    expect(
      () => NotificationSettings.fromJson({
        ...settings.toJson(),
        'progressTime': '25:00',
      }),
      throwsFormatException,
    );
    expect(notificationDestination('progress'), 'calendar');
    expect(notificationDestination('motivation'), 'home');
    expect(notificationDestination('https://untrusted.test'), isNull);
  });
  test('next reminder respects local date, next day and DST', () {
    tzdata.initializeTimeZones();
    final zone = tz.getLocation('Asia/Makassar');
    final now = DateTime.utc(2026, 11, 3, 12);
    expect(nextNotification(zone, now, '20:00').day, 4);
    expect(nextNotification(zone, now, '20:01').day, 3);
    final berlin = tz.getLocation('Europe/Berlin');
    final next = nextNotification(
      berlin,
      DateTime.utc(2026, 3, 28, 20),
      '08:00',
    );
    expect(next.hour, 8);
    expect(next.toUtc().hour, 6);
  });
  test('GMT and UTC reported by devices are scheduled without throwing', () {
    tzdata.initializeTimeZones();
    expect(normalizeTimezone('GMT'), 'Etc/GMT');
    expect(normalizeTimezone(' UTC '), 'Etc/UTC');
    expect(normalizeTimezone('Asia/Jakarta'), 'Asia/Jakarta');
    expect(notificationZone('GMT').name, 'Etc/GMT');
    expect(notificationZone('UTC').name, 'Etc/UTC');
    expect(notificationZone('Asia/Jakarta').name, 'Asia/Jakarta');
    expect(timezoneLabel('GMT'), 'GMT');
    expect(timezoneLabel('Asia/Jakarta'), 'Asia/Jakarta');
    final next = nextNotification(
      notificationZone('GMT'),
      DateTime.utc(2026, 11, 3, 12),
      '20:00',
    );
    expect(next.hour, 20);
    expect(next.minute, 0);
  });
  test('unknown zone falls back to the device offset instead of failing', () {
    tzdata.initializeTimeZones();
    final at = DateTime(2026, 11, 3, 9);
    final zone = notificationZone('Bukan/Zona', at: at);
    expect(zone.name, startsWith('device-'));
    expect(zone.currentTimeZone.offset, at.timeZoneOffset);
    final next = nextNotification(zone, at, '20:00');
    expect(next.hour, 20);
    expect(next.minute, 0);
  });
  test('API uses current ID token and refuses insecure transport', () async {
    var token = 'first';
    final seen = <String>[];
    final client = MockClient((request) async {
      seen.add(request.headers['Authorization']!);
      expect(jsonDecode(request.body)['deviceId'], 'installation');
      return http.Response('{}', 200);
    });
    final api = NotificationApi(
      'https://example.test',
      () async => token,
      client: client,
    );
    await api.request('PUT', '/v1/device', {'deviceId': 'installation'});
    token = 'refreshed';
    await api.request('PUT', '/v1/device', {'deviceId': 'installation'});
    expect(seen, ['Bearer first', 'Bearer refreshed']);
    final insecure = NotificationApi(
      'http://example.test',
      () async => token,
      client: client,
    );
    await expectLater(insecure.request('POST', '/v1/test'), throwsStateError);
    api.close();
  });
  test('API reports revoked session and rate limits', () async {
    for (final status in [401, 429, 503]) {
      final api = NotificationApi(
        'https://example.test',
        () async => 'token',
        client: MockClient((_) async => http.Response('{}', status)),
      );
      await expectLater(api.request('POST', '/v1/test'), throwsStateError);
      api.close();
    }
  });
  test(
    'late, wrong-account and disabled pushes are ignored without display',
    () async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      final service = NotificationService();
      final data = {'uid': 'A', 'kind': 'progress', 'deliveryId': 'a' * 64};
      await service.receive(data); // signed out: no platform display call
      await service.preferences.setString('notification_active_uid', 'B');
      await service.preferences.setString(
        'notification_active_owner',
        'local-B',
      );
      await service.receive(data);
      await service.preferences.setString('notification_active_uid', 'A');
      await service.preferences.setString(
        'notification_settings_local-B',
        jsonEncode(const NotificationSettings().toJson()),
      );
      await service.receive(data);
      expect(
        await service.preferences.getStringList('notification_seen_A'),
        isNull,
      );
    },
  );
  test(
    'daily limit alerts once: 5/5 none, 6/5 once, additions/corrections never repeat',
    () async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      var tracker = DailyLimitNotification(SharedPreferencesAsync());
      var day = DateTime(2026, 11, 3);
      Future<bool> check(
        int total, {
        Habit habit = Habit.cigarette,
        String owner = 'A',
        bool enabled = true,
      }) => tracker.shouldNotify(
        owner: owner,
        day: day,
        habit: habit,
        total: total,
        limit: 5,
        enabled: enabled,
      );
      expect(await check(0), isFalse);
      expect(await check(5), isFalse);
      expect(await check(6), isTrue);
      expect(await check(7), isFalse);
      expect(await check(5), isFalse);
      expect(await check(6), isFalse);
      expect(await check(0, habit: Habit.vape), isFalse);
      expect(await check(6, habit: Habit.vape), isTrue);
      // Preferences survive creating a new detector (process restart).
      tracker = DailyLimitNotification(SharedPreferencesAsync());
      expect(await check(0), isFalse);
      expect(await check(6), isFalse);
      day = DateTime(2026, 11, 4);
      expect(await check(6), isTrue, reason: 'first bulk entry the next day');
      expect(await check(0, owner: 'B'), isFalse);
      expect(await check(6, owner: 'B'), isTrue, reason: 'account isolation');
    },
  );
  test(
    'daily limit ignores restoration, missing targets and disabled settings',
    () async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      final tracker = DailyLimitNotification(SharedPreferencesAsync());
      Future<bool> check(int total, {int? limit = 5, bool enabled = true}) =>
          tracker.shouldNotify(
            owner: 'A',
            day: DateTime(2026, 11, 3),
            habit: Habit.cigarette,
            total: total,
            limit: limit,
            enabled: enabled,
          );
      expect(
        await check(6),
        isFalse,
        reason: 'restore is not a new consumption',
      );
      expect(await check(5), isFalse);
      expect(await check(6, enabled: false), isFalse);
      expect(
        await check(7),
        isFalse,
        reason: 'enabling does not retroactively alert',
      );
      expect(await check(0, limit: null), isFalse);
      expect(await check(10, limit: null), isFalse);
    },
  );
}
