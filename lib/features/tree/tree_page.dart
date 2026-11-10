import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/family_graph.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../members/person_detail_screen.dart';
import '../members/person_form_screen.dart';
import 'tree_layout.dart';

/// Phả đồ tương tác: kéo, phóng to/thu nhỏ, thu gọn từng nhánh.
class TreePage extends ConsumerStatefulWidget {
  const TreePage({super.key, required this.clanId});

  final String clanId;

  @override
  ConsumerState<TreePage> createState() => _TreePageState();
}

class _TreePageState extends ConsumerState<TreePage> {
  final _controller = TransformationController();
  final Set<String> _collapsed = {};
  int? _maxGenerations;
  Size _viewport = Size.zero;
  String? _highlightId;
  bool _didInitialFit = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _fit(TreeLayout layout) {
    if (_viewport.isEmpty) return;
    final scale = math.min(
      1.0,
      math.min(_viewport.width / layout.size.width, _viewport.height / layout.size.height),
    ).clamp(0.15, 1.0).toDouble();
    final dx = (_viewport.width - layout.size.width * scale) / 2;
    final dy = math.max(0.0, (_viewport.height - layout.size.height * scale) / 2);
    _controller.value = Matrix4.diagonal3Values(scale, scale, 1)
      ..setTranslationRaw(math.max(dx, 0.0), dy, 0);
  }

  void _centerOn(TreeLayout layout, String personId) {
    final box = layout.boxOf(personId);
    if (box == null || _viewport.isEmpty) return;
    const scale = 1.0;
    final c = box.rect.center;
    _controller.value = Matrix4.diagonal3Values(scale, scale, 1)
      ..setTranslationRaw(_viewport.width / 2 - c.dx * scale, _viewport.height / 3 - c.dy * scale, 0);
  }

  Future<void> _search(FamilyGraph graph) async {
    final person = await pickPerson(context, graph, title: 'Tìm trên phả đồ');
    if (person == null || !mounted) return;
    // Mở các nhánh tổ tiên để người được tìm hiện ra.
    setState(() {
      var current = graph.treeParentOf(person) ??
          graph.spousesOf(person.id).map((s) => s.id).firstOrNull;
      final guard = <String>{};
      while (current != null && guard.add(current)) {
        _collapsed.remove(current);
        final p = graph[current];
        current = p == null ? null : graph.treeParentOf(p);
      }
      _maxGenerations = null;
      _highlightId = person.id;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final layout = TreeLayout.compute(graph, collapsed: _collapsed, maxGenerations: _maxGenerations);
      _centerOn(layout, person.id);
    });
  }

