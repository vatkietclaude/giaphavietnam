import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/kinship/kinship.dart';
import '../../data/family_graph.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';

/// Tra cứu cách xưng hô giữa hai thành viên.
class KinshipPage extends ConsumerStatefulWidget {
  const KinshipPage({super.key, required this.clanId});

  final String clanId;

  @override
  ConsumerState<KinshipPage> createState() => _KinshipPageState();
}

class _KinshipPageState extends ConsumerState<KinshipPage> {
  String? _aId;
  String? _bId;

  Future<void> _pick(FamilyGraph graph, bool first) async {
    final p = await pickPerson(context, graph, title: first ? 'Chọn người thứ nhất' : 'Chọn người thứ hai');
    if (p == null || !mounted) return;
    setState(() {
      if (first) {
        _aId = p.id;
      } else {
        _bId = p.id;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final graph = ref.watch(graphProvider(widget.clanId));
    if (graph == null) return const SizedBox.shrink();
    final a = graph[_aId];
    final b = graph[_bId];
    final theme = Theme.of(context);
    final result = a != null && b != null
        ? KinshipCalculator(graph.people).describe(a.id, b.id)
        : null;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Chọn hai người để biết họ xưng hô với nhau thế nào.',
                style: theme.textTheme.bodyLarge),
            const SizedBox(height: 4),
            Text(
              'Vai vế anh/chị – em giữa các nhánh được tính theo thứ bậc của tổ tiên '
              '(con chú con bác), không theo tuổi. Cách gọi theo phong tục miền Bắc.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            _PersonSlot(label: 'Người thứ nhất (A)', person: a, onTap: () => _pick(graph, true)),
            Center(
              child: IconButton(
                tooltip: 'Đổi chỗ',
                icon: const Icon(Icons.swap_vert),
                onPressed: () => setState(() {
                  final t = _aId;
                  _aId = _bId;
                  _bId = t;
                }),
              ),
            ),
            _PersonSlot(label: 'Người thứ hai (B)', person: b, onTap: () => _pick(graph, false)),
            const SizedBox(height: 20),
            if (result != null && a != null && b != null)
              Card(
                color: theme.colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Line(caller: a.fullName, term: result.aCallsB, callee: b.fullName),
                      const SizedBox(height: 12),
                      _Line(caller: b.fullName, term: result.bCallsA, callee: a.fullName),
                      if (result.explanation.isNotEmpty) ...[
                        const Divider(height: 24),
                        Text(result.explanation, style: theme.textTheme.bodyMedium),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PersonSlot extends StatelessWidget {
  const _PersonSlot({required this.label, required this.person, required this.onTap});

  final String label;
  final Person? person;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = person;
    return Card(
      child: ListTile(
        leading: p == null ? const Icon(Icons.person_search_outlined) : PersonAvatar(person: p),
        title: Text(p?.fullName ?? 'Chạm để chọn'),
        subtitle: Text(label),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.caller, required this.term, required this.callee});

  final String caller;
  final String term;
  final String callee;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onPrimaryContainer;
    return Text.rich(
      TextSpan(
        style: theme.textTheme.bodyLarge?.copyWith(color: color),
        children: [
          TextSpan(text: caller, style: const TextStyle(fontWeight: FontWeight.w600)),
          const TextSpan(text: ' gọi '),
          TextSpan(text: callee, style: const TextStyle(fontWeight: FontWeight.w600)),
          const TextSpan(text: ' là '),
          TextSpan(
            text: term.toLowerCase().startsWith('chưa') ? term : '“$term”',
            style: theme.textTheme.titleLarge?.copyWith(color: color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
