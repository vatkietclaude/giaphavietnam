import 'models.dart';

/// Gia phả mẫu (hư cấu) để người dùng mới xem thử các tính năng.
Clan buildSampleClan({String id = 'sample-nguyen'}) {
  final members = <String, Person>{};

  void add(Person p) => members[p.id] = p;

  Person person(
    String id,
    String name,
    Gender gender, {
    int? born,
    PartialDate? death,
    int? diedYear,
    LunarDayMonth? gio,
    String? father,
    String? mother,
    List<String> spouses = const [],
    int? order,
    bool inLaw = false,
    String title = '',
    String burial = '',
    String bio = '',
    String occupation = '',
    String address = '',
  }) {
    final deceased = death != null || diedYear != null || gio != null;
    return Person(
      id: id,
      fullName: name,
      gender: gender,
      birth: PartialDate(year: born),
      death: death ?? PartialDate(year: diedYear),
      isDeceased: deceased,
      deathAnniversary: gio,
      fatherId: father,
      motherId: mother,
      spouseIds: spouses,
      birthOrder: order,
      isInLaw: inLaw,
      title: title,
      burialPlace: burial,
      biography: bio,
      occupation: occupation,
      address: address,
    );
  }

  const m = Gender.male;
  const f = Gender.female;

  // Đời 1
  add(person('to', 'Nguyễn Văn Tổ', m,
      born: 1880,
      death: const PartialDate(day: 15, month: 3, year: 1950),
      spouses: ['to-w'],
      title: 'Thủy tổ',
      burial: 'Nghĩa trang làng Phú Xuân, khu A, mộ số 1',
      bio: 'Người khai cơ lập nghiệp, đưa con cháu về làng Phú Xuân lập nghiệp.'));
  add(person('to-w', 'Lê Thị Hiền', f,
      born: 1885, diedYear: 1958, gio: const LunarDayMonth(8, 1), spouses: ['to'], inLaw: true));

  // Đời 2
  add(person('truong', 'Nguyễn Văn Trưởng', m,
      born: 1905, diedYear: 1975, gio: const LunarDayMonth(20, 7),
      father: 'to', mother: 'to-w', order: 1, spouses: ['truong-w'], title: 'Trưởng chi'));
  add(person('truong-w', 'Phạm Thị Lan', f,
      born: 1907, diedYear: 1985, gio: const LunarDayMonth(3, 3), spouses: ['truong'], inLaw: true));
  add(person('mai', 'Nguyễn Thị Mai', f,
      born: 1908, diedYear: 1990, gio: const LunarDayMonth(16, 11), father: 'to', mother: 'to-w', order: 2));
  add(person('thu', 'Nguyễn Văn Thứ', m,
      born: 1912,
      death: const PartialDate(day: 12, month: 10, year: 1980),
      father: 'to', mother: 'to-w', order: 3, spouses: ['thu-w1', 'thu-w2']));
  add(person('thu-w1', 'Trần Thị Cúc', f,
      born: 1915, diedYear: 1960, gio: const LunarDayMonth(27, 4), spouses: ['thu'], inLaw: true));
  add(person('thu-w2', 'Đỗ Thị Đào', f,
      born: 1920, diedYear: 2000, gio: const LunarDayMonth(10, 12), spouses: ['thu'], inLaw: true));

  // Đời 3
  add(person('an', 'Nguyễn Văn An', m,
      born: 1930, diedYear: 2005, gio: const LunarDayMonth(14, 8),
      father: 'truong', mother: 'truong-w', order: 1, spouses: ['an-w'], occupation: 'Giáo viên'));
  add(person('an-w', 'Hoàng Thị Hoa', f,
      born: 1932, diedYear: 2010, gio: const LunarDayMonth(5, 9), spouses: ['an'], inLaw: true));
  add(person('binh', 'Nguyễn Văn Bình', m,
      born: 1934, diedYear: 2015, gio: const LunarDayMonth(2, 2), father: 'truong', mother: 'truong-w', order: 2));
  add(person('cuong', 'Nguyễn Văn Cường', m,
      born: 1938, diedYear: 2020, gio: const LunarDayMonth(1, 5),
      father: 'thu', mother: 'thu-w1', order: 1, spouses: ['cuong-w']));
  add(person('cuong-w', 'Vũ Thị Hạnh', f, born: 1940, spouses: ['cuong'], inLaw: true));
  add(person('dung', 'Nguyễn Thị Dung', f,
      born: 1945, father: 'thu', mother: 'thu-w2', order: 2, spouses: ['dung-h']));
  add(person('dung-h', 'Lý Văn Hùng', m, born: 1943, spouses: ['dung'], inLaw: true));

  // Đời 4
  add(person('duc', 'Nguyễn Văn Đức', m,
      born: 1955, father: 'an', mother: 'an-w', order: 1, spouses: ['duc-w'],
      title: 'Trưởng tộc', address: 'Làng Phú Xuân'));
  add(person('duc-w', 'Bùi Thị Thu', f, born: 1957, spouses: ['duc'], inLaw: true));
  add(person('hang', 'Nguyễn Thị Hằng', f, born: 1958, father: 'an', mother: 'an-w', order: 2));
  add(person('phuc', 'Nguyễn Văn Phúc', m, born: 1960, father: 'binh', order: 1));
  add(person('quang', 'Nguyễn Văn Quang', m,
      born: 1962, father: 'cuong', mother: 'cuong-w', order: 1));
  add(person('ngoc', 'Nguyễn Thị Ngọc', f, born: 1965, father: 'cuong', mother: 'cuong-w', order: 2));

  // Đời 5
  add(person('minh', 'Nguyễn Văn Minh', m,
      born: 1980, father: 'duc', mother: 'duc-w', order: 1, occupation: 'Kỹ sư'));
  add(person('linh', 'Nguyễn Thị Linh', f, born: 1983, father: 'duc', mother: 'duc-w', order: 2));
  add(person('tuan', 'Nguyễn Văn Tuấn', m, born: 1978, father: 'quang', order: 1));

  // Đời 6
  add(person('bao', 'Nguyễn Gia Bảo', m, born: 2010, father: 'minh', order: 1));

  return Clan(
    id: id,
    name: 'Họ Nguyễn Văn – làng Phú Xuân (mẫu)',
    origin: 'Làng Phú Xuân (dữ liệu minh họa)',
    ancestralHall: 'Nhà thờ họ Nguyễn Văn, xóm Đình, làng Phú Xuân',
    history: 'Đây là gia phả mẫu để bạn xem thử. Cụ Thủy tổ Nguyễn Văn Tổ '
        'về khai khẩn đất Phú Xuân từ đầu thế kỷ XX. Con cháu chia thành hai chi: '
        'chi trưởng (cụ Trưởng) và chi thứ (cụ Thứ).',
    rules: '1. Ngày giỗ Thủy tổ, con cháu các chi về nhà thờ họ dâng hương.\n'
        '2. Mỗi năm họp họ một lần vào mùng 4 Tết.\n'
        '3. Con cháu sinh ra cần báo trưởng chi để ghi vào gia phả.',
    members: members,
    createdAt: DateTime(2026, 1, 1),
  );
}
