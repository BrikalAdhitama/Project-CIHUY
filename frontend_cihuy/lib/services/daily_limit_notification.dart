import 'package:shared_preferences/shared_preferences.dart';
import '../models/records.dart';

/// Detects current-day upward crossings; durable claims prevent repeat alerts
/// after edits/restarts. The first observation only establishes a baseline.
class DailyLimitNotification {
  DailyLimitNotification(this.preferences);
  final SharedPreferencesAsync preferences;
  final Map<String, int> _previous = {};
  final Set<String> _observed = {};
  final Set<String> _pending = {};

  Future<bool> shouldNotify({
    required String owner,
    required DateTime day,
    required Habit habit,
    required int total,
    required int? limit,
    required bool enabled,
  }) async {
    final date = '${day.year}-${day.month}-${day.day}';
    final key = 'notification_limit_${owner}_${date}_${habit.name}';
    final accountHabit = '${owner}_${habit.name}';
    final previous =
        _previous[key] ?? (_observed.contains(accountHabit) ? 0 : null);
    _observed.add(accountHabit);
    _previous[key] = total;
    if (!enabled ||
        limit == null ||
        previous == null ||
        previous > limit ||
        total <= limit ||
        total <= previous ||
        !_pending.add(key)) {
      return false;
    }
    try {
      if (await preferences.getBool(key) ?? false) return false;
      // Claim before display: no duplicate even if the display call fails.
      await preferences.setBool(key, true);
      return true;
    } finally {
      _pending.remove(key);
    }
  }
}
