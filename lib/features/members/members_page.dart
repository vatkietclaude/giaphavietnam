import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/family_graph.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';
import 'person_detail_screen.dart';
import 'person_form_screen.dart';

enum _StatusFilter { all, living, deceased }

/// Danh sách thành viên dạng bảng: tìm kiếm, lọc giới tính, tình trạng, đời.
class MembersPage extends ConsumerStatefulWidget {
  const MembersPage({super.key, required this.clanId});

  final String clanId;

  @override
  ConsumerState<MembersPage> createState() => _MembersPageState();
}

class _MembersPageState extends ConsumerState<MembersPage> {
  String _query = '';
  Gender? _gender;
  _StatusFilter _status = _StatusFilter.all;
  int? _generation;
  bool _hideInLaws = false;

  @override
  Widget build(BuildContext context) {
    final graph = ref.watch(graphProvider(widget.clanId));
    if (graph == null) return const SizedBox.shrink();
    final q = foldVietnamese(_query.trim());
    final people = graph.people.values.where((p) {
      if (_gender != null && p.gender != _gender) return false;
      if (_status == _StatusFilter.living && p.isDeceased) return false;
      if (_status == _StatusFilter.deceased && !p.isDeceased) return false;
      if (_generation != null && graph.generationOf(p.id) != _generation) return false;
      if (_hideInLaws && p.isInLaw) return false;
      if (q.isNotEmpty &&
          !foldVietnamese(p.fullName).contains(q) &&
          !foldVietnamese(p.nickname).contains(q) &&
          !foldVietnamese(p.title).contains(q)) {
        return false;
      }
      return true;
    }).toList()
      ..sort((a, b) {
        final g = graph.generationOf(a.id).compareTo(graph.generationOf(b.id));
        return g != 0 ? g : FamilyGraph.compareSiblings(a, b);
      });

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add-member',
        onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => PersonFormScreen(clanId: widget.clanId),
        )),
        icon: const Icon(Icons.person_add_alt),
        label: const Text('Thêm người'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Tìm theo tên, tên húy, chức danh…',
                isDense: true,
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                _chip('Nam', _gender == Gender.male,
                    () => setState(() => _gender = _gender == Gender.male ? null : Gender.male)),
                _chip('Nữ', _gender == Gender.female,
                    () => setState(() => _gender = _gender == Gender.female ? null : Gender.female)),
                const SizedBox(width: 8),
                _chip('Còn sống', _status == _StatusFilter.living, () => setState(() {
                      _status = _status == _StatusFilter.living ? _StatusFilter.all : _StatusFilter.living;
                    })),
                _chip('Đã mất', _status == _StatusFilter.deceased, () => setState(() {
                      _status = _status == _StatusFilter.deceased ? _StatusFilter.all : _StatusFilter.deceased;
                    })),
                const SizedBox(width: 8),
                _chip('Ẩn dâu/rể', _hideInLaws, () => setState(() => _hideInLaws = !_hideInLaws)),
                const SizedBox(width: 8),
                DropdownButton<int?>(
                  value: _generation,
                  hint: const Text('Mọi đời'),
                  underline: const SizedBox.shrink(),
                  items: [
                    const DropdownMenuItem<int?>(value: null, child: Text('Mọi đời')),
                    for (var g = 1; g <= graph.generationCount; g++)
                      DropdownMenuItem<int?>(value: g, child: Text('Đời $g')),
                  ],
                  onChanged: (v) => setState(() => _generation = v),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text('${people.length} / ${graph.people.length} thành viên',
                  style: Theme.of(context).textTheme.labelMedium),
            ),
          ),
          Expanded(
            child: people.isEmpty
                ? const EmptyState(icon: Icons.search_off, title: 'Không có thành viên phù hợp')
                : ListView.separated(
                    padding: const EdgeInsets.only(bottom: 96),
                    itemCount: people.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
                    itemBuilder: (context, i) {
                      final p = people[i];
                      final parts = <String>[
                        'Đời ${graph.generationOf(p.id)}',
                        if (p.lifeSpan.isNotEmpty) p.lifeSpan,
                        if (p.isInLaw) p.isMale ? 'Rể' : 'Dâu',
                        if (graph.parentageLabel(p).isNotEmpty) graph.parentageLabel(p),
                      ];
                      return ListTile(
                        leading: PersonAvatar(person: p),
                        title: Text(
                          p.title.isEmpty ? p.fullName : '${p.fullName} · ${p.title}',
                        ),
                        subtitle: Text(parts.join(' · ')),
                        trailing: p.isDeceased
                            ? const Tooltip(message: 'Đã mất', child: Icon(Icons.local_florist_outlined))
                            : null,
                        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                          builder: (_) => PersonDetailScreen(clanId: widget.clanId, personId: p.id),
                        )),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 6),
      child: FilterChip(label: Text(label), selected: selected, onSelected: (_) => onTap()),
    );
  }
}
