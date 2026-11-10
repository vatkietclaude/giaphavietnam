import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/lunar/lunar_calendar.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';

/// Thêm mới hoặc sửa thông tin một thành viên.
class PersonFormScreen extends ConsumerStatefulWidget {
  const PersonFormScreen({
    super.key,
    required this.clanId,
    this.existing,
    this.relation = NewRelation.none,
    this.anchorId,
  });

  final String clanId;
  final Person? existing;
  final NewRelation relation;
  final String? anchorId;

  @override
  ConsumerState<PersonFormScreen> createState() => _PersonFormScreenState();
}

class _PersonFormScreenState extends ConsumerState<PersonFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _nickname;
  late final TextEditingController _birth;
  late final TextEditingController _death;
  late final TextEditingController _order;
  late final TextEditingController _title;
  late final TextEditingController _occupation;
  late final TextEditingController _address;
  late final TextEditingController _phone;
  late final TextEditingController _burial;
  late final TextEditingController _bio;
  late Gender _gender;
  late bool _deceased;
  int? _gioDay;
  int? _gioMonth;
  String? _otherParentId;
  bool _saving = false;

  Person? get _anchor {
    final clan = ref.read(clanProvider(widget.clanId));
    return widget.anchorId == null ? null : clan?.members[widget.anchorId];
  }

  @override
  void initState() {
    super.initState();
    final p = widget.existing;
    final anchor = _anchor;
    _name = TextEditingController(text: p?.fullName ?? _suggestedSurname(anchor));
    _nickname = TextEditingController(text: p?.nickname ?? '');
    _birth = TextEditingController(text: p?.birth.format() ?? '');
    _death = TextEditingController(text: p?.death.format() ?? '');
    _title = TextEditingController(text: p?.title ?? '');
    _occupation = TextEditingController(text: p?.occupation ?? '');
    _address = TextEditingController(text: p?.address ?? '');
    _phone = TextEditingController(text: p?.phone ?? '');
    _burial = TextEditingController(text: p?.burialPlace ?? '');
    _bio = TextEditingController(text: p?.biography ?? '');
    _deceased = p?.isDeceased ?? false;
    _gioDay = p?.deathAnniversary?.day;
    _gioMonth = p?.deathAnniversary?.month;

    _gender = p?.gender ??
        switch (widget.relation) {
          NewRelation.father => Gender.male,
          NewRelation.mother => Gender.female,
          NewRelation.spouse =>
            (anchor?.isMale ?? true) ? Gender.female : Gender.male,
          _ => Gender.male,
        };

    var order = p?.birthOrder;
    if (p == null && widget.relation == NewRelation.child && anchor != null) {
      final clan = ref.read(clanProvider(widget.clanId));
      final existingChildren = clan?.members.values
              .where((c) => c.fatherId == anchor.id || c.motherId == anchor.id)
              .length ??
          0;
      order = existingChildren + 1;
      final spouses = anchor.spouseIds.where((s) => clan?.members[s] != null).toList();
      _otherParentId = spouses.isEmpty ? null : spouses.first;
    }
    _order = TextEditingController(text: order?.toString() ?? '');
  }

  /// Gợi ý họ cho con theo họ của cha (hoặc mẹ nếu là con của người nữ trong họ).
  String _suggestedSurname(Person? anchor) {
    if (anchor == null || widget.relation != NewRelation.child) return '';
    final surname = anchor.fullName.trim().split(RegExp(r'\s+')).first;
    return surname.isEmpty || !anchor.isMale ? '' : '$surname ';
  }

  @override
  void dispose() {
    for (final c in [
      _name, _nickname, _birth, _death, _order, _title, //
      _occupation, _address, _phone, _burial, _bio,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _validateDate(String? value) {
    if (PartialDate.tryParse(value ?? '') == null) {
      return 'Nhập dạng ngày/tháng/năm, tháng/năm hoặc chỉ năm';
    }
    return null;
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final base = widget.existing;
    final gio = _gioDay != null && _gioMonth != null ? LunarDayMonth(_gioDay!, _gioMonth!) : null;
    final death = _deceased ? PartialDate.tryParse(_death.text)! : const PartialDate();
    final person = (base ??
            Person(id: newId(), fullName: '', gender: _gender))
        .copyWith(
      fullName: _name.text.trim(),
      nickname: _nickname.text.trim(),
      gender: _gender,
      birth: PartialDate.tryParse(_birth.text)!,
      death: death,
      isDeceased: _deceased,
      deathAnniversary: _deceased ? gio : null,
      birthOrder: int.tryParse(_order.text.trim()),
      title: _title.text.trim(),
      occupation: _occupation.text.trim(),
      address: _address.text.trim(),
      phone: _phone.text.trim(),
      burialPlace: _burial.text.trim(),
      biography: _bio.text.trim(),
    );
    final notifier = ref.read(clansProvider.notifier);
    try {
      if (base != null) {
        await notifier.updatePerson(widget.clanId, person);
      } else {
        await notifier.addPerson(
          widget.clanId,
          person,
          relation: widget.relation,
          anchorId: widget.anchorId,
          otherParentId: _otherParentId,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop();
      showMessage(context, base == null ? 'Đã thêm ${person.fullName}' : 'Đã lưu thay đổi');
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showMessage(context, 'Không lưu được: $e');
    }
  }

  String get _screenTitle {
    if (widget.existing != null) return 'Sửa thông tin';
    final anchor = _anchor;
    final name = anchor?.fullName ?? '';
    return switch (widget.relation) {
      NewRelation.child => 'Thêm con của $name',
      NewRelation.spouse => 'Thêm ${(anchor?.isMale ?? true) ? 'vợ' : 'chồng'} cho $name',
      NewRelation.father => 'Thêm bố của $name',
      NewRelation.mother => 'Thêm mẹ của $name',
      NewRelation.none => 'Thêm thành viên',
    };
  }

  @override
  Widget build(BuildContext context) {
    final anchor = _anchor;
    final clan = ref.watch(clanProvider(widget.clanId));
    final anchorSpouses = anchor == null
        ? <Person>[]
        : anchor.spouseIds.map((s) => clan?.members[s]).whereType<Person>().toList();
    final genderLocked =
        widget.relation == NewRelation.father || widget.relation == NewRelation.mother;
    final autoGio = _computedGio();

    return Scaffold(
      appBar: AppBar(
        title: Text(_screenTitle),
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: const Text('Lưu'),
            ),
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
                  autofocus: widget.existing == null,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Họ và tên *'),
                  validator: (v) => (v ?? '').trim().isEmpty ? 'Hãy nhập họ tên' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nickname,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Tên thường gọi / tên húy / pháp danh',
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: SegmentedButton<Gender>(
                        segments: const [
                          ButtonSegment(value: Gender.male, label: Text('Nam'), icon: Icon(Icons.male)),
                          ButtonSegment(value: Gender.female, label: Text('Nữ'), icon: Icon(Icons.female)),
                        ],
                        selected: {_gender},
                        onSelectionChanged:
                            genderLocked ? null : (s) => setState(() => _gender = s.first),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 110,
                      child: TextFormField(
                        controller: _order,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: const InputDecoration(labelText: 'Con thứ'),
                      ),
                    ),
                  ],
                ),
                if (widget.relation == NewRelation.child && anchorSpouses.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String?>(
                    initialValue: _otherParentId,
                    decoration: InputDecoration(
                      labelText: anchor!.isMale ? 'Mẹ của người con' : 'Bố của người con',
                    ),
                    items: [
                      for (var i = 0; i < anchorSpouses.length; i++)
                        DropdownMenuItem<String?>(
                          value: anchorSpouses[i].id,
                          child: Text(anchorSpouses.length > 1
                              ? '${anchorSpouses[i].fullName} (${i == 0 ? 'cả' : 'thứ ${i + 1}'})'
                              : anchorSpouses[i].fullName),
                        ),
                      const DropdownMenuItem<String?>(value: null, child: Text('Chưa rõ')),
                    ],
                    onChanged: (v) => setState(() => _otherParentId = v),
                  ),
                ],
                const SizedBox(height: 12),
                TextFormField(
                  controller: _birth,
                  textInputAction: TextInputAction.next,
                  keyboardType: TextInputType.datetime,
                  decoration: const InputDecoration(
                    labelText: 'Ngày sinh (dương lịch)',
                    hintText: 'VD: 12/03/1950, 03/1950 hoặc 1950',
                  ),
                  validator: _validateDate,
                ),
                const SizedBox(height: 4),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Đã mất'),
                  value: _deceased,
                  onChanged: (v) => setState(() => _deceased = v),
                ),
                if (_deceased) ...[
                  TextFormField(
                    controller: _death,
                    keyboardType: TextInputType.datetime,
                    decoration: const InputDecoration(
                      labelText: 'Ngày mất (dương lịch)',
                      hintText: 'Để trống nếu không rõ',
                    ),
                    validator: _validateDate,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  Text('Ngày giỗ (âm lịch)', style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int?>(
                          initialValue: _gioDay,
                          decoration: const InputDecoration(labelText: 'Ngày'),
                          items: [
                            const DropdownMenuItem<int?>(value: null, child: Text('—')),
                            for (var d = 1; d <= 30; d++)
                              DropdownMenuItem<int?>(value: d, child: Text('$d')),
                          ],
                          onChanged: (v) => setState(() => _gioDay = v),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<int?>(
                          initialValue: _gioMonth,
                          decoration: const InputDecoration(labelText: 'Tháng'),
                          items: [
                            const DropdownMenuItem<int?>(value: null, child: Text('—')),
                            for (var m = 1; m <= 12; m++)
                              DropdownMenuItem<int?>(value: m, child: Text('Tháng $m')),
                          ],
                          onChanged: (v) => setState(() => _gioMonth = v),
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      autoGio == null
                          ? 'Nếu nhập đủ ngày mất dương lịch, ngày giỗ sẽ được tự tính.'
                          : 'Theo ngày mất, ngày giỗ là ${autoGio.day}/${autoGio.month} âm lịch. '
                              'Chỉ cần chọn nếu gia đình làm giỗ ngày khác.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _burial,
                    decoration: const InputDecoration(labelText: 'Nơi an táng / mộ phần'),
                  ),
                ],
                const SizedBox(height: 12),
                TextFormField(
                  controller: _title,
                  decoration: const InputDecoration(
                    labelText: 'Chức danh, danh hiệu',
                    hintText: 'VD: Trưởng tộc, Liệt sĩ, Bà mẹ VN anh hùng…',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _occupation,
                  decoration: const InputDecoration(labelText: 'Nghề nghiệp'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _address,
                  decoration: const InputDecoration(labelText: 'Địa chỉ'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Điện thoại'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _bio,
                  minLines: 3,
                  maxLines: 10,
                  decoration: const InputDecoration(
                    labelText: 'Tiểu sử, công đức, ghi chú',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Lưu'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  LunarDayMonth? _computedGio() {
    final date = PartialDate.tryParse(_death.text)?.toDateTime();
    if (date == null) return null;
    final lunar = LunarCalendar.fromSolar(date);
    return LunarDayMonth(lunar.day, lunar.month);
  }
}
