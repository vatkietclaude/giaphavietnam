import 'package:flutter_test/flutter_test.dart';
import 'package:giaphavietnam/core/kinship/kinship.dart';
import 'package:giaphavietnam/data/clan_repository.dart';
import 'package:giaphavietnam/data/family_graph.dart';
import 'package:giaphavietnam/data/models.dart';
import 'package:giaphavietnam/data/sample_data.dart';
import 'package:giaphavietnam/features/tree/tree_layout.dart';

void main() {
  final clan = buildSampleClan();
  final graph = FamilyGraph(clan);
  final kin = KinshipCalculator(clan.members);

  group('FamilyGraph', () {
    test('thủy tổ là gốc duy nhất', () {
      expect(graph.treeRoots.map((p) => p.id), ['to']);
    });

    test('tính đời', () {
      expect(graph.generationOf('to'), 1);
      expect(graph.generationOf('to-w'), 1);
      expect(graph.generationOf('an'), 3);
      expect(graph.generationOf('duc-w'), 4);
      expect(graph.generationOf('bao'), 6);
      expect(graph.generationCount, 6);
    });

    test('con xếp theo thứ tự', () {
      expect(graph.childrenOf('to').map((p) => p.id), ['truong', 'mai', 'thu']);
    });

    test('con của nhiều vợ đều treo dưới người cha', () {
      expect(graph.treeChildrenOf('thu').map((p) => p.id), ['cuong', 'dung']);
    });
  });

  group('Xưng hô', () {
    test('trực hệ', () {
      expect(kin.termFor('minh', 'bao'), 'Con trai');
      expect(kin.termFor('bao', 'minh'), 'Bố');
      expect(kin.termFor('ngoc', 'thu'), 'Ông nội');
      expect(kin.termFor('duc', 'an-w'), 'Mẹ');
    });

    test('anh chị em cùng cha khác mẹ', () {
      expect(kin.termFor('dung', 'cuong'), 'Anh trai');
      expect(kin.termFor('cuong', 'dung'), 'Em gái');
    });

    test('bác – chú theo thứ bậc của bố', () {
      expect(kin.termFor('phuc', 'an'), 'Bác');
      expect(kin.termFor('duc', 'binh'), 'Chú');
    });

    test('vai vế theo nhánh, không theo tuổi', () {
      // Tuấn sinh trước Minh nhưng thuộc chi thứ nên vẫn gọi Minh là anh.
      expect(kin.termFor('tuan', 'minh'), 'Anh họ');
      expect(kin.termFor('minh', 'tuan'), 'Em họ');
    });

    test('dâu rể', () {
      expect(kin.termFor('an', 'duc-w'), 'Con dâu');
      expect(kin.termFor('duc-w', 'an'), 'Bố chồng');
      expect(kin.termFor('phuc', 'duc-w'), 'Chị dâu (họ)');
      expect(kin.termFor('duc', 'dung'), 'Cô họ');
      expect(kin.termFor('duc', 'dung-h'), 'Chú (dượng) họ');
    });

    test('vợ chồng', () {
      expect(kin.termFor('thu', 'thu-w2'), 'Vợ');
      expect(kin.termFor('thu-w2', 'thu'), 'Chồng');
    });
  });

  group('Phả đồ', () {
    test('mọi người trong họ và vợ/chồng đều có ô', () {
      final layout = TreeLayout.compute(graph);
      final ids = layout.boxes.map((b) => b.personId).toSet();
      expect(ids, clan.members.keys.toSet());
      // Không có hai ô chồng lên nhau.
      for (var i = 0; i < layout.boxes.length; i++) {
        for (var j = i + 1; j < layout.boxes.length; j++) {
          final a = layout.boxes[i].rect.deflate(1);
          final b = layout.boxes[j].rect.deflate(1);
          expect(a.overlaps(b), isFalse,
              reason: '${layout.boxes[i].personId} – ${layout.boxes[j].personId}');
        }
      }
    });

    test('thu gọn nhánh và giới hạn số đời', () {
      final collapsed = TreeLayout.compute(graph, collapsed: {'truong'});
      expect(collapsed.boxOf('an'), isNull);
      expect(collapsed.boxOf('truong')!.hiddenChildren, 2);
      final limited = TreeLayout.compute(graph, maxGenerations: 2);
      expect(limited.boxOf('an'), isNull);
      expect(limited.boxOf('truong'), isNotNull);
    });
  });

  group('Dữ liệu', () {
    test('sao lưu rồi khôi phục giữ nguyên dữ liệu', () {
      final text = ClanRepository.exportClan(clan);
      final restored = ClanRepository.importClan(text);
      expect(restored.name, clan.name);
      expect(restored.members.length, clan.members.length);
      expect(ClanRepository.exportClan(restored).split('\n').skip(4).join('\n'),
          text.split('\n').skip(4).join('\n'));
    });

    test('đọc ngày thiếu thông tin', () {
      expect(PartialDate.tryParse('1950'), const PartialDate(year: 1950));
      expect(PartialDate.tryParse('3/1950'), const PartialDate(month: 3, year: 1950));
      expect(PartialDate.tryParse('12-3-1950'),
          const PartialDate(day: 12, month: 3, year: 1950));
      expect(PartialDate.tryParse('31/2/1950'), isNull);
      expect(PartialDate.tryParse('abc'), isNull);
    });

    test('ngày giỗ tính từ ngày mất dương lịch', () {
      final to = clan.members['to']!;
      expect(to.effectiveAnniversary, const LunarDayMonth(27, 1));
    });
  });
}
