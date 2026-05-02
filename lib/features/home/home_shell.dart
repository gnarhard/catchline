import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../data/models/item_kind.dart';
import '../items/item_list_screen.dart';
import '../settings/settings_screen.dart';

/// Max width that the app's UI content (excluding the bottom nav background)
/// is allowed to occupy. Beyond this, content is centered with empty space
/// on either side; the wave background and nav bar surface still fill the
/// full viewport.
const double kMaxContentWidth = 1080;

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
    final theme = Theme.of(context);
    final navBg =
        theme.navigationBarTheme.backgroundColor ?? theme.colorScheme.surface;

    return Column(
      children: [
        Expanded(
          child: MediaQuery.removePadding(
            context: context,
            removeBottom: true,
            child: SafeArea(
              bottom: false,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: kMaxContentWidth),
                  child: IndexedStack(
                    index: _index,
                    children: [
                      for (final kind in _kinds) ItemListScreen(kind: kind),
                      const SettingsScreen(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        ColoredBox(
          color: navBg,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: kMaxContentWidth),
              child: NavigationBar(
                backgroundColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
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
                  NavigationDestination(
                    icon: Icon(LucideIcons.music),
                    label: 'Lyrics',
                  ),
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
            ),
          ),
        ),
      ],
    );
  }
}
