import 'package:intl/intl.dart';

DateTime dayOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);
DateTime shiftDay(DateTime value, int days) =>
    DateTime(value.year, value.month, value.day + days);
bool sameDay(DateTime a, DateTime b) => dayOnly(a) == dayOnly(b);
String fullDate(DateTime date) =>
    DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(date);
String shortDate(DateTime date) =>
    DateFormat('d MMM yyyy', 'id_ID').format(date);
String monthLabel(DateTime date) =>
    DateFormat('MMMM yyyy', 'id_ID').format(date);
String clockLabel(DateTime date) => DateFormat('HH:mm', 'id_ID').format(date);
String dateRange(DateTime from, DateTime to) {
  if (from.year != to.year) return '${shortDate(from)} – ${shortDate(to)}';
  if (from.month != to.month) {
    return '${DateFormat('d MMM', 'id_ID').format(from)}–${DateFormat('d MMM', 'id_ID').format(to)}';
  }
  return '${from.day}–${DateFormat('d MMM', 'id_ID').format(to)}';
}
