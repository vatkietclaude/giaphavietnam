import 'dart:math' as math;
import 'dart:ui';

import '../../data/family_graph.dart';

/// Kích thước và khoảng cách của các ô trên phả đồ.
class TreeMetrics {
  const TreeMetrics({
    this.nodeWidth = 156,
    this.nodeHeight = 92,
    this.spouseGap = 8,
    this.siblingGap = 20,
    this.levelGap = 60,
    this.padding = 32,
  });

  final double nodeWidth;
  final double nodeHeight;
  final double spouseGap;
  final double siblingGap;
  final double levelGap;
  final double padding;
}

/// Một ô (người) trên phả đồ.
class TreeBox {
  const TreeBox({
    required this.personId,
    required this.rect,
    required this.isSpouse,
    required this.generation,
    this.hiddenChildren = 0,
    this.childCount = 0,
  });

  final String personId;
  final Rect rect;

  /// Ô vợ/chồng (dâu/rể) vẽ cạnh người trong họ.
  final bool isSpouse;
  final int generation;

  /// Số con đang bị thu gọn.
  final int hiddenChildren;
  final int childCount;
}

/// Đường nối cha/mẹ với các con.
class TreeConnector {
  const TreeConnector(this.from, this.to);

  final Offset from;
  final List<Offset> to;
}

class TreeLayout {
  const TreeLayout({
    required this.boxes,
    required this.connectors,
    required this.marriages,
    required this.size,
  });

  final List<TreeBox> boxes;
  final List<TreeConnector> connectors;

  /// Đường nối ngang giữa vợ và chồng.
  final List<(Offset, Offset)> marriages;
  final Size size;

  TreeBox? boxOf(String personId) {
    for (final b in boxes) {
      if (b.personId == personId && !b.isSpouse) return b;
    }
    for (final b in boxes) {
      if (b.personId == personId) return b;
    }
    return null;
  }

  /// Tính bố cục phả đồ dạng cây từ trên xuống.
  ///
  /// [collapsed] chứa id những người đã thu gọn nhánh; [maxGenerations]
  /// giới hạn số đời hiển thị (null = tất cả).
  static TreeLayout compute(
    FamilyGraph graph, {
    Set<String> collapsed = const {},
    int? maxGenerations,
    String? rootId,
    TreeMetrics metrics = const TreeMetrics(),
  }) {
    final m = metrics;
    final widths = <String, double>{};
    final visited = <String>{};
    final roots = rootId != null && graph[rootId] != null
        ? [graph[rootId]!]
        : graph.treeRoots;

    double unitWidth(String id) {
      final spouses = graph.spousesOf(id).length;
      return (1 + spouses) * m.nodeWidth + spouses * m.spouseGap;
    }

    List<String> visibleChildren(String id, int depth) {
      if (collapsed.contains(id)) return const [];
      if (maxGenerations != null && depth + 1 >= maxGenerations) return const [];
      return graph.treeChildrenOf(id).map((p) => p.id).toList();
    }

    double measure(String id, int depth) {
      if (!visited.add(id)) return widths[id] = 0;
      final kids = visibleChildren(id, depth);
      var childrenWidth = 0.0;
      for (var i = 0; i < kids.length; i++) {
        childrenWidth += measure(kids[i], depth + 1);
        if (i > 0) childrenWidth += m.siblingGap;
      }
      return widths[id] = math.max(unitWidth(id), childrenWidth);
    }

    var totalWidth = 0.0;
    for (var i = 0; i < roots.length; i++) {
      totalWidth += measure(roots[i].id, 0);
      if (i > 0) totalWidth += m.siblingGap * 2;
    }

    final boxes = <TreeBox>[];
    final connectors = <TreeConnector>[];
    final marriages = <(Offset, Offset)>[];
    final placed = <String>{};
    var maxDepth = 0;

    /// Đặt người [id] trong khoảng ngang bắt đầu từ [left]; trả về tâm trên
    /// của ô người đó.
    Offset place(String id, double left, int depth) {
      final width = widths[id] ?? unitWidth(id);
      final y = m.padding + depth * (m.nodeHeight + m.levelGap);
      maxDepth = math.max(maxDepth, depth);
      if (!placed.add(id)) {
        return Offset(left + m.nodeWidth / 2, y);
      }
      final kids = visibleChildren(id, depth);
      final allKids = graph.treeChildrenOf(id);
      final unitLeft = left + (width - unitWidth(id)) / 2;
      final personRect = Rect.fromLTWH(unitLeft, y, m.nodeWidth, m.nodeHeight);
      boxes.add(TreeBox(
        personId: id,
        rect: personRect,
        isSpouse: false,
        generation: graph.generationOf(id),
        childCount: allKids.length,
        hiddenChildren: allKids.length - kids.length,
      ));
      var spouseLeft = unitLeft + m.nodeWidth + m.spouseGap;
      for (final spouse in graph.spousesOf(id)) {
        final rect = Rect.fromLTWH(spouseLeft, y, m.nodeWidth, m.nodeHeight);
        boxes.add(TreeBox(
          personId: spouse.id,
          rect: rect,
          isSpouse: true,
          generation: graph.generationOf(spouse.id),
        ));
        marriages.add((
          Offset(spouseLeft - m.spouseGap, y + m.nodeHeight / 2),
          Offset(spouseLeft, y + m.nodeHeight / 2),
        ));
        spouseLeft += m.nodeWidth + m.spouseGap;
      }
      if (kids.isNotEmpty) {
        var childrenWidth = 0.0;
        for (var i = 0; i < kids.length; i++) {
          childrenWidth += widths[kids[i]] ?? 0;
          if (i > 0) childrenWidth += m.siblingGap;
        }
        var cursor = left + (width - childrenWidth) / 2;
        final tops = <Offset>[];
        for (final kid in kids) {
          final w = widths[kid] ?? 0;
          if (w > 0) tops.add(place(kid, cursor, depth + 1));
          cursor += w + m.siblingGap;
        }
        if (tops.isNotEmpty) {
          connectors.add(TreeConnector(personRect.bottomCenter, tops));
        }
      }
      return personRect.topCenter;
    }

    var cursor = m.padding;
    for (final root in roots) {
      place(root.id, cursor, 0);
      cursor += (widths[root.id] ?? 0) + m.siblingGap * 2;
    }

    final width = math.max(totalWidth + m.padding * 2, m.nodeWidth + m.padding * 2);
    final height = m.padding * 2 + (maxDepth + 1) * m.nodeHeight + maxDepth * m.levelGap;
    return TreeLayout(
      boxes: boxes,
      connectors: connectors,
      marriages: marriages,
      size: Size(width, height),
    );
  }
}
