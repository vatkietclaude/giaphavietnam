import 'dart:collection';

import 'models.dart';

/// Chỉ mục quan hệ được tính một lần từ một [Clan]: con cái, đời, gốc cây.
class FamilyGraph {
  FamilyGraph(this.clan) {
    _buildChildren();
    _generations = _computeGenerations();
  }

  final Clan clan;
  final Map<String, List<String>> _children = {};
  late final Map<String, int> _generations;

  Map<String, Person> get people => clan.members;

  Person? operator [](String? id) => id == null ? null : clan.members[id];

  void _buildChildren() {
    for (final p in clan.members.values) {
      for (final parentId in [p.fatherId, p.motherId]) {
        if (parentId != null && clan.members.containsKey(parentId)) {
          (_children[parentId] ??= []).add(p.id);
        }
      }
    }
    for (final list in _children.values) {
      list.sort((a, b) => compareSiblings(clan.members[a]!, clan.members[b]!));
    }
  }

  /// Sắp xếp anh chị em: theo con thứ, rồi năm sinh, rồi tên.
  static int compareSiblings(Person a, Person b) {
    final oa = a.birthOrder ?? 999;
    final ob = b.birthOrder ?? 999;
    if (oa != ob) return oa.compareTo(ob);
    final ya = a.birth.year ?? 99999;
    final yb = b.birth.year ?? 99999;
    if (ya != yb) return ya.compareTo(yb);
    return a.fullName.compareTo(b.fullName);
  }

  /// Tất cả con (cả con với các vợ/chồng khác nhau).
  List<Person> childrenOf(String id) =>
      (_children[id] ?? const []).map((c) => clan.members[c]!).toList();

  List<Person> spousesOf(String id) {
    final p = clan.members[id];
    if (p == null) return const [];
    return p.spouseIds
        .map((s) => clan.members[s])
        .whereType<Person>()
        .toList();
  }

  /// Người cha/mẹ thuộc dòng họ mà [child] được treo dưới trên phả đồ.
  String? treeParentOf(Person child) {
    final father = this[child.fatherId];
    final mother = this[child.motherId];
    if (father != null && !father.isInLaw) return father.id;
    if (mother != null && !mother.isInLaw) return mother.id;
    return father?.id ?? mother?.id;
  }

  /// Con hiển thị dưới [id] trên phả đồ.
  List<Person> treeChildrenOf(String id) =>
      childrenOf(id).where((c) => treeParentOf(c) == id).toList();

  /// Người đứng đầu các nhánh trên phả đồ (thủy tổ).
  List<Person> get treeRoots {
    final roots = <Person>[];
    for (final p in clan.members.values) {
      if (p.isInLaw) continue;
      if (this[p.fatherId] != null || this[p.motherId] != null) continue;
      // Người vợ/chồng của một gốc khác được vẽ cạnh người đó.
      final shownBesideSpouse = spousesOf(p.id).any(
        (s) =>
            !s.isInLaw &&
            s.isMale &&
            !p.isMale &&
            this[s.fatherId] == null &&
            this[s.motherId] == null,
      );
      final hasParentedSpouse = spousesOf(p.id).any(
        (s) =>
            !s.isInLaw &&
            (this[s.fatherId] != null || this[s.motherId] != null),
      );
      if (shownBesideSpouse || hasParentedSpouse) continue;
      roots.add(p);
    }
    roots.sort(compareSiblings);
    return roots;
  }

  /// Đời thứ mấy (1 = đời thủy tổ).
  int generationOf(String id) => _generations[id] ?? 1;

  int get generationCount =>
      _generations.values.isEmpty ? 0 : _generations.values.reduce((a, b) => a > b ? a : b);

  Map<String, int> _computeGenerations() {
    final gen = <String, int>{};
    final order = [
      ...treeRoots.map((p) => p.id),
      ...clan.members.keys,
    ];
    for (final start in order) {
      if (gen.containsKey(start)) continue;
      final component = <String>[];
      final queue = Queue<String>()..add(start);
      gen[start] = 0;
      while (queue.isNotEmpty) {
        final id = queue.removeFirst();
        component.add(id);
        final g = gen[id]!;
        final p = clan.members[id]!;
        void visit(String? other, int delta) {
          if (other == null || !clan.members.containsKey(other)) return;
          if (gen.containsKey(other)) return;
          gen[other] = g + delta;
          queue.add(other);
        }

        visit(p.fatherId, -1);
        visit(p.motherId, -1);
        for (final s in p.spouseIds) {
          visit(s, 0);
        }
        for (final c in _children[id] ?? const <String>[]) {
          visit(c, 1);
        }
      }
      final blood = component.where((id) => !clan.members[id]!.isInLaw);
      final base = (blood.isEmpty ? component : blood)
          .map((id) => gen[id]!)
          .reduce((a, b) => a < b ? a : b);
      for (final id in component) {
        final normalized = gen[id]! - base + 1;
        gen[id] = normalized < 1 ? 1 : normalized;
      }
    }
    return gen;
  }

  /// Số thành viên theo từng đời.
  Map<int, int> membersPerGeneration() {
    final result = SplayTreeMap<int, int>();
    for (final id in clan.members.keys) {
      final g = generationOf(id);
      result[g] = (result[g] ?? 0) + 1;
    }
    return result;
  }

  /// Mô tả ngắn quan hệ cha mẹ, ví dụ "Con ông Nguyễn Văn A".
  String parentageLabel(Person p) {
    final father = this[p.fatherId];
    final mother = this[p.motherId];
    if (father != null) return 'Con ông ${father.fullName}';
    if (mother != null) return 'Con bà ${mother.fullName}';
    if (p.isInLaw) {
      final spouse = spousesOf(p.id).firstOrNull;
      if (spouse != null) {
        return '${p.isMale ? 'Chồng' : 'Vợ'} của ${spouse.fullName}';
      }
    }
    return '';
  }
}
