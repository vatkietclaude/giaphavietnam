import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../core/lunar/lunar_calendar.dart';
import '../../data/clan_repository.dart';
import '../../data/family_graph.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';
import '../anniversary/anniversary_logic.dart';
import '../clan/clan_workspace.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _open(BuildContext context, String clanId) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => ClanWorkspace(clanId: clanId)),
    );
  }

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<_NewClanData>(
      context: context,
      builder: (_) => const _NewClanDialog(),
    );
    if (result == null || !context.mounted) return;
    final id = await ref.read(clansProvider.notifier).createClan(
          name: result.name,
          founderName: result.founderName,
          founderGender: result.gender,
          origin: result.origin,
        );
    if (!context.mounted) return;
    await _open(context, id);
  }

  Future<void> _openSample(BuildContext context, WidgetRef ref) async {
    final id = await ref.read(clansProvider.notifier).addSample();
    if (!context.mounted) return;
    await _open(context, id);
  }

  Future<void> _restore(BuildContext context, WidgetRef ref) async {
    final text = await showDialog<String>(
      context: context,
      builder: (_) => const _RestoreDialog(),
    );
    if (text == null || text.trim().isEmpty || !context.mounted) return;
    Clan clan;
    try {
      clan = ClanRepository.importClan(text);
    } catch (e) {
      showMessage(context, 'Bản sao lưu không hợp lệ: ${e is FormatException ? e.message : e}');
      return;
    }
    final id = await ref.read(clansProvider.notifier).importClan(clan);
    if (!context.mounted) return;
    showMessage(context, 'Đã khôi phục "${clan.name}" (${clan.members.length} thành viên)');
    await _open(context, id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clans = ref.watch(clansProvider);
    final theme = Theme.of(context);
    final upcoming = <(Clan, Anniversary)>[];
    for (final clan in clans) {
      for (final a in upcomingAnniversaries(clan, from: today(), withinDays: 30)) {
        upcoming.add((clan, a));
      }
    }
    upcoming.sort((a, b) => a.$2.date.compareTo(b.$2.date));

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.account_tree_outlined),
            SizedBox(width: 10),
            Text(GiaPhaApp.title),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Khôi phục từ bản sao lưu',
            icon: const Icon(Icons.restore_page_outlined),
            onPressed: () => _restore(context, ref),
          ),
          IconButton(
            tooltip: 'Giới thiệu',
            icon: const Icon(Icons.info_outline),
            onPressed: () => showAboutDialog(
              context: context,
              applicationName: GiaPhaApp.title,
              applicationVersion: '1.0.0',
              children: const [
                Text('Ứng dụng gia phả chạy trên web và điện thoại. '
                    'Dữ liệu được lưu ngay trên thiết bị của bạn; hãy sao lưu '
                    'định kỳ trong mục Dòng họ.'),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: clans.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _create(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Tạo gia phả'),
            ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              const _TodayCard(),
              const SizedBox(height: 16),
              if (clans.isEmpty)
                Card(
                  child: EmptyState(
                    icon: Icons.park_outlined,
                    title: 'Bắt đầu ghi chép gia phả của dòng họ bạn',
                    message: 'Tạo cây gia phả nhiều đời, ghi nhớ ngày giỗ theo âm lịch, '
                        'tra cứu cách xưng hô và lưu phả ký – tất cả trong một ứng dụng.',
                    action: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      alignment: WrapAlignment.center,
                      children: [
                        FilledButton.icon(
                          onPressed: () => _create(context, ref),
                          icon: const Icon(Icons.add),
                          label: const Text('Tạo gia phả mới'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _openSample(context, ref),
                          icon: const Icon(Icons.visibility_outlined),
                          label: const Text('Xem gia phả mẫu'),
                        ),
                      ],
                    ),
                  ),
                )
              else ...[
                if (upcoming.isNotEmpty) ...[
                  SectionCard(
                    title: 'Ngày giỗ sắp tới (30 ngày)',
                    child: Column(
                      children: [
                        for (final (clan, a) in upcoming.take(5))
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.local_fire_department_outlined),
                            title: Text('Giỗ ${a.person.fullName}'),
                            subtitle: Text('${weekdayName(a.date)}, ${formatDate(a.date)} · '
                                '${a.daysLeft == 0 ? 'Hôm nay' : 'còn ${a.daysLeft} ngày'}'
                                '${clans.length > 1 ? ' · ${clan.name}' : ''}'),
                            onTap: () => _open(context, clan.id),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                Text('Gia phả của bạn', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                for (final clan in clans) ...[
                  _ClanCard(clan: clan, onTap: () => _open(context, clan.id)),
                  const SizedBox(height: 12),
                ],
                if (!clans.any((c) => c.id == 'sample-nguyen'))
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton.icon(
                      onPressed: () => _openSample(context, ref),
                      icon: const Icon(Icons.visibility_outlined),
                      label: const Text('Xem gia phả mẫu'),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TodayCard extends StatelessWidget {
  const _TodayCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = today();
    final lunar = LunarCalendar.fromSolar(now);
    return Card(
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 64,
              height: 64,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${lunar.day}',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: theme.colorScheme.onPrimary,
                        fontWeight: FontWeight.w700,
                      )),
                  Text('tháng ${lunar.month}',
                      style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onPrimary)),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${weekdayName(now)}, ${formatDate(now)}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                      )),
                  const SizedBox(height: 4),
                  Text(
                    'Âm lịch: ${formatLunar(lunar)}\n'
                    'Ngày ${LunarCalendar.dayCanChi(now)} · tháng ${LunarCalendar.monthCanChi(lunar)}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
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

class _ClanCard extends StatelessWidget {
  const _ClanCard({required this.clan, required this.onTap});

  final Clan clan;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final graph = FamilyGraph(clan);
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: theme.colorScheme.secondaryContainer,
                child: Icon(Icons.account_tree, color: theme.colorScheme.onSecondaryContainer),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(clan.name, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      '${clan.members.length} thành viên · ${graph.generationCount} đời'
                      '${clan.origin.isEmpty ? '' : ' · ${clan.origin}'}',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _NewClanData {
  const _NewClanData(this.name, this.founderName, this.gender, this.origin);

  final String name;
  final String founderName;
  final Gender gender;
  final String origin;
}

class _NewClanDialog extends StatefulWidget {
  const _NewClanDialog();

  @override
  State<_NewClanDialog> createState() => _NewClanDialogState();
}

class _NewClanDialogState extends State<_NewClanDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _founder = TextEditingController();
  final _origin = TextEditingController();
  Gender _gender = Gender.male;

  @override
  void dispose() {
    _name.dispose();
    _founder.dispose();
    _origin.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      _NewClanData(_name.text.trim(), _founder.text.trim(), _gender, _origin.text.trim()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Tạo gia phả mới'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _name,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Tên gia phả',
                    hintText: 'VD: Họ Trần – chi trưởng',
                  ),
                  validator: (v) => (v ?? '').trim().isEmpty ? 'Hãy nhập tên gia phả' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _founder,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Họ tên thủy tổ / người đầu tiên',
                    helperText: 'Có thể thêm các đời trên sau',
                  ),
                  validator: (v) => (v ?? '').trim().isEmpty ? 'Hãy nhập họ tên' : null,
                ),
                const SizedBox(height: 12),
                SegmentedButton<Gender>(
                  segments: const [
                    ButtonSegment(value: Gender.male, label: Text('Nam'), icon: Icon(Icons.male)),
                    ButtonSegment(value: Gender.female, label: Text('Nữ'), icon: Icon(Icons.female)),
                  ],
                  selected: {_gender},
                  onSelectionChanged: (s) => setState(() => _gender = s.first),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _origin,
                  decoration: const InputDecoration(labelText: 'Quê gốc (không bắt buộc)'),
                  onFieldSubmitted: (_) => _submit(),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
        FilledButton(onPressed: _submit, child: const Text('Tạo')),
      ],
    );
  }
}

class _RestoreDialog extends StatefulWidget {
  const _RestoreDialog();

  @override
  State<_RestoreDialog> createState() => _RestoreDialogState();
}

class _RestoreDialogState extends State<_RestoreDialog> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Khôi phục gia phả'),
      content: SizedBox(
        width: 480,
        child: TextField(
          controller: _text,
          minLines: 6,
          maxLines: 12,
          decoration: const InputDecoration(
            hintText: 'Dán nội dung bản sao lưu (bắt đầu bằng {"format": "giaphavietnam"…) vào đây',
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
        FilledButton(
          onPressed: () => Navigator.pop(context, _text.text),
          child: const Text('Khôi phục'),
        ),
      ],
    );
  }
}
