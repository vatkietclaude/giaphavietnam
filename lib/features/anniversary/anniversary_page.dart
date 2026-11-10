import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/lunar/lunar_calendar.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';
import '../members/person_detail_screen.dart';
import 'anniversary_logic.dart';

/// Lịch ngày giỗ theo âm lịch, quy đổi sang dương lịch cho năm hiện tại.
class AnniversaryPage extends ConsumerStatefulWidget {
  const AnniversaryPage({super.key, required this.clanId});

  final String clanId;

  @override
  ConsumerState<AnniversaryPage> createState() => _AnniversaryPageState();
}

class _AnniversaryPageState extends ConsumerState<AnniversaryPage> {
  int _range = 30;

  @override
  Widget build(BuildContext context) {
    final clan = ref.watch(clanProvider(widget.clanId));
    if (clan == null) return const SizedBox.shrink();
    final now = today();
    final items = upcomingAnniversaries(clan, from: now, withinDays: _range);
    final missing = deceasedWithoutAnniversary(clan);
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 30, label: Text('30 ngày')),
                ButtonSegment(value: 90, label: Text('3 tháng')),
                ButtonSegment(value: 366, label: Text('Cả năm')),
              ],
              selected: {_range},
              onSelectionChanged: (s) => setState(() => _range = s.first),
            ),
            OutlinedButton.icon(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => const LunarConverterDialog(),
              ),
              icon: const Icon(Icons.swap_horiz),
              label: const Text('Đổi ngày âm – dương'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (items.isEmpty)
          EmptyState(
            icon: Icons.event_available_outlined,
            title: 'Không có ngày giỗ nào trong khoảng này',
            message: missing.isEmpty
                ? 'Thêm ngày mất hoặc ngày giỗ âm lịch trong hồ sơ người đã khuất.'
                : null,
          )
        else
          for (final a in items)
            Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                leading: _DateBadge(date: a.date, urgent: a.daysLeft <= 7),
                title: Text('Giỗ ${a.person.fullName}'),
                subtitle: Text(
                  'Ngày ${a.lunar.day} tháng ${a.lunar.month} âm lịch\n'
                  '${weekdayName(a.date)}, ${formatDate(a.date)} · '
                  '${a.daysLeft == 0 ? 'Hôm nay' : 'còn ${a.daysLeft} ngày'}'
                  '${a.yearsSinceDeath != null && a.yearsSinceDeath! > 0 ? ' · mất ${a.yearsSinceDeath} năm' : ''}',
                ),
                isThreeLine: true,
                onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => PersonDetailScreen(clanId: clan.id, personId: a.person.id),
                )),
              ),
            ),
        if (missing.isNotEmpty) ...[
          const SizedBox(height: 8),
          Card(
            color: theme.colorScheme.secondaryContainer,
            child: ExpansionTile(
              leading: const Icon(Icons.info_outline),
              title: Text('${missing.length} người đã mất chưa có ngày giỗ'),
              children: [
                for (final p in missing)
                  ListTile(
                    title: Text(p.fullName),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => PersonDetailScreen(clanId: clan.id, personId: p.id),
                    )),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _DateBadge extends StatelessWidget {
  const _DateBadge({required this.date, required this.urgent});

  final DateTime date;
  final bool urgent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = urgent ? theme.colorScheme.primary : theme.colorScheme.surfaceContainerHighest;
    final fg = urgent ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface;
    return Container(
      width: 52,
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${date.day}',
              style: theme.textTheme.titleLarge?.copyWith(color: fg, fontWeight: FontWeight.w700)),
          Text('Th ${date.month}', style: theme.textTheme.labelSmall?.copyWith(color: fg)),
        ],
      ),
    );
  }
}

/// Công cụ đổi ngày dương lịch ↔ âm lịch.
class LunarConverterDialog extends StatefulWidget {
  const LunarConverterDialog({super.key});

  @override
  State<LunarConverterDialog> createState() => _LunarConverterDialogState();
}

class _LunarConverterDialogState extends State<LunarConverterDialog> {
  DateTime _solar = today();
  late int _lDay;
  late int _lMonth;
  late int _lYear;
  bool _leap = false;

  @override
  void initState() {
    super.initState();
    final l = LunarCalendar.fromSolar(_solar);
    _lDay = l.day;
    _lMonth = l.month;
    _lYear = l.year;
  }

  Future<void> _pickSolar() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _solar,
      firstDate: DateTime(1800),
      lastDate: DateTime(2199, 12, 31),
    );
    if (picked != null && mounted) setState(() => _solar = picked);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lunar = LunarCalendar.fromSolar(_solar);
    final solarFromLunar = LunarCalendar.toSolar(
      LunarDate(day: _lDay, month: _lMonth, year: _lYear, isLeapMonth: _leap),
    );
    return AlertDialog(
      title: const Text('Đổi ngày âm – dương'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Dương lịch → Âm lịch', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _pickSolar,
                icon: const Icon(Icons.calendar_month_outlined),
                label: Text('${weekdayName(_solar)}, ${formatDate(_solar)}'),
              ),
              const SizedBox(height: 6),
              Text('${formatLunar(lunar)}\nNgày ${LunarCalendar.dayCanChi(_solar)}, '
                  'tháng ${LunarCalendar.monthCanChi(lunar)}'),
              const Divider(height: 32),
              Text('Âm lịch → Dương lịch', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _lDay,
                      decoration: const InputDecoration(labelText: 'Ngày', isDense: true),
                      items: [
                        for (var d = 1; d <= 30; d++) DropdownMenuItem(value: d, child: Text('$d')),
                      ],
                      onChanged: (v) => setState(() => _lDay = v ?? _lDay),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _lMonth,
                      decoration: const InputDecoration(labelText: 'Tháng', isDense: true),
                      items: [
                        for (var m = 1; m <= 12; m++) DropdownMenuItem(value: m, child: Text('$m')),
                      ],
                      onChanged: (v) => setState(() => _lMonth = v ?? _lMonth),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      initialValue: '$_lYear',
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Năm', isDense: true),
                      onChanged: (v) {
                        final y = int.tryParse(v);
                        if (y != null && y > 1800 && y < 2200) setState(() => _lYear = y);
                      },
                    ),
                  ),
                ],
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _leap,
                title: const Text('Tháng nhuận'),
                onChanged: (v) => setState(() => _leap = v ?? false),
              ),
              Text(
                solarFromLunar == null
                    ? 'Năm ${LunarCalendar.yearCanChi(_lYear)} không có tháng nhuận này.'
                    : 'Năm ${LunarCalendar.yearCanChi(_lYear)}: '
                        '${weekdayName(solarFromLunar)}, ${formatDate(solarFromLunar)}',
                style: theme.textTheme.bodyLarge,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Đóng')),
      ],
    );
  }
}
