import 'package:flutter/material.dart';

import '../core/lunar/lunar_calendar.dart';
import '../data/family_graph.dart';
import '../data/models.dart';
import '../theme.dart';

const _weekdays = ['Thứ Hai', 'Thứ Ba', 'Thứ Tư', 'Thứ Năm', 'Thứ Sáu', 'Thứ Bảy', 'Chủ Nhật'];

String weekdayName(DateTime d) => _weekdays[d.weekday - 1];

String formatDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

String formatLunar(LunarDate l, {bool withYear = true}) {
  final leap = l.isLeapMonth ? ' (nhuận)' : '';
  final year = withYear ? ' năm ${LunarCalendar.yearCanChi(l.year)}' : '';
  return 'Ngày ${l.day} tháng ${l.month}$leap$year';
}

DateTime today() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

/// Ảnh đại diện chữ cái đầu, màu + biểu tượng theo giới tính.
class PersonAvatar extends StatelessWidget {
  const PersonAvatar({super.key, required this.person, this.radius = 20});

  final Person person;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final color = genderColor(context, person.isMale);
    return Semantics(
      label: person.isMale ? 'Nam' : 'Nữ',
      child: CircleAvatar(
        radius: radius,
        backgroundColor: color.withValues(alpha: person.isDeceased ? 0.12 : 0.18),
        foregroundColor: color,
        child: Text(
          person.initials,
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: radius * 0.8),
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(title, style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(message!, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
            ],
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    );
  }
}

/// Khối nội dung có tiêu đề.
class SectionCard extends StatelessWidget {
  const SectionCard({super.key, required this.title, required this.child, this.trailing});

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

class InfoRow extends StatelessWidget {
  const InfoRow({super.key, required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          SizedBox(
            width: 120,
            child: Text(label, style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            )),
          ),
          Expanded(child: SelectableText(value, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

void showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Hộp thoại xác nhận; trả về `true` khi người dùng đồng ý.
Future<bool> confirm(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Đồng ý',
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                )
              : null,
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Bỏ dấu tiếng Việt để tìm kiếm không phân biệt dấu.
String foldVietnamese(String input) {
  const groups = {
    'a': 'àáạảãâầấậẩẫăằắặẳẵ',
    'e': 'èéẹẻẽêềếệểễ',
    'i': 'ìíịỉĩ',
    'o': 'òóọỏõôồốộổỗơờớợởỡ',
    'u': 'ùúụủũưừứựửữ',
    'y': 'ỳýỵỷỹ',
    'd': 'đ',
  };
  final buffer = StringBuffer();
  for (final rune in input.toLowerCase().runes) {
    final ch = String.fromCharCode(rune);
    var mapped = ch;
    for (final entry in groups.entries) {
      if (entry.value.contains(ch)) {
        mapped = entry.key;
        break;
      }
    }
    buffer.write(mapped);
  }
  return buffer.toString();
}

/// Hộp thoại chọn một người trong gia phả, có ô tìm kiếm.
Future<Person?> pickPerson(
  BuildContext context,
  FamilyGraph graph, {
  String title = 'Chọn thành viên',
  bool Function(Person)? filter,
}) {
  return showDialog<Person>(
    context: context,
    builder: (context) => _PersonPickerDialog(graph: graph, title: title, filter: filter),
  );
}

class _PersonPickerDialog extends StatefulWidget {
  const _PersonPickerDialog({required this.graph, required this.title, this.filter});

  final FamilyGraph graph;
  final String title;
  final bool Function(Person)? filter;

  @override
  State<_PersonPickerDialog> createState() => _PersonPickerDialogState();
}

class _PersonPickerDialogState extends State<_PersonPickerDialog> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final q = foldVietnamese(_query.trim());
    final people = widget.graph.people.values
        .where((p) => widget.filter?.call(p) ?? true)
        .where((p) =>
            q.isEmpty ||
            foldVietnamese(p.fullName).contains(q) ||
            foldVietnamese(p.nickname).contains(q))
        .toList()
      ..sort((a, b) {
        final g = widget.graph.generationOf(a.id).compareTo(widget.graph.generationOf(b.id));
        return g != 0 ? g : FamilyGraph.compareSiblings(a, b);
      });
    return AlertDialog(
      title: Text(widget.title),
      contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      content: SizedBox(
        width: 420,
        height: 480,
        child: Column(
          children: [
            TextField(
              autofocus: true,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Tìm theo tên (có thể gõ không dấu)',
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: people.isEmpty
                  ? const Center(child: Text('Không tìm thấy ai'))
                  : ListView.builder(
                      itemCount: people.length,
                      itemBuilder: (context, i) {
                        final p = people[i];
                        return ListTile(
                          leading: PersonAvatar(person: p, radius: 18),
                          title: Text(p.fullName),
                          subtitle: Text(
                            'Đời ${widget.graph.generationOf(p.id)}'
                            '${p.lifeSpan.isEmpty ? '' : ' · ${p.lifeSpan}'}',
                          ),
                          onTap: () => Navigator.pop(context, p),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Đóng')),
      ],
    );
  }
}
