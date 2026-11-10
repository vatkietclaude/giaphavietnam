import 'dart:collection';

import '../../data/models.dart';

/// Kết quả tra cứu xưng hô giữa hai người.
class KinshipResult {
  const KinshipResult({
    required this.aCallsB,
    required this.bCallsA,
    required this.explanation,
  });

  /// A gọi B là gì.
  final String aCallsB;

  /// B gọi A là gì.
  final String bCallsA;
  final String explanation;
}

class _Ancestor {
  const _Ancestor(this.distance, this.path);

  final int distance;

  /// Đường đi từ người gốc (index 0) lên tổ tiên (phần tử cuối).
  final List<String> path;
}

class _Blood {
  const _Blood({
    required this.up,
    required this.down,
    required this.viewerPath,
    required this.targetPath,
  });

  /// Số đời từ người xem lên tổ tiên chung.
  final int up;

  /// Số đời từ người được gọi lên tổ tiên chung.
  final int down;
  final List<String> viewerPath;
  final List<String> targetPath;

  String get commonAncestorId => viewerPath.last;
}

/// Tính cách xưng hô (theo cách gọi miền Bắc) dựa trên quan hệ huyết thống,
/// vai vế giữa các nhánh và quan hệ hôn nhân.
class KinshipCalculator {
  KinshipCalculator(this.people);

  final Map<String, Person> people;

  static const unknown = 'Chưa xác định được';

  KinshipResult describe(String aId, String bId) {
    final a = people[aId];
    final b = people[bId];
    if (a == null || b == null) {
      return const KinshipResult(aCallsB: unknown, bCallsA: unknown, explanation: '');
    }
    return KinshipResult(
      aCallsB: termFor(aId, bId),
      bCallsA: termFor(bId, aId),
      explanation: _explain(a, b),
    );
  }

  /// Người [viewerId] gọi người [targetId] là gì.
  String termFor(String viewerId, String targetId) {
    final viewer = people[viewerId];
    final target = people[targetId];
    if (viewer == null || target == null) return unknown;
    final direct = _termWithoutViewerMarriage(viewer, target);
    if (direct != null) return direct;

    // Người xem là dâu/rể: gọi theo vợ/chồng.
    for (final spouseId in viewer.spouseIds) {
      final spouse = people[spouseId];
      if (spouse == null || spouse.id == target.id) continue;
      final viaSpouse = _termWithoutViewerMarriage(spouse, target);
      if (viaSpouse == null) continue;
      if (viaSpouse == 'Bố' || viaSpouse == 'Mẹ') {
        return '$viaSpouse ${viewer.isMale ? 'vợ' : 'chồng'}';
      }
      if (viaSpouse == 'Anh trai' || viaSpouse == 'Chị gái' ||
          viaSpouse == 'Em trai' || viaSpouse == 'Em gái') {
        final base = viaSpouse.split(' ').first;
        return '$base ${viewer.isMale ? 'vợ' : 'chồng'}';
      }
      return '$viaSpouse (theo ${viewer.isMale ? 'vợ' : 'chồng'})';
    }
    return unknown;
  }

  String? _termWithoutViewerMarriage(Person viewer, Person target) {
    if (viewer.id == target.id) return 'Chính mình';
    if (viewer.spouseIds.contains(target.id) || target.spouseIds.contains(viewer.id)) {
      return target.isMale ? 'Chồng' : 'Vợ';
    }
    final blood = _blood(viewer.id, target.id);
    if (blood != null) return _bloodTerm(viewer, target, blood);

    // Người được gọi là vợ/chồng của một người có họ với người xem.
    for (final spouseId in target.spouseIds) {
      final spouse = people[spouseId];
      if (spouse == null) continue;
      final relation = _blood(viewer.id, spouse.id);
      if (relation != null) {
        return _spouseOfRelativeTerm(viewer, spouse, target, relation);
      }
    }
    return null;
  }

  Map<String, _Ancestor> _ancestors(String id) {
    final result = <String, _Ancestor>{id: _Ancestor(0, [id])};
    final queue = Queue<String>()..add(id);
    while (queue.isNotEmpty) {
      final current = queue.removeFirst();
      final info = result[current]!;
      final p = people[current];
      if (p == null) continue;
      for (final parentId in [p.fatherId, p.motherId]) {
        if (parentId == null || !people.containsKey(parentId)) continue;
        if (result.containsKey(parentId)) continue;
        result[parentId] = _Ancestor(info.distance + 1, [...info.path, parentId]);
        queue.add(parentId);
      }
    }
    return result;
  }

