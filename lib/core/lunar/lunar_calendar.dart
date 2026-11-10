import 'dart:math' as math;

/// Một ngày theo âm lịch Việt Nam (múi giờ UTC+7).
class LunarDate {
  const LunarDate({
    required this.day,
    required this.month,
    required this.year,
    this.isLeapMonth = false,
  });

  final int day;
  final int month;
  final int year;

  /// Whether the date falls in a leap month (tháng nhuận).
  final bool isLeapMonth;

  @override
  bool operator ==(Object other) =>
      other is LunarDate &&
      other.day == day &&
      other.month == month &&
      other.year == year &&
      other.isLeapMonth == isLeapMonth;

  @override
  int get hashCode => Object.hash(day, month, year, isLeapMonth);

  @override
  String toString() => '$day/$month${isLeapMonth ? ' nhuận' : ''}/$year';
}

/// Chuyển đổi âm – dương lịch theo thuật toán của Hồ Ngọc Đức,
/// tính cho múi giờ Việt Nam (UTC+7).
class LunarCalendar {
  LunarCalendar._();

  static const double _timeZone = 7.0;

  static const List<String> can = [
    'Giáp', 'Ất', 'Bính', 'Đinh', 'Mậu', 'Kỷ', 'Canh', 'Tân', 'Nhâm', 'Quý', //
  ];

  static const List<String> chi = [
    'Tý', 'Sửu', 'Dần', 'Mão', 'Thìn', 'Tỵ', //
    'Ngọ', 'Mùi', 'Thân', 'Dậu', 'Tuất', 'Hợi',
  ];

  /// Julian day number of a Gregorian (or Julian, before 1582) date.
  static int jdFromDate(int dd, int mm, int yy) {
    final a = (14 - mm) ~/ 12;
    final y = yy + 4800 - a;
    final m = mm + 12 * a - 3;
    var jd = dd +
        (153 * m + 2) ~/ 5 +
        365 * y +
        y ~/ 4 -
        y ~/ 100 +
        y ~/ 400 -
        32045;
    if (jd < 2299161) {
      jd = dd + (153 * m + 2) ~/ 5 + 365 * y + y ~/ 4 - 32083;
    }
    return jd;
  }

  /// Converts a Julian day number back to a calendar date.
  static DateTime jdToDate(int jd) {
    int b;
    int c;
    if (jd > 2299160) {
      final a = jd + 32044;
      b = (4 * a + 3) ~/ 146097;
      c = a - (b * 146097) ~/ 4;
    } else {
      b = 0;
      c = jd + 32082;
    }
    final d = (4 * c + 3) ~/ 1461;
    final e = c - (1461 * d) ~/ 4;
    final m = (5 * e + 2) ~/ 153;
    final day = e - (153 * m + 2) ~/ 5 + 1;
    final month = m + 3 - 12 * (m ~/ 10);
    final year = b * 100 + d - 4800 + m ~/ 10;
    return DateTime(year, month, day);
  }

  static int _newMoonDay(int k) {
    final t = k / 1236.85;
    final t2 = t * t;
    final t3 = t2 * t;
    const dr = math.pi / 180;
    var jd1 = 2415020.75933 + 29.53058868 * k + 0.0001178 * t2 - 0.000000155 * t3;
    jd1 += 0.00033 * math.sin((166.56 + 132.87 * t - 0.009173 * t2) * dr);
    final m = 359.2242 + 29.10535608 * k - 0.0000333 * t2 - 0.00000347 * t3;
    final mpr = 306.0253 + 385.81691806 * k + 0.0107306 * t2 + 0.00001236 * t3;
    final f = 21.2964 + 390.67050646 * k - 0.0016528 * t2 - 0.00000239 * t3;
    var c1 = (0.1734 - 0.000393 * t) * math.sin(m * dr) + 0.0021 * math.sin(2 * dr * m);
    c1 = c1 - 0.4068 * math.sin(mpr * dr) + 0.0161 * math.sin(dr * 2 * mpr);
    c1 = c1 - 0.0004 * math.sin(dr * 3 * mpr);
    c1 = c1 + 0.0104 * math.sin(dr * 2 * f) - 0.0051 * math.sin(dr * (m + mpr));
    c1 = c1 - 0.0074 * math.sin(dr * (m - mpr)) + 0.0004 * math.sin(dr * (2 * f + m));
    c1 = c1 - 0.0004 * math.sin(dr * (2 * f - m)) - 0.0006 * math.sin(dr * (2 * f + mpr));
    c1 = c1 + 0.0010 * math.sin(dr * (2 * f - mpr)) + 0.0005 * math.sin(dr * (2 * mpr + m));
    double deltaT;
    if (t < -11) {
      deltaT = 0.001 + 0.000839 * t + 0.0002261 * t2 - 0.00000845 * t3 - 0.000000081 * t * t3;
    } else {
      deltaT = -0.000278 + 0.000265 * t + 0.000262 * t2;
    }
    final jdNew = jd1 + c1 - deltaT;
    return (jdNew + 0.5 + _timeZone / 24).floor();
  }

  static int _sunLongitude(int jdn) {
    final t = (jdn - 2451545.5 - _timeZone / 24) / 36525;
    final t2 = t * t;
    const dr = math.pi / 180;
    final m = 357.52910 + 35999.05030 * t - 0.0001559 * t2 - 0.00000048 * t * t2;
    final l0 = 280.46645 + 36000.76983 * t + 0.0003032 * t2;
    var dl = (1.914600 - 0.004817 * t - 0.000014 * t2) * math.sin(dr * m);
    dl += (0.019993 - 0.000101 * t) * math.sin(dr * 2 * m) + 0.000290 * math.sin(dr * 3 * m);
    var l = (l0 + dl) * dr;
    l = l - math.pi * 2 * (l / (math.pi * 2)).floor();
    return (l / math.pi * 6).floor();
  }

