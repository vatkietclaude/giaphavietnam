import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/lunar/lunar_calendar.dart';
import '../../data/family_graph.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';
import 'person_form_screen.dart';

/// Hồ sơ chi tiết một thành viên và các quan hệ trực tiếp.
class PersonDetailScreen extends ConsumerWidget {
  const PersonDetailScreen({super.key, required this.clanId, required this.personId});

  final String clanId;
  final String personId;

  void _openForm(
    BuildContext context, {
    Person? existing,
    NewRelation relation = NewRelation.none,
  }) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => PersonFormScreen(
        clanId: clanId,
        existing: existing,
        relation: relation,
        anchorId: relation == NewRelation.none ? null : personId,
      ),
    ));
  }

  void _openPerson(BuildContext context, String id) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => PersonDetailScreen(clanId: clanId, personId: id),
    ));
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Person person, FamilyGraph graph) async {
    final children = graph.childrenOf(person.id).length;
    final ok = await confirm(
      context,
      title: 'Xóa ${person.fullName}?',
      message: children > 0
          ? 'Người này có $children người con. Các con vẫn được giữ lại nhưng sẽ không còn nối với cha/mẹ này.'
          : 'Thao tác này không thể hoàn tác.',
      confirmLabel: 'Xóa',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    await ref.read(clansProvider.notifier).deletePerson(clanId, person.id);
    if (!context.mounted) return;
    Navigator.of(context).pop();
    showMessage(context, 'Đã xóa ${person.fullName}');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final graph = ref.watch(graphProvider(clanId));
    final person = graph?[personId];
    if (graph == null || person == null) {
      return Scaffold(appBar: AppBar(), body: const Center(child: Text('Không tìm thấy thành viên.')));
    }
    final theme = Theme.of(context);
    final father = graph[person.fatherId];
    final mother = graph[person.motherId];
    final spouses = graph.spousesOf(person.id);
    final children = graph.childrenOf(person.id);
    final siblings = <Person>{
      if (father != null) ...graph.childrenOf(father.id),
      if (mother != null) ...graph.childrenOf(mother.id),
    }.where((p) => p.id != person.id).toList()
      ..sort(FamilyGraph.compareSiblings);
    final gio = person.effectiveAnniversary;
    final nextGio = gio == null ? null : LunarCalendar.nextAnniversary(gio.day, gio.month, today());

    String lunarOf(PartialDate d) {
      final dt = d.toDateTime();
      if (dt == null) return '';
      return ' (âm lịch: ${formatLunar(LunarCalendar.fromSolar(dt))})';
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(person.fullName),
        actions: [
          IconButton(
            tooltip: 'Sửa thông tin',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => _openForm(context, existing: person),
          ),
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'delete') await _delete(context, ref, person, graph);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'delete', child: Text('Xóa thành viên')),
            ],
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  PersonAvatar(person: person, radius: 36),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(person.fullName, style: theme.textTheme.headlineSmall),
                        if (person.nickname.isNotEmpty)
                          Text('Tên khác: ${person.nickname}', style: theme.textTheme.bodyMedium),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            Chip(
                              avatar: Icon(person.isMale ? Icons.male : Icons.female, size: 18),
                              label: Text(person.gender.label),
                            ),
                            Chip(label: Text('Đời ${graph.generationOf(person.id)}')),
                            if (person.birthOrder != null) Chip(label: Text('Con thứ ${person.birthOrder}')),
                            if (person.isInLaw) Chip(label: Text(person.isMale ? 'Con rể' : 'Con dâu')),
                            if (person.title.isNotEmpty) Chip(label: Text(person.title)),
                            if (person.isDeceased) const Chip(label: Text('Đã mất')),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: () => _openForm(context, relation: NewRelation.child),
                    icon: const Icon(Icons.child_care),
                    label: const Text('Thêm con'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () => _openForm(context, relation: NewRelation.spouse),
                    icon: const Icon(Icons.favorite_border),
                    label: Text(person.isMale ? 'Thêm vợ' : 'Thêm chồng'),
                  ),
                  if (father == null)
                    FilledButton.tonalIcon(
                      onPressed: () => _openForm(context, relation: NewRelation.father),
                      icon: const Icon(Icons.arrow_upward),
                      label: const Text('Thêm bố'),
                    ),
                  if (mother == null)
                    FilledButton.tonalIcon(
                      onPressed: () => _openForm(context, relation: NewRelation.mother),
                      icon: const Icon(Icons.arrow_upward),
                      label: const Text('Thêm mẹ'),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              SectionCard(
                title: 'Thông tin',
                child: Column(
                  children: [
                    InfoRow(
                      icon: Icons.cake_outlined,
                      label: 'Ngày sinh',
                      value: person.birth.isEmpty ? '' : '${person.birth.format()}${lunarOf(person.birth)}',
                    ),
                    if (person.isDeceased)
                      InfoRow(
                        icon: Icons.local_florist_outlined,
                        label: 'Ngày mất',
                        value: person.death.isEmpty
                            ? 'Chưa rõ'
                            : '${person.death.format()}${lunarOf(person.death)}',
                      ),
                    if (gio != null)
                      InfoRow(
                        icon: Icons.event_outlined,
                        label: 'Ngày giỗ',
                        value: 'Ngày ${gio.day} tháng ${gio.month} âm lịch'
                            '${nextGio == null ? '' : '\nLần tới: ${weekdayName(nextGio)}, ${formatDate(nextGio)}'}',
                      ),
                    InfoRow(icon: Icons.place_outlined, label: 'Nơi an táng', value: person.burialPlace),
                    InfoRow(icon: Icons.work_outline, label: 'Nghề nghiệp', value: person.occupation),
                    InfoRow(icon: Icons.home_outlined, label: 'Địa chỉ', value: person.address),
                    InfoRow(icon: Icons.phone_outlined, label: 'Điện thoại', value: person.phone),
                  ],
                ),
              ),
              if (person.biography.isNotEmpty) ...[
                const SizedBox(height: 12),
                SectionCard(
                  title: 'Tiểu sử',
                  child: SelectableText(person.biography, style: theme.textTheme.bodyMedium),
                ),
              ],
              const SizedBox(height: 12),
              SectionCard(
                title: 'Quan hệ gia đình',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _RelationGroup(
                      label: 'Bố mẹ',
                      people: [if (father != null) father, if (mother != null) mother],
                      graph: graph,
                      onTap: (id) => _openPerson(context, id),
                    ),
                    _RelationGroup(
                      label: person.isMale ? 'Vợ' : 'Chồng',
                      people: spouses,
                      graph: graph,
                      numbered: spouses.length > 1,
                      onTap: (id) => _openPerson(context, id),
                    ),
                    _RelationGroup(
                      label: 'Anh chị em',
                      people: siblings,
                      graph: graph,
                      onTap: (id) => _openPerson(context, id),
                    ),
                    _RelationGroup(
                      label: 'Con',
                      people: children,
                      graph: graph,
                      showMother: person.isMale && spouses.length > 1,
                      onTap: (id) => _openPerson(context, id),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RelationGroup extends StatelessWidget {
  const _RelationGroup({
    required this.label,
    required this.people,
    required this.graph,
    required this.onTap,
    this.numbered = false,
    this.showMother = false,
  });

  final String label;
  final List<Person> people;
  final FamilyGraph graph;
  final ValueChanged<String> onTap;
  final bool numbered;
  final bool showMother;

  @override
  Widget build(BuildContext context) {
    if (people.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelLarge),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < people.length; i++)
                ActionChip(
                  avatar: PersonAvatar(person: people[i], radius: 12),
                  label: Text(_label(people[i], i)),
                  onPressed: () => onTap(people[i].id),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _label(Person p, int index) {
    final buffer = StringBuffer();
    if (numbered) buffer.write(index == 0 ? 'Cả: ' : 'Thứ ${index + 1}: ');
    buffer.write(p.fullName);
    if (p.lifeSpan.isNotEmpty) buffer.write(' (${p.lifeSpan})');
    if (showMother) {
      final mother = graph[p.motherId];
      if (mother != null) buffer.write(' – mẹ: ${mother.fullName}');
    }
    return buffer.toString();
  }
}
