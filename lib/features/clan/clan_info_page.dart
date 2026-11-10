import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/clan_repository.dart';
import '../../data/csv_export.dart';
import '../../data/family_graph.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';

/// Thông tin dòng họ (phả ký, tộc ước, nhà thờ họ), thống kê và sao lưu.
class ClanInfoPage extends ConsumerWidget {
  const ClanInfoPage({super.key, required this.clanId});

  final String clanId;

  Future<void> _edit(BuildContext context, WidgetRef ref, Clan clan) async {
    final updated = await Navigator.of(context).push<Clan>(MaterialPageRoute(
      builder: (_) => _ClanEditScreen(clan: clan),
    ));
    if (updated == null) return;
    await ref.read(clansProvider.notifier).updateClanInfo(updated);
    if (context.mounted) showMessage(context, 'Đã lưu thông tin dòng họ');
  }

  Future<void> _copy(BuildContext context, String text, String message) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) showMessage(context, message);
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Clan clan) async {
    final ok = await confirm(
      context,
      title: 'Xóa gia phả "${clan.name}"?',
      message: 'Toàn bộ ${clan.members.length} thành viên sẽ bị xóa khỏi thiết bị. '
          'Hãy sao lưu trước nếu cần.',
      confirmLabel: 'Xóa vĩnh viễn',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    final notifier = ref.read(clansProvider.notifier);
    Navigator.of(context).popUntil((r) => r.isFirst);
    await notifier.deleteClan(clan.id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final graph = ref.watch(graphProvider(clanId));
    if (graph == null) return const SizedBox.shrink();
    final clan = graph.clan;
    final theme = Theme.of(context);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _StatsSection(graph: graph),
            const SizedBox(height: 12),
            SectionCard(
              title: 'Thông tin dòng họ',
              trailing: TextButton.icon(
                onPressed: () => _edit(context, ref, clan),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Sửa'),
              ),
              child: Column(
                children: [
                  InfoRow(icon: Icons.badge_outlined, label: 'Tên gia phả', value: clan.name),
                  InfoRow(icon: Icons.landscape_outlined, label: 'Quê gốc', value: clan.origin),
                  InfoRow(icon: Icons.temple_buddhist_outlined, label: 'Nhà thờ họ', value: clan.ancestralHall),
                  if (clan.origin.isEmpty && clan.ancestralHall.isEmpty)
                    Text('Chưa có thông tin. Bấm "Sửa" để thêm quê gốc, nhà thờ họ.',
                        style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SectionCard(
              title: 'Phả ký – lịch sử dòng họ',
              child: SelectableText(
                clan.history.isEmpty ? 'Chưa có phả ký.' : clan.history,
                style: theme.textTheme.bodyMedium,
              ),
            ),
            const SizedBox(height: 12),
            SectionCard(
              title: 'Tộc ước',
              child: SelectableText(
                clan.rules.isEmpty ? 'Chưa có tộc ước.' : clan.rules,
                style: theme.textTheme.bodyMedium,
              ),
            ),
            const SizedBox(height: 12),
            SectionCard(
              title: 'Sao lưu & xuất dữ liệu',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dữ liệu được lưu trên thiết bị này. Hãy sao lưu định kỳ và giữ bản '
                    'sao lưu ở nơi an toàn (email, Google Drive, Zalo…).',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: () => _copy(context, ClanRepository.exportClan(clan),
                            'Đã sao chép bản sao lưu. Dán vào ghi chú/email để cất giữ.'),
                        icon: const Icon(Icons.backup_outlined),
                        label: const Text('Sao chép bản sao lưu'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: () => _copy(context, exportMembersCsv(graph),
                            'Đã sao chép bảng thành viên. Dán vào Excel hoặc Google Sheets.'),
                        icon: const Icon(Icons.table_chart_outlined),
                        label: const Text('Sao chép bảng (Excel)'),
                      ),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(foregroundColor: theme.colorScheme.error),
                        onPressed: () => _delete(context, ref, clan),
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Xóa gia phả'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsSection extends StatelessWidget {
  const _StatsSection({required this.graph});

  final FamilyGraph graph;

  @override
  Widget build(BuildContext context) {
    final people = graph.people.values;
    final male = people.where((p) => p.isMale).length;
    final deceased = people.where((p) => p.isDeceased).length;
    final inLaws = people.where((p) => p.isInLaw).length;
    final perGen = graph.membersPerGeneration();
    final maxCount = perGen.values.fold<int>(1, (a, b) => a > b ? a : b);
    final theme = Theme.of(context);

    Widget stat(String label, String value, IconData icon) => SizedBox(
          width: 150,
          child: Card(
            margin: EdgeInsets.zero,
            color: theme.colorScheme.surfaceContainerHigh,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, color: theme.colorScheme.primary),
                  const SizedBox(height: 6),
                  Text(value, style: theme.textTheme.headlineSmall),
                  Text(label, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ),
        );

    return SectionCard(
      title: 'Thống kê',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              stat('Thành viên', '${people.length}', Icons.people_outline),
              stat('Số đời', '${graph.generationCount}', Icons.layers_outlined),
              stat('Nam / Nữ', '$male / ${people.length - male}', Icons.wc),
              stat('Còn sống / Đã mất', '${people.length - deceased} / $deceased', Icons.favorite_outline),
              stat('Dâu, rể', '$inLaws', Icons.diversity_1_outlined),
            ],
          ),
          const SizedBox(height: 16),
          Text('Số người theo từng đời', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          for (final entry in perGen.entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  SizedBox(width: 64, child: Text('Đời ${entry.key}')),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: entry.value / maxCount,
                        minHeight: 14,
                        semanticsLabel: 'Đời ${entry.key}',
                        semanticsValue: '${entry.value} người',
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 48,
                    child: Text('${entry.value}', textAlign: TextAlign.end),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ClanEditScreen extends StatefulWidget {
  const _ClanEditScreen({required this.clan});

  final Clan clan;

  @override
  State<_ClanEditScreen> createState() => _ClanEditScreenState();
}

class _ClanEditScreenState extends State<_ClanEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.clan.name);
  late final _origin = TextEditingController(text: widget.clan.origin);
  late final _hall = TextEditingController(text: widget.clan.ancestralHall);
  late final _history = TextEditingController(text: widget.clan.history);
  late final _rules = TextEditingController(text: widget.clan.rules);

  @override
  void dispose() {
    for (final c in [_name, _origin, _hall, _history, _rules]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      widget.clan.copyWith(
        name: _name.text.trim(),
        origin: _origin.text.trim(),
        ancestralHall: _hall.text.trim(),
        history: _history.text.trim(),
        rules: _rules.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thông tin dòng họ'),
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: FilledButton(onPressed: _save, child: const Text('Lưu')),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Tên gia phả *'),
                  validator: (v) => (v ?? '').trim().isEmpty ? 'Hãy nhập tên' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _origin,
                  decoration: const InputDecoration(labelText: 'Quê gốc / nguyên quán'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _hall,
                  decoration: const InputDecoration(labelText: 'Địa chỉ nhà thờ họ (từ đường)'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _history,
                  minLines: 5,
                  maxLines: 20,
                  decoration: const InputDecoration(
                    labelText: 'Phả ký – lịch sử dòng họ',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _rules,
                  minLines: 4,
                  maxLines: 20,
                  decoration: const InputDecoration(
                    labelText: 'Tộc ước',
                    alignLabelWithHint: true,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
