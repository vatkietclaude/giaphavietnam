import 'dart:math' as math;

import '../core/lunar/lunar_calendar.dart';

/// Giới tính của một thành viên.
enum Gender {
  male,
  female;

  String get label => this == Gender.male ? 'Nam' : 'Nữ';

  static Gender fromJson(Object? value) =>
      value == 'female' ? Gender.female : Gender.male;
}

/// Ngày có thể thiếu thông tin (chỉ biết năm, hoặc tháng/năm).
class PartialDate {
  const PartialDate({this.day, this.month, this.year});

  final int? day;
  final int? month;
  final int? year;

  bool get isEmpty => day == null && month == null && year == null;

  bool get isComplete => day != null && month != null && year != null;

  /// The full date, or `null` when day, month or year is unknown.
  DateTime? toDateTime() => isComplete ? DateTime(year!, month!, day!) : null;

  /// Hiển thị dạng dd/mm/yyyy, mm/yyyy hoặc yyyy.
  String format() {
    if (isEmpty) return '';
    final parts = <String>[
      if (day != null) day!.toString().padLeft(2, '0'),
      if (month != null) month!.toString().padLeft(2, '0'),
      if (year != null) year!.toString(),
    ];
    return parts.join('/');
  }

  /// Parses "12/3/1950", "3/1950", "1950" (also accepts "-" or "." as
  /// separators). Returns `null` when the text is not a valid date and an
  /// empty date when the text is blank.
  static PartialDate? tryParse(String input) {
    final text = input.trim();
    if (text.isEmpty) return const PartialDate();
    final pieces = text.split(RegExp(r'[/\-.\s]+'));
    final numbers = <int>[];
    for (final p in pieces) {
      final n = int.tryParse(p);
      if (n == null) return null;
      numbers.add(n);
    }
    int? d;
    int? m;
    int y;
    switch (numbers.length) {
      case 1:
        y = numbers[0];
      case 2:
        m = numbers[0];
        y = numbers[1];
      case 3:
        d = numbers[0];
        m = numbers[1];
        y = numbers[2];
      default:
        return null;
    }
    if (y < 1 || y > 9999) return null;
    if (m != null && (m < 1 || m > 12)) return null;
    if (d != null) {
      final daysInMonth = DateTime(y, m! + 1, 0).day;
      if (d < 1 || d > daysInMonth) return null;
    }
    return PartialDate(day: d, month: m, year: y);
  }

  Map<String, Object?> toJson() => {'d': day, 'm': month, 'y': year};

