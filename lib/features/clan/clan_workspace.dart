import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/providers.dart';
import '../anniversary/anniversary_page.dart';
import '../kinship/kinship_page.dart';
import '../members/members_page.dart';
import '../tree/tree_page.dart';
import 'clan_info_page.dart';

/// Màn hình làm việc với một gia phả: phả đồ, thành viên, ngày giỗ…
class ClanWorkspace extends ConsumerStatefulWidget {
  const ClanWorkspace({super.key, required this.clanId, this.initialTab = 0});

  final String clanId;
  final int initialTab;

  @override
  ConsumerState<ClanWorkspace> createState() => _ClanWorkspaceState();
}

class _Destination {
  const _Destination(this.label, this.icon, this.selectedIcon);

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

const _destinations = [
  _Destination('Phả đồ', Icons.account_tree_outlined, Icons.account_tree),
  _Destination('Thành viên', Icons.people_outline, Icons.people),
  _Destination('Ngày giỗ', Icons.event_outlined, Icons.event),
  _Destination('Xưng hô', Icons.connect_without_contact_outlined, Icons.connect_without_contact),
  _Destination('Dòng họ', Icons.menu_book_outlined, Icons.menu_book),
];

class _ClanWorkspaceState extends ConsumerState<ClanWorkspace> {
  late int _index = widget.initialTab;

  @override
  Widget build(BuildContext context) {
    final clan = ref.watch(clanProvider(widget.clanId));
    if (clan == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Gia phả này không còn tồn tại.')),
      );
    }
    final pages = [
      TreePage(clanId: clan.id),
      MembersPage(clanId: clan.id),
      AnniversaryPage(clanId: clan.id),
      KinshipPage(clanId: clan.id),
      ClanInfoPage(clanId: clan.id),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 720;
        final body = IndexedStack(index: _index, children: pages);
        return Scaffold(
          appBar: AppBar(
            title: Text(clan.name, overflow: TextOverflow.ellipsis),
          ),
          body: wide
              ? Row(
                  children: [
                    NavigationRail(
                      selectedIndex: _index,
                      labelType: NavigationRailLabelType.all,
                      onDestinationSelected: (i) => setState(() => _index = i),
                      destinations: [
                        for (final d in _destinations)
                          NavigationRailDestination(
                            icon: Icon(d.icon),
                            selectedIcon: Icon(d.selectedIcon),
                            label: Text(d.label),
                          ),
                      ],
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(child: body),
                  ],
                )
              : body,
          bottomNavigationBar: wide
              ? null
              : NavigationBar(
                  selectedIndex: _index,
                  onDestinationSelected: (i) => setState(() => _index = i),
                  destinations: [
                    for (final d in _destinations)
                      NavigationDestination(
                        icon: Icon(d.icon),
                        selectedIcon: Icon(d.selectedIcon),
                        label: d.label,
                      ),
                  ],
                ),
        );
      },
    );
  }
}