  _Blood? _blood(String viewerId, String targetId) {
    final va = _ancestors(viewerId);
    final ta = _ancestors(targetId);
    _Blood? best;
    for (final entry in va.entries) {
      final other = ta[entry.key];
      if (other == null) continue;
      final candidate = _Blood(
        up: entry.value.distance,
        down: other.distance,
        viewerPath: entry.value.path,
        targetPath: other.path,
      );
      if (best == null || candidate.up + candidate.down < best.up + best.down) {
        best = candidate;
      }
    }
    return best;
  }

  /// `true` nếu [x] lớn hơn (hoặc thuộc vai trên) so với [y].
  bool? _isSenior(String xId, String yId) {
    final x = people[xId];
    final y = people[yId];
    if (x == null || y == null) return null;
    final sameParents = (x.fatherId != null && x.fatherId == y.fatherId) ||
        (x.motherId != null && x.motherId == y.motherId);
    if (sameParents && x.birthOrder != null && y.birthOrder != null &&
        x.birthOrder != y.birthOrder) {
      return x.birthOrder! < y.birthOrder!;
    }
    final xb = x.birth.toDateTime();
    final yb = y.birth.toDateTime();
    if (xb != null && yb != null && xb != yb) return xb.isBefore(yb);
    if (x.birth.year != null && y.birth.year != null && x.birth.year != y.birth.year) {
      return x.birth.year! < y.birth.year!;
    }
    if (x.birthOrder != null && y.birthOrder != null && x.birthOrder != y.birthOrder) {
      return x.birthOrder! < y.birthOrder!;
    }
    return null;
  }

  /// Vai vế giữa hai nhánh: so sánh hai người con của tổ tiên chung.
  bool? _branchSenior(Person viewer, Person target, _Blood r) {
    if (r.up == 0 || r.down == 0) return null;
    final viewerBranch = r.viewerPath[r.up - 1];
    final targetBranch = r.targetPath[r.down - 1];
    return _isSenior(targetBranch, viewerBranch) ?? _isSenior(target.id, viewer.id);
  }

  bool _paternal(Person viewer, _Blood r) =>
      r.viewerPath.length > 1 && r.viewerPath[1] == viewer.fatherId;

  String _bloodTerm(Person viewer, Person target, _Blood r) {
    final male = target.isMale;
    final up = r.up;
    final down = r.down;

    if (up == 0) {
      // Người được gọi là con cháu trực hệ.
      switch (down) {
        case 1:
          return male ? 'Con trai' : 'Con gái';
        case 2:
          final child = people[r.targetPath[down - 1]];
          return (child?.isMale ?? true) ? 'Cháu nội' : 'Cháu ngoại';
        case 3:
          return 'Chắt';
        case 4:
          return 'Chút';
        case 5:
          return 'Chít';
        default:
          return 'Hậu duệ đời thứ $down';
      }
    }
    if (down == 0) {
      // Người được gọi là tổ tiên trực hệ.
      final side = _paternal(viewer, r) ? 'nội' : 'ngoại';
      switch (up) {
        case 1:
          return male ? 'Bố' : 'Mẹ';
        case 2:
          return male ? 'Ông $side' : 'Bà $side';
        case 3:
          return male ? 'Cụ ông' : 'Cụ bà';
        case 4:
          return male ? 'Kỵ ông' : 'Kỵ bà';
        default:
          return 'Tổ tiên $up đời';
      }
    }

    if (up == 1 && down == 1) {
      final older = _isSenior(target.id, viewer.id);
      if (older == null) return male ? 'Anh/em trai' : 'Chị/em gái';
      if (older) return male ? 'Anh trai' : 'Chị gái';
      return male ? 'Em trai' : 'Em gái';
    }

    final senior = _branchSenior(viewer, target, r);
    final paternal = _paternal(viewer, r);
    final distant = down >= 2 && up >= 2;

    if (up == down) {
      final suffix = ' họ';
      if (senior == null) return male ? 'Anh/em$suffix' : 'Chị/em$suffix';
      if (senior) return male ? 'Anh$suffix' : 'Chị$suffix';
      return 'Em$suffix';
    }

    if (up == down + 1) {
      // Vai bác/chú/cô/cậu/dì.
      final suffix = down >= 2 ? ' họ' : '';
      String term;
      if (paternal) {
        if (male) {
          term = senior == null ? 'Bác/Chú' : (senior ? 'Bác' : 'Chú');
        } else {
          term = senior == null ? 'Bác/Cô' : (senior ? 'Bác' : 'Cô');
        }
      } else {
        if (male) {
          term = senior == null ? 'Bác/Cậu' : (senior ? 'Bác' : 'Cậu');
        } else {
          term = senior == null ? 'Bác/Dì' : (senior ? 'Bác' : 'Dì');
        }
      }
      return '$term$suffix';
    }

    if (down == up + 1) return distant ? 'Cháu họ' : 'Cháu';

    if (up > down) {
      final diff = up - down;
      final side = paternal ? 'bên nội' : 'bên ngoại';
      switch (diff) {
        case 2:
          return '${male ? 'Ông' : 'Bà'} họ ($side)';
        case 3:
          return '${male ? 'Cụ ông' : 'Cụ bà'} họ';
        case 4:
          return '${male ? 'Kỵ ông' : 'Kỵ bà'} họ';
        default:
          return 'Bề trên $diff đời';
      }
    }

    final diff = down - up;
    switch (diff) {
      case 2:
        return 'Cháu họ (gọi bằng ông/bà)';
      case 3:
        return 'Chắt họ';
      case 4:
        return 'Chút họ';
      default:
        return 'Hậu duệ $diff đời';
    }
  }