  static PartialDate fromJson(Object? json) {
    if (json is! Map) return const PartialDate();
    return PartialDate(
      day: (json['d'] as num?)?.toInt(),
      month: (json['m'] as num?)?.toInt(),
      year: (json['y'] as num?)?.toInt(),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PartialDate &&
      other.day == day &&
      other.month == month &&
      other.year == year;

  @override
  int get hashCode => Object.hash(day, month, year);
}

/// Ngày/tháng âm lịch lặp lại hằng năm (dùng cho ngày giỗ).
class LunarDayMonth {
  const LunarDayMonth(this.day, this.month);

  final int day;
  final int month;

  String format() => '$day/$month';

  Map<String, Object?> toJson() => {'d': day, 'm': month};

  static LunarDayMonth? fromJson(Object? json) {
    if (json is! Map) return null;
    final d = (json['d'] as num?)?.toInt();
    final m = (json['m'] as num?)?.toInt();
    if (d == null || m == null) return null;
    return LunarDayMonth(d, m);
  }

  @override
  bool operator ==(Object other) =>
      other is LunarDayMonth && other.day == day && other.month == month;

  @override
  int get hashCode => Object.hash(day, month);
}

const Object _unset = Object();

/// Một thành viên trong gia phả.
class Person {
  const Person({
    required this.id,
    required this.fullName,
    required this.gender,
    this.nickname = '',
    this.birth = const PartialDate(),
    this.death = const PartialDate(),
    this.isDeceased = false,
    this.deathAnniversary,
    this.fatherId,
    this.motherId,
    this.spouseIds = const [],
    this.birthOrder,
    this.isInLaw = false,
    this.title = '',
    this.occupation = '',
    this.address = '',
    this.phone = '',
    this.burialPlace = '',
    this.biography = '',
  });

  final String id;
  final String fullName;

  /// Tên thường gọi, tên húy, pháp danh…
  final String nickname;
  final Gender gender;
  final PartialDate birth;
  final PartialDate death;
  final bool isDeceased;

  /// Ngày giỗ âm lịch nhập tay. Khi trống, tính từ [death] nếu đủ ngày.
  final LunarDayMonth? deathAnniversary;
  final String? fatherId;
  final String? motherId;

  /// Vợ/chồng theo thứ tự (vợ cả, vợ hai…).
  final List<String> spouseIds;

  /// Con thứ mấy trong gia đình (1 = con trưởng).
  final int? birthOrder;

  /// Dâu/rể – người ngoài dòng họ kết hôn vào.
  final bool isInLaw;
  final String title;
  final String occupation;
  final String address;
  final String phone;

  /// Nơi an táng / mộ phần.
  final String burialPlace;
  final String biography;

  bool get isMale => gender == Gender.male;

  /// Ngày giỗ dùng để nhắc: ưu tiên ngày nhập tay, nếu không thì quy đổi
  /// từ ngày mất dương lịch.
  LunarDayMonth? get effectiveAnniversary {
    if (!isDeceased) return null;
    if (deathAnniversary != null) return deathAnniversary;
    final date = death.toDateTime();
    if (date == null) return null;
    final lunar = LunarCalendar.fromSolar(date);
    return LunarDayMonth(lunar.day, lunar.month);
  }

  /// "1920 – 1990", "1950", "? – 1990"…
  String get lifeSpan {
    final b = birth.year?.toString();
    final d = death.year?.toString();
    if (!isDeceased) return b ?? '';
    if (b == null && d == null) return 'Đã mất';
    return '${b ?? '?'} – ${d ?? '?'}';
  }

  String get initials {
    final words = fullName.trim().split(RegExp(r'\s+'));
    if (words.isEmpty || words.first.isEmpty) return '?';
    return words.last.characters1.toUpperCase();
  }

  Person copyWith({
    String? fullName,
    String? nickname,
    Gender? gender,
    PartialDate? birth,
    PartialDate? death,
    bool? isDeceased,
    Object? deathAnniversary = _unset,
    Object? fatherId = _unset,
    Object? motherId = _unset,
    List<String>? spouseIds,
    Object? birthOrder = _unset,
    bool? isInLaw,
    String? title,
    String? occupation,
    String? address,
    String? phone,
    String? burialPlace,
    String? biography,
  }) {
    return Person(
      id: id,
      fullName: fullName ?? this.fullName,
      nickname: nickname ?? this.nickname,
      gender: gender ?? this.gender,
      birth: birth ?? this.birth,
      death: death ?? this.death,
      isDeceased: isDeceased ?? this.isDeceased,
      deathAnniversary: identical(deathAnniversary, _unset)
          ? this.deathAnniversary
          : deathAnniversary as LunarDayMonth?,
      fatherId: identical(fatherId, _unset) ? this.fatherId : fatherId as String?,
      motherId: identical(motherId, _unset) ? this.motherId : motherId as String?,
      spouseIds: spouseIds ?? this.spouseIds,
      birthOrder: identical(birthOrder, _unset) ? this.birthOrder : birthOrder as int?,
      isInLaw: isInLaw ?? this.isInLaw,
      title: title ?? this.title,
      occupation: occupation ?? this.occupation,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      burialPlace: burialPlace ?? this.burialPlace,
      biography: biography ?? this.biography,
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'name': fullName,
        if (nickname.isNotEmpty) 'nick': nickname,
        'gender': gender.name,
        if (!birth.isEmpty) 'birth': birth.toJson(),
        if (!death.isEmpty) 'death': death.toJson(),
        if (isDeceased) 'deceased': true,
        if (deathAnniversary != null) 'gio': deathAnniversary!.toJson(),
        if (fatherId != null) 'father': fatherId,
        if (motherId != null) 'mother': motherId,
        if (spouseIds.isNotEmpty) 'spouses': spouseIds,
        if (birthOrder != null) 'order': birthOrder,
        if (isInLaw) 'inLaw': true,
        if (title.isNotEmpty) 'title': title,
        if (occupation.isNotEmpty) 'job': occupation,
        if (address.isNotEmpty) 'address': address,
        if (phone.isNotEmpty) 'phone': phone,
        if (burialPlace.isNotEmpty) 'burial': burialPlace,
        if (biography.isNotEmpty) 'bio': biography,
      };

  static Person fromJson(Map<String, Object?> json) {
    String str(String key) => (json[key] as String?) ?? '';
    final spouses = json['spouses'];
    return Person(
      id: json['id']! as String,
      fullName: str('name'),
      nickname: str('nick'),
      gender: Gender.fromJson(json['gender']),
      birth: PartialDate.fromJson(json['birth']),
      death: PartialDate.fromJson(json['death']),
      isDeceased: json['deceased'] == true,
      deathAnniversary: LunarDayMonth.fromJson(json['gio']),
      fatherId: json['father'] as String?,
      motherId: json['mother'] as String?,
      spouseIds: spouses is List ? spouses.whereType<String>().toList() : const [],
      birthOrder: (json['order'] as num?)?.toInt(),
      isInLaw: json['inLaw'] == true,
      title: str('title'),
      occupation: str('job'),
      address: str('address'),
      phone: str('phone'),
      burialPlace: str('burial'),
      biography: str('bio'),
    );
  }
}

extension on String {
  /// First user-perceived letter (handles Vietnamese precomposed letters).
  String get characters1 => isEmpty ? '' : String.fromCharCode(runes.first);
}

/// Một cuốn gia phả (một dòng họ / một chi).
class Clan {
  const Clan({
    required this.id,
    required this.name,
    required this.members,
    required this.createdAt,
    this.origin = '',
    this.ancestralHall = '',
    this.history = '',
    this.rules = '',
  });

  final String id;
  final String name;

  /// Quê gốc / nguyên quán.
  final String origin;

  /// Địa chỉ nhà thờ họ (từ đường).
  final String ancestralHall;

  /// Phả ký – lịch sử dòng họ.
  final String history;

  /// Tộc ước – quy ước của dòng họ.
  final String rules;
  final Map<String, Person> members;
  final DateTime createdAt;

  Clan copyWith({
    String? name,
    String? origin,
    String? ancestralHall,
    String? history,
    String? rules,
    Map<String, Person>? members,
  }) {
    return Clan(
      id: id,
      name: name ?? this.name,
      origin: origin ?? this.origin,
      ancestralHall: ancestralHall ?? this.ancestralHall,
      history: history ?? this.history,
      rules: rules ?? this.rules,
      members: members ?? this.members,
      createdAt: createdAt,
    );
  }

  Clan withId(String newId) => Clan(
        id: newId,
        name: name,
        origin: origin,
        ancestralHall: ancestralHall,
        history: history,
        rules: rules,
        members: members,
        createdAt: createdAt,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'origin': origin,
        'hall': ancestralHall,
        'history': history,
        'rules': rules,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'members': members.values.map((p) => p.toJson()).toList(),
      };

  static Clan fromJson(Map<String, Object?> json) {
    final list = json['members'];
    final members = <String, Person>{};
    if (list is List) {
      for (final item in list) {
        if (item is Map) {
          final p = Person.fromJson(item.cast<String, Object?>());
          members[p.id] = p;
        }
      }
    }
    return Clan(
      id: json['id']! as String,
      name: (json['name'] as String?) ?? 'Gia phả',
      origin: (json['origin'] as String?) ?? '',
      ancestralHall: (json['hall'] as String?) ?? '',
      history: (json['history'] as String?) ?? '',
      rules: (json['rules'] as String?) ?? '',
      createdAt: DateTime.tryParse((json['createdAt'] as String?) ?? '')?.toLocal() ??
          DateTime.now(),
      members: members,
    );
  }
}

final math.Random _random = math.Random();

/// Sinh id ngẫu nhiên, đủ an toàn để không trùng trong một gia phả.
String newId() {
  final time = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  final rand = _random.nextInt(0x7fffffff).toRadixString(36);
  return '$time$rand';
}
