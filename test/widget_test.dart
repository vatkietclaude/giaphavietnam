import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giaphavietnam/app.dart';
import 'package:giaphavietnam/data/clan_repository.dart';
import 'package:giaphavietnam/state/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('mở gia phả mẫu và xem các mục chính', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [repositoryProvider.overrideWithValue(ClanRepository(prefs))],
        child: const GiaPhaApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Gia Phả Việt'), findsOneWidget);
    await tester.tap(find.text('Xem gia phả mẫu'));
    await tester.pumpAndSettle();

    // Phả đồ hiển thị thủy tổ.
    expect(find.text('Nguyễn Văn Tổ'), findsWidgets);

    await tester.tap(find.text('Thành viên'));
    await tester.pumpAndSettle();
    expect(find.textContaining('thành viên'), findsWidgets);

    await tester.tap(find.text('Ngày giỗ'));
    await tester.pumpAndSettle();
    expect(find.text('Đổi ngày âm – dương'), findsOneWidget);

    await tester.tap(find.text('Dòng họ'));
    await tester.pumpAndSettle();
    expect(find.text('Thống kê'), findsOneWidget);

    // Dữ liệu đã được lưu.
    expect(ClanRepository(prefs).load(), hasLength(1));
  });
}