  static int _lunarMonth11(int yy) {
    final off = jdFromDate(31, 12, yy) - 2415021;
    final k = (off / 29.530588853).floor();
    var nm = _newMoonDay(k);
    if (_sunLongitude(nm) >= 9) {
      nm = _newMoonDay(k - 1);
    }
    return nm;
  }

  static int _leapMonthOffset(int a11) {
    final k = ((a11 - 2415021.076998695) / 29.530588853 + 0.5).floor();
    var last = 0;
    var i = 1;
    var arc = _sunLongitude(_newMoonDay(k + i));
    do {
      last = arc;
      i++;
      arc = _sunLongitude(_newMoonDay(k + i));
    } while (arc != last && i < 14);
    return i - 1;
  }

  /// Converts a solar (Gregorian) date to the Vietnamese lunar date.
  static LunarDate fromSolar(DateTime date) {
    final dayNumber = jdFromDate(date.day, date.month, date.year);
    final k = ((dayNumber - 2415021.076998695) / 29.530588853).floor();
    var monthStart = _newMoonDay(k + 1);
    if (monthStart > dayNumber) {
      monthStart = _newMoonDay(k);
    }
    var a11 = _lunarMonth11(date.year);
    var b11 = a11;
    int lunarYear;
    if (a11 >= monthStart) {
      lunarYear = date.year;
      a11 = _lunarMonth11(date.year - 1);
    } else {
      lunarYear = date.year + 1;
      b11 = _lunarMonth11(date.year + 1);
    }
    final lunarDay = dayNumber - monthStart + 1;
    final diff = ((monthStart - a11) / 29).floor();
    var isLeap = false;
    var lunarMonth = diff + 11;
    if (b11 - a11 > 365) {
      final leapMonthDiff = _leapMonthOffset(a11);
      if (diff >= leapMonthDiff) {
        lunarMonth = diff + 10;
        if (diff == leapMonthDiff) {
          isLeap = true;
        }
      }
    }
    if (lunarMonth > 12) {
      lunarMonth -= 12;
    }
    if (lunarMonth >= 11 && diff < 4) {
      lunarYear -= 1;
    }
    return LunarDate(
      day: lunarDay,
      month: lunarMonth,
      year: lunarYear,
      isLeapMonth: isLeap,
    );
  }

  /// Converts a lunar date to the solar date, or `null` when the date does
  /// not exist (e.g. a leap month that the year does not have).
  static DateTime? toSolar(LunarDate lunar) {
    if (lunar.day < 1 || lunar.day > 30 || lunar.month < 1 || lunar.month > 12) {
      return null;
    }
    int a11;
    int b11;
    if (lunar.month < 11) {
      a11 = _lunarMonth11(lunar.year - 1);
      b11 = _lunarMonth11(lunar.year);
    } else {
      a11 = _lunarMonth11(lunar.year);
      b11 = _lunarMonth11(lunar.year + 1);
    }
    final k = (0.5 + (a11 - 2415021.076998695) / 29.530588853).floor();
    var off = lunar.month - 11;
    if (off < 0) {
      off += 12;
    }
    if (b11 - a11 > 365) {
      final leapOff = _leapMonthOffset(a11);
      var leapMonth = leapOff - 2;
      if (leapMonth < 0) {
        leapMonth += 12;
      }
      if (lunar.isLeapMonth && lunar.month != leapMonth) {
        return null;
      } else if (lunar.isLeapMonth || off >= leapOff) {
        off += 1;
      }
    } else if (lunar.isLeapMonth) {
      return null;
    }
    final monthStart = _newMoonDay(k + off);
    return jdToDate(monthStart + lunar.day - 1);
  }

  /// Solar date on which a death anniversary (ngày giỗ) given as a lunar
  /// day/month falls in [lunarYear]. Day 30 in a 29-day month moves to 29.
  static DateTime? anniversaryInLunarYear(int day, int month, int lunarYear) {
    var solar = toSolar(LunarDate(day: day, month: month, year: lunarYear));
    if (solar == null) return null;
    if (day == 30 && fromSolar(solar).day != 30) {
      solar = toSolar(LunarDate(day: 29, month: month, year: lunarYear));
    }
    return solar;
  }

  /// Next solar date (today included) of a yearly lunar anniversary.
  static DateTime? nextAnniversary(int day, int month, DateTime from) {
    final today = DateTime(from.year, from.month, from.day);
    final lunarToday = fromSolar(today);
    for (var y = lunarToday.year - 1; y <= lunarToday.year + 1; y++) {
      final candidate = anniversaryInLunarYear(day, month, y);
      if (candidate != null && !candidate.isBefore(today)) {
        return candidate;
      }
    }
    return null;
  }

  /// Tên năm theo can chi, ví dụ 2026 → "Bính Ngọ".
  static String yearCanChi(int lunarYear) =>
      '${can[(lunarYear + 6) % 10]} ${chi[(lunarYear + 8) % 12]}';

  /// Can chi của tháng âm lịch.
  static String monthCanChi(LunarDate date) =>
      '${can[(date.year * 12 + date.month + 3) % 10]} ${chi[(date.month + 1) % 12]}';

  /// Can chi của ngày dương lịch.
  static String dayCanChi(DateTime date) {
    final jd = jdFromDate(date.day, date.month, date.year);
    return '${can[(jd + 9) % 10]} ${chi[(jd + 1) % 12]}';
  }
}