  String _spouseOfRelativeTerm(
    Person viewer,
    Person relative,
    Person target,
    _Blood r,
  ) {
    final relativeMale = relative.isMale;
    final up = r.up;
    final down = r.down;

    if (up == 0 && down == 1) return relativeMale ? 'Con dâu' : 'Con rể';
    if (up == 0 && down >= 2) return relativeMale ? 'Cháu dâu' : 'Cháu rể';
    if (up == 1 && down == 0) return relativeMale ? 'Mẹ kế' : 'Bố dượng';
    if (down == 0 && up == 2) {
      final side = _paternal(viewer, r) ? 'nội' : 'ngoại';
      return target.isMale ? 'Ông $side' : 'Bà $side';
    }
    if (up == 1 && down == 1) {
      final older = _isSenior(relative.id, viewer.id);
      if (relativeMale) {
        if (older == null) return 'Chị dâu/Em dâu';
        return older ? 'Chị dâu' : 'Em dâu';
      }
      if (older == null) return 'Anh rể/Em rể';
      return older ? 'Anh rể' : 'Em rể';
    }
    if (up == down) {
      final senior = _branchSenior(viewer, relative, r);
      if (relativeMale) {
        return senior == true ? 'Chị dâu (họ)' : (senior == false ? 'Em dâu (họ)' : 'Chị/em dâu (họ)');
      }
      return senior == true ? 'Anh rể (họ)' : (senior == false ? 'Em rể (họ)' : 'Anh/em rể (họ)');
    }
    if (up == down + 1) {
      final relativeTerm = _bloodTerm(viewer, relative, r);
      final suffix = relativeTerm.endsWith(' họ') ? ' họ' : '';
      final base = relativeTerm.replaceAll(' họ', '');
      switch (base) {
        case 'Bác':
          return relativeMale ? 'Bác gái$suffix' : 'Bác trai$suffix';
        case 'Chú':
          return 'Thím$suffix';
        case 'Cô':
        case 'Dì':
          return 'Chú (dượng)$suffix';
        case 'Cậu':
          return 'Mợ$suffix';
        default:
          return '${target.isMale ? 'Chồng' : 'Vợ'} của ${base.toLowerCase()}$suffix';
      }
    }
    if (down > up) return relativeMale ? 'Cháu dâu' : 'Cháu rể';
    final relativeTerm = _bloodTerm(viewer, relative, r);
    return '${target.isMale ? 'Chồng' : 'Vợ'} của ${relativeTerm.toLowerCase()}';
  }

  String _explain(Person a, Person b) {
    if (a.id == b.id) return '';
    if (a.spouseIds.contains(b.id)) return '${a.fullName} và ${b.fullName} là vợ chồng.';
    final r = _blood(a.id, b.id);
    if (r != null) {
      final ancestor = people[r.commonAncestorId];
      if (r.up == 0) {
        return '${b.fullName} là hậu duệ đời thứ ${r.down} của ${a.fullName}.';
      }
      if (r.down == 0) {
        return '${b.fullName} là tổ tiên ${r.up} đời của ${a.fullName}.';
      }
      return 'Tổ tiên chung gần nhất: ${ancestor?.fullName ?? '?'}. '
          '${a.fullName} cách ${r.up} đời, ${b.fullName} cách ${r.down} đời.';
    }
    return 'Quan hệ thông qua hôn nhân (dâu/rể).';
  }
}
