import 'family_graph.dart';

/// Xuất danh sách thành viên ra CSV (mở được bằng Excel / Google Sheets).
String exportMembersCsv(FamilyGraph graph) {
  const header = [
    'Đời', 'Họ tên', 'Tên khác', 'Giới tính', 'Con thứ', 'Ngày sinh', //
    'Đã mất', 'Ngày mất', 'Ngày giỗ (âm lịch)', 'Bố', 'Mẹ', 'Vợ/Chồng',
    'Dâu/Rể', 'Chức danh', 'Nghề nghiệp', 'Địa chỉ', 'Điện thoại', 'Nơi an táng', 'Tiểu sử',
  ];
  final people = graph.people.values.toList()
    ..sort((a, b) {
      final g = graph.generationOf(a.id).compareTo(graph.generationOf(b.id));
      return g != 0 ? g : FamilyGraph.compareSiblings(a, b);
    });
  final rows = <List<String>>[header];
  for (final p in people) {
    rows.add([
      '${graph.generationOf(p.id)}',
      p.fullName,
      p.nickname,
      p.gender.label,
      p.birthOrder?.toString() ?? '',
      p.birth.format(),
      p.isDeceased ? 'Có' : '',
      p.death.format(),
      p.effectiveAnniversary?.format() ?? '',
      graph[p.fatherId]?.fullName ?? '',
      graph[p.motherId]?.fullName ?? '',
      graph.spousesOf(p.id).map((s) => s.fullName).join('; '),
      p.isInLaw ? (p.isMale ? 'Rể' : 'Dâu') : '',
      p.title,
      p.occupation,
      p.address,
      p.phone,
      p.burialPlace,
      p.biography,
    ]);
  }
  return rows.map((r) => r.map(_cell).join(',')).join('\r\n');
}

String _cell(String value) {
  var v = value;
  // Chặn công thức độc hại khi mở bằng bảng tính.
  if (v.isNotEmpty && '=+-@'.contains(v[0])) v = "'$v";
  if (v.contains(RegExp(r'[",\r\n]'))) v = '"${v.replaceAll('"', '""')}"';
  return v;
}