  void _openPerson(String personId) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => PersonDetailScreen(clanId: widget.clanId, personId: personId),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final graph = ref.watch(graphProvider(widget.clanId));
    if (graph == null) return const SizedBox.shrink();
    if (graph.people.isEmpty) {
      return EmptyState(
        icon: Icons.account_tree_outlined,
        title: 'Gia phả chưa có thành viên',
        action: FilledButton.icon(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => PersonFormScreen(clanId: widget.clanId),
          )),
          icon: const Icon(Icons.person_add_alt),
          label: const Text('Thêm người đầu tiên'),
        ),
      );
    }
    final layout = TreeLayout.compute(
      graph,
      collapsed: _collapsed,
      maxGenerations: _maxGenerations,
    );
    final generationCount = graph.generationCount;
    final theme = Theme.of(context);

    return Column(
      children: [
        Material(
          color: theme.colorScheme.surfaceContainerLow,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FilledButton.tonalIcon(
                  onPressed: () => _search(graph),
                  icon: const Icon(Icons.search),
                  label: const Text('Tìm'),
                ),
                DropdownButton<int?>(
                  value: _maxGenerations,
                  underline: const SizedBox.shrink(),
                  items: [
                    const DropdownMenuItem<int?>(value: null, child: Text('Tất cả các đời')),
                    for (var g = 2; g < generationCount; g++)
                      DropdownMenuItem<int?>(value: g, child: Text('Hiện $g đời')),
                  ],
                  onChanged: (v) => setState(() => _maxGenerations = v),
                ),
                IconButton(
                  tooltip: 'Mở rộng tất cả',
                  icon: const Icon(Icons.unfold_more),
                  onPressed: () => setState(_collapsed.clear),
                ),
                IconButton(
                  tooltip: 'Thu gọn về đời 2',
                  icon: const Icon(Icons.unfold_less),
                  onPressed: () => setState(() {
                    _collapsed
                      ..clear()
                      ..addAll(graph.treeRoots.expand((r) => graph.treeChildrenOf(r.id)).map((p) => p.id));
                  }),
                ),
                IconButton(
                  tooltip: 'Vừa khung hình',
                  icon: const Icon(Icons.fit_screen_outlined),
                  onPressed: () => _fit(layout),
                ),
                IconButton(
                  tooltip: 'Phóng to',
                  icon: const Icon(Icons.zoom_in),
                  onPressed: () => _zoom(1.25),
                ),
                IconButton(
                  tooltip: 'Thu nhỏ',
                  icon: const Icon(Icons.zoom_out),
                  onPressed: () => _zoom(0.8),
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              _viewport = constraints.biggest;
              if (!_didInitialFit) {
                _didInitialFit = true;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _fit(layout);
                });
              }
              return ClipRect(
                child: InteractiveViewer(
                  transformationController: _controller,
                  constrained: false,
                  minScale: 0.1,
                  maxScale: 3,
                  boundaryMargin: const EdgeInsets.all(600),
                  child: SizedBox(
                    width: layout.size.width,
                    height: layout.size.height,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _ConnectorPainter(
                              layout: layout,
                              lineColor: theme.colorScheme.outline,
                              marriageColor: AppColors.gold,
                            ),
                          ),
                        ),
                        for (final box in layout.boxes)
                          Positioned.fromRect(
                            rect: box.rect,
                            child: _PersonNode(
                              person: graph[box.personId]!,
                              box: box,
                              highlighted: box.personId == _highlightId,
                              onTap: () => _openPerson(box.personId),
                            ),
                          ),
                        for (final box in layout.boxes)
                          if (!box.isSpouse && box.childCount > 0)
                            Positioned(
                              left: box.rect.center.dx - 14,
                              top: box.rect.bottom - 2,
                              child: _ToggleButton(
                                collapsed: box.hiddenChildren > 0,
                                count: box.childCount,
                                onPressed: () => setState(() {
                                  if (_collapsed.contains(box.personId)) {
                                    _collapsed.remove(box.personId);
                                  } else if (box.hiddenChildren > 0 && _maxGenerations != null) {
                                    _maxGenerations = null;
                                  } else {
                                    _collapsed.add(box.personId);
                                  }
                                }),
                              ),
                            ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _zoom(double factor) {
    final current = _controller.value.clone();
    final scale = current.getMaxScaleOnAxis();
    final target = (scale * factor).clamp(0.1, 3.0).toDouble();
    final ratio = target / scale;
    final center = Offset(_viewport.width / 2, _viewport.height / 2);
    final translation = current.getTranslation();
    final tx = center.dx - (center.dx - translation.x) * ratio;
    final ty = center.dy - (center.dy - translation.y) * ratio;
    _controller.value = Matrix4.diagonal3Values(target, target, 1)..setTranslationRaw(tx, ty, 0);
  }
}

class _PersonNode extends StatelessWidget {
  const _PersonNode({
    required this.person,
    required this.box,
    required this.highlighted,
    required this.onTap,
  });

  final Person person;
  final TreeBox box;
  final bool highlighted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = genderColor(context, person.isMale);
    final background = box.isSpouse
        ? theme.colorScheme.surfaceContainerHighest
        : (person.isDeceased ? theme.colorScheme.surfaceContainerHigh : theme.colorScheme.surface);
    final role = box.isSpouse ? (person.isMale ? 'Chồng' : 'Vợ') : 'Đời ${box.generation}';
    return Semantics(
      button: true,
      label: '${person.fullName}, $role${person.lifeSpan.isEmpty ? '' : ', ${person.lifeSpan}'}',
      child: ExcludeSemantics(
        child: Material(
          color: background,
          elevation: highlighted ? 6 : 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(
              color: highlighted ? theme.colorScheme.primary : color.withValues(alpha: 0.7),
              width: highlighted ? 3 : (box.isSpouse ? 1 : 1.6),
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Icon(person.isMale ? Icons.male : Icons.female, size: 16, color: color),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          role,
                          style: theme.textTheme.labelSmall?.copyWith(color: color),
                        ),
                      ),
                      if (person.isDeceased)
                        Text('Đã mất', style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        )),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    person.fullName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600, height: 1.15),
                  ),
                  if (person.lifeSpan.isNotEmpty)
                    Text(
                      person.lifeSpan,
                      maxLines: 1,
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ToggleButton extends StatelessWidget {
  const _ToggleButton({required this.collapsed, required this.count, required this.onPressed});

  final bool collapsed;
  final int count;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message: collapsed ? 'Mở nhánh ($count con)' : 'Thu gọn nhánh',
      child: Material(
        color: collapsed ? theme.colorScheme.primary : theme.colorScheme.surface,
        shape: CircleBorder(side: BorderSide(color: theme.colorScheme.primary)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: 28,
            height: 28,
            child: Center(
              child: collapsed
                  ? Text('$count',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onPrimary,
                        fontWeight: FontWeight.w700,
                      ))
                  : Icon(Icons.remove, size: 16, color: theme.colorScheme.primary),
            ),
          ),
        ),
      ),
    );
  }
}

class _ConnectorPainter extends CustomPainter {
  _ConnectorPainter({required this.layout, required this.lineColor, required this.marriageColor});

  final TreeLayout layout;
  final Color lineColor;
  final Color marriageColor;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = lineColor
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
    final marriage = Paint()
      ..color = marriageColor
      ..strokeWidth = 2.4;
    for (final c in layout.connectors) {
      final midY = c.from.dy + (c.to.first.dy - c.from.dy) / 2;
      final path = Path()
        ..moveTo(c.from.dx, c.from.dy)
        ..lineTo(c.from.dx, midY);
      final minX = c.to.map((o) => o.dx).reduce(math.min);
      final maxX = c.to.map((o) => o.dx).reduce(math.max);
      path
        ..moveTo(math.min(minX, c.from.dx), midY)
        ..lineTo(math.max(maxX, c.from.dx), midY);
      for (final t in c.to) {
        path
          ..moveTo(t.dx, midY)
          ..lineTo(t.dx, t.dy);
      }
      canvas.drawPath(path, line);
    }
    for (final (a, b) in layout.marriages) {
      canvas.drawLine(a, b, marriage);
    }
  }

  @override
  bool shouldRepaint(_ConnectorPainter old) =>
      old.layout != layout || old.lineColor != lineColor || old.marriageColor != marriageColor;
}
