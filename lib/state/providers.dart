import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/clan_repository.dart';
import '../data/family_graph.dart';
import '../data/models.dart';
import '../data/sample_data.dart';

/// Được thay bằng kho thật trong `main()`.
final repositoryProvider = Provider<ClanRepository>(
  (ref) => throw UnimplementedError('repositoryProvider chưa được khởi tạo'),
);

final clansProvider = NotifierProvider<ClansNotifier, List<Clan>>(ClansNotifier.new);

final clanProvider = Provider.family<Clan?, String>((ref, id) {
  for (final c in ref.watch(clansProvider)) {
    if (c.id == id) return c;
  }
  return null;
});

final graphProvider = Provider.family<FamilyGraph?, String>((ref, id) {
  final clan = ref.watch(clanProvider(id));
  return clan == null ? null : FamilyGraph(clan);
});

/// Quan hệ của người mới so với người đang chọn.
enum NewRelation { none, child, spouse, father, mother }

/// Nơi duy nhất thay đổi dữ liệu gia phả; mọi thay đổi đều được lưu ngay.
class ClansNotifier extends Notifier<List<Clan>> {
  @override
  List<Clan> build() => ref.read(repositoryProvider).load();

  Future<void> _commit(List<Clan> next) async {
    state = next;
    try {
      await ref.read(repositoryProvider).save(next);
    } catch (e, st) {
      debugPrint('Lưu gia phả thất bại: $e\n$st');
      rethrow;
    }
  }

  Clan? _find(String clanId) {
    for (final c in state) {
      if (c.id == clanId) return c;
    }
    return null;
  }

  Future<void> _replace(Clan clan) =>
      _commit([for (final c in state) c.id == clan.id ? clan : c]);

  Future<String> createClan({
    required String name,
    required String founderName,
    required Gender founderGender,
    String origin = '',
  }) async {
    final founder = Person(
      id: newId(),
      fullName: founderName,
      gender: founderGender,
      title: 'Thủy tổ',
    );
    final clan = Clan(
      id: newId(),
      name: name,
      origin: origin,
      members: {founder.id: founder},
      createdAt: DateTime.now(),
    );
    await _commit([...state, clan]);
    return clan.id;
  }

  Future<String> addSample() async {
    final existing = _find('sample-nguyen');
    if (existing != null) return existing.id;
    final clan = buildSampleClan();
    await _commit([...state, clan]);
    return clan.id;
  }

  Future<void> updateClanInfo(Clan clan) => _replace(clan);

  Future<void> deleteClan(String clanId) =>
      _commit(state.where((c) => c.id != clanId).toList());

  /// Nhập một gia phả từ tệp sao lưu; trả về id gia phả đã nhập.
  Future<String> importClan(Clan clan) async {
    final imported = _find(clan.id) == null ? clan : clan.withId(newId());
    await _commit([...state, imported]);
    return imported.id;
  }

  /// Thêm người mới, liên kết với [anchorId] theo [relation].
  Future<void> addPerson(
    String clanId,
    Person person, {
    NewRelation relation = NewRelation.none,
    String? anchorId,
    String? otherParentId,
  }) async {
    final clan = _find(clanId);
    if (clan == null) return;
    final members = Map<String, Person>.of(clan.members);
    var p = person;
    final anchor = anchorId == null ? null : members[anchorId];

    switch (relation) {
      case NewRelation.none:
        break;
      case NewRelation.child:
        if (anchor != null) {
          final other = otherParentId == null ? null : members[otherParentId];
          p = anchor.isMale
              ? p.copyWith(fatherId: anchor.id, motherId: other?.id)
              : p.copyWith(motherId: anchor.id, fatherId: other?.id);
        }
      case NewRelation.spouse:
        if (anchor != null) {
          p = p.copyWith(spouseIds: [anchor.id], isInLaw: !anchor.isInLaw);
          members[anchor.id] = anchor.copyWith(spouseIds: [...anchor.spouseIds, p.id]);
        }
      case NewRelation.father:
      case NewRelation.mother:
        if (anchor != null) {
          final isFather = relation == NewRelation.father;
          final otherParent = members[isFather ? anchor.motherId : anchor.fatherId];
          final inLaw = isFather
              ? anchor.isInLaw
              : (anchor.isInLaw || (otherParent != null && !otherParent.isInLaw));
          p = p.copyWith(
            isInLaw: inLaw,
            spouseIds: otherParent == null ? p.spouseIds : [...p.spouseIds, otherParent.id],
          );
          if (otherParent != null) {
            members[otherParent.id] =
                otherParent.copyWith(spouseIds: [...otherParent.spouseIds, p.id]);
          }
          members[anchor.id] = isFather
              ? anchor.copyWith(fatherId: p.id)
              : anchor.copyWith(motherId: p.id);
          // Nếu người được thêm bố/mẹ là thủy tổ, bố/mẹ trở thành thủy tổ mới.
          if (anchor.title == 'Thủy tổ' && !inLaw) {
            members[anchor.id] = members[anchor.id]!.copyWith(title: '');
            p = p.copyWith(title: p.title.isEmpty ? 'Thủy tổ' : p.title);
          }
        }
    }
    members[p.id] = p;
    await _replace(clan.copyWith(members: members));
  }

  Future<void> updatePerson(String clanId, Person person) async {
    final clan = _find(clanId);
    if (clan == null) return;
    await _replace(clan.copyWith(members: {...clan.members, person.id: person}));
  }

  /// Xóa một người và gỡ mọi liên kết tới người đó.
  Future<void> deletePerson(String clanId, String personId) async {
    final clan = _find(clanId);
    if (clan == null) return;
    final members = <String, Person>{};
    for (final p in clan.members.values) {
      if (p.id == personId) continue;
      var next = p;
      if (p.fatherId == personId) next = next.copyWith(fatherId: null);
      if (p.motherId == personId) next = next.copyWith(motherId: null);
      if (p.spouseIds.contains(personId)) {
        next = next.copyWith(spouseIds: p.spouseIds.where((s) => s != personId).toList());
      }
      members[p.id] = next;
    }
    await _replace(clan.copyWith(members: members));
  }

  /// Đổi thứ tự vợ/chồng (vợ cả, vợ hai…).
  Future<void> reorderSpouses(String clanId, String personId, List<String> spouseIds) async {
    final clan = _find(clanId);
    final p = clan?.members[personId];
    if (clan == null || p == null) return;
    await updatePerson(clanId, p.copyWith(spouseIds: spouseIds));
  }
}
