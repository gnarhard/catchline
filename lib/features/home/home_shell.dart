import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../data/models/item_kind.dart';
import '../items/item_list_screen.dart';
import '../settings/settings_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _kinds = ItemKind.values;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: _index,
          children: [
            for (final kind in _kinds) ItemListScreen(kind: kind),
            const SettingsScreen(),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(LucideIcons.notebookPen),
            label: 'Journal',
          ),
          NavigationDestination(
            icon: Icon(LucideIcons.feather),
            label: 'Poems',
          ),
          NavigationDestination(icon: Icon(LucideIcons.music), label: 'Lyrics'),
          NavigationDestination(
            icon: Icon(LucideIcons.quote),
            label: 'Phrases',
          ),
          NavigationDestination(
            icon: Icon(LucideIcons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
