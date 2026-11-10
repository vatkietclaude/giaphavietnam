import 'package:flutter_test/flutter_test.dart';
import 'package:giaphavietnam/core/lunar/lunar_calendar.dart';

void main() {
  group('LunarCalendar.fromSolar', () {
    test('Tết Nguyên Đán các năm gần đây', () {
      expect(LunarCalendar.fromSolar(DateTime(2026, 2, 17)),
          const LunarDate(day: 1, month: 1, year: 2026));
      expect(LunarCalendar.fromSolar(DateTime(2025, 1, 29)),
          const LunarDate(day: 1, month: 1, year: 2025));
      expect(LunarCalendar.fromSolar(DateTime(2024, 2, 10)),
          const LunarDate(day: 1, month: 1, year: 2024));
      expect(LunarCalendar.fromSolar(DateTime(2023, 1, 22)),
          const LunarDate(day: 1, month: 1, year: 2023));
    });

    test('tháng nhuận', () {
      expect(LunarCalendar.fromSolar(DateTime(2023, 3, 22)),
          const LunarDate(day: 1, month: 2, year: 2023, isLeapMonth: true));
      expect(LunarCalendar.fromSolar(DateTime(2025, 7, 25)),
          const LunarDate(day: 1, month: 6, year: 2025, isLeapMonth: true));
    });

    test('Trung thu và Vu Lan', () {
      expect(LunarCalendar.fromSolar(DateTime(2024, 9, 17)),
          const LunarDate(day: 15, month: 8, year: 2024));
      expect(LunarCalendar.fromSolar(DateTime(2025, 9, 6)),
          const LunarDate(day: 15, month: 7, year: 2025));
    });
  });

  group('LunarCalendar.toSolar', () {
    test('chiều ngược lại khớp với fromSolar', () {
      for (var d = DateTime(2023, 1, 1);
          d.isBefore(DateTime(2027, 1, 1));
          d = d.add(const Duration(days: 13))) {
        final day = DateTime(d.year, d.month, d.day);
        final lunar = LunarCalendar.fromSolar(day);
        expect(LunarCalendar.toSolar(lunar), day, reason: '$day ↔ $lunar');
      }
    });

    test('tháng nhuận không tồn tại trả về null', () {
      expect(
        LunarCalendar.toSolar(
            const LunarDate(day: 1, month: 3, year: 2026, isLeapMonth: true)),
        isNull,
      );
    });
  });

  test('ngày giỗ kế tiếp', () {
    // Rằm tháng 7 năm Ất Tỵ là 6/9/2025.
    expect(LunarCalendar.nextAnniversary(15, 7, DateTime(2025, 8, 1)),
        DateTime(2025, 9, 6));
    // Đã qua thì sang năm âm lịch sau.
    final next = LunarCalendar.nextAnniversary(15, 7, DateTime(2025, 9, 7))!;
    expect(next.year, 2026);
    expect(LunarCalendar.fromSolar(next).day, 15);
    expect(LunarCalendar.fromSolar(next).month, 7);
  });

  test('can chi', () {
    expect(LunarCalendar.yearCanChi(2026), 'Bính Ngọ');
    expect(LunarCalendar.yearCanChi(2025), 'Ất Tỵ');
    expect(LunarCalendar.yearCanChi(1945), 'Ất Dậu');
  });
}
