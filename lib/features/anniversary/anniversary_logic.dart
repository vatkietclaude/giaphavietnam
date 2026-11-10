import '../../core/lunar/lunar_calendar.dart';
import '../../data/models.dart';

/// Một lần giỗ sắp tới của một người.
class Anniversary {
  const Anniversary({
    required this.person,
    required this.lunar,
    required this.date,
    required this.daysLeft,
    this.yearsSinceDeath,
  });

  final Person person;
  final LunarDayMonth lunar;

  /// Ngày dương lịch của lần giỗ này.
  final DateTime date;
  final int daysLeft;

  /// Giỗ lần thứ mấy (tính theo năm mất), nếu biết năm mất.
  final int? yearsSinceDeath;
}

/// Các ngày giỗ sắp tới, sắp xếp theo ngày gần nhất.
List<Anniversary> upcomingAnniversaries(
  Clan clan, {
  required DateTime from,
  int? withinDays,
}) {
  final start = DateTime(from.year, from.month, from.day);
  final result = <Anniversary>[];
  for (final p in clan.members.values) {
    final lunar = p.effectiveAnniversary;
    if (lunar == null) continue;
    final date = LunarCalendar.nextAnniversary(lunar.day, lunar.month, start);
    if (date == null) continue;
    final days = DateTime.utc(date.year, date.month, date.day)
        .difference(DateTime.utc(start.year, start.month, start.day))
        .inDays;
    if (withinDays != null && days > withinDays) continue;
    final deathYear = p.death.year;
    result.add(Anniversary(
      person: p,
      lunar: lunar,
      date: date,
      daysLeft: days,
      yearsSinceDeath: deathYear == null ? null : date.year - deathYear,
    ));
  }
  result.sort((a, b) {
    final c = a.date.compareTo(b.date);
    return c != 0 ? c : a.person.fullName.compareTo(b.person.fullName);
  });
  return result;
}

/// Người đã mất nhưng chưa có ngày giỗ.
List<Person> deceasedWithoutAnniversary(Clan clan) => clan.members.values
    .where((p) => p.isDeceased && p.effectiveAnniversary == null)
    .toList();
