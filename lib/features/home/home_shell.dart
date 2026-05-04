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

/// Compact height used by the bottom navigation bar's icon+label content.
///
/// Top and bottom breathing room are rendered as separate fillers in the
/// same chrome background so labels never centre into the home-indicator
/// safe area or sit flush against the screen edge.
@visibleForTesting
const double kNavBarHeight = 48;

/// Symmetric vertical padding rendered above the nav bar's content area, and
/// used as the bottom filler on platforms with no system bottom inset
/// (desktop, iPad with a home button). On platforms with a system bottom
/// inset, that inset is used as the bottom filler instead.
@visibleForTesting
const double kNavBarVerticalPadding = 12;

/// Tight label spacing used by the bottom navigation bar.
@visibleForTesting
const EdgeInsets kNavBarLabelPadding = EdgeInsets.only(top: 2);

/// Below this width, the nav bar shrinks its labels so all five destinations
/// still fit without overflow on small phones.
@visibleForTesting
const double kNavBarCompactWidth = 380;

/// Returns the horizontal inset that centres [kMaxContentWidth] of content
/// within [width]. Zero when the screen is narrower than the max content.
@visibleForTesting
double appContentHorizontalInset(double width) {
  final inset = (width - kMaxContentWidth) / 2;
  return inset > 0 ? inset : 0;
}

/// Subtle drop shadow above the bottom nav bar, lifting it off the page.
@visibleForTesting
BoxShadow buildBottomNavigationShadow(Brightness brightness) {
  return BoxShadow(
    color: Colors.black.withAlpha(brightness == Brightness.dark ? 140 : 30),
    blurRadius: 16,
    offset: const Offset(0, -2),
  );
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _kinds = ItemKind.values;

  void _onNavTap(int i) {
    if (i == _index) return;
    setState(() => _index = i);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCompact = MediaQuery.sizeOf(context).width < kNavBarCompactWidth;
    final compactLabelStyle = theme.textTheme.labelSmall?.copyWith(
      fontSize: 10,
      height: 1.0,
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: MediaQuery.removePadding(
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
      bottomNavigationBar: _buildNavBar(
        context,
        isCompact: isCompact,
        compactLabelStyle: compactLabelStyle,
      ),
    );
  }

  Widget _buildNavBar(
    BuildContext context, {
    required bool isCompact,
    required TextStyle? compactLabelStyle,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final scheme = theme.colorScheme;

    const destinations = <NavigationDestination>[
      NavigationDestination(
        icon: Icon(LucideIcons.notebookPen),
        label: 'Journal',
        tooltip: '',
      ),
      NavigationDestination(
        icon: Icon(LucideIcons.feather),
        label: 'Poems',
        tooltip: '',
      ),
      NavigationDestination(
        icon: Icon(LucideIcons.music),
        label: 'Lyrics',
        tooltip: '',
      ),
      NavigationDestination(
        icon: Icon(LucideIcons.quote),
        label: 'Phrases',
        tooltip: '',
      ),
      NavigationDestination(
        icon: Icon(LucideIcons.settings),
        label: 'Settings',
        tooltip: '',
      ),
    ];
    final destCount = destinations.length;

    final screenWidth = MediaQuery.sizeOf(context).width;
    final inset = appContentHorizontalInset(screenWidth);
    final darkenedBg = isDark
        ? scheme.surface.withAlpha(160)
        : scheme.surface.withAlpha(180);
    final activeHighlight = scheme.primary.withAlpha(isDark ? 8 : 6);
    final hoverHighlight = scheme.primary.withAlpha(isDark ? 14 : 10);

    final labelStyle = WidgetStateProperty.resolveWith<TextStyle?>((states) {
      if (!isCompact) return null;
      return compactLabelStyle;
    });

    Widget bar = NavigationBar(
      height: kNavBarHeight,
      labelPadding: kNavBarLabelPadding,
      backgroundColor: Colors.transparent,
      indicatorColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      selectedIndex: _index,
      onDestinationSelected: _onNavTap,
      destinations: destinations,
    );

    if (inset > 0) {
      bar = Padding(
        padding: EdgeInsets.symmetric(horizontal: inset),
        child: bar,
      );
    }

    final systemBottomInset = MediaQuery.paddingOf(context).bottom;
    final bottomFiller = systemBottomInset > 0
        ? systemBottomInset
        : kNavBarVerticalPadding;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: darkenedBg,
        boxShadow: [buildBottomNavigationShadow(theme.brightness)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: kMaxContentWidth),
              child: Row(
                children: [
                  for (var i = 0; i < destCount; i++)
                    Expanded(
                      child: Container(
                        height: 2,
                        color: i == _index
                            ? scheme.primary
                            : Colors.transparent,
                      ),
                    ),
                ],
              ),
            ),
          ),
          Stack(
            children: [
              MediaQuery.removePadding(
                context: context,
                removeBottom: true,
                removeTop: true,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: kNavBarVerticalPadding),
                    TooltipTheme(
                      data: const TooltipThemeData(
                        constraints: BoxConstraints(),
                        padding: EdgeInsets.zero,
                        margin: EdgeInsets.zero,
                        waitDuration: Duration(days: 1),
                        decoration: BoxDecoration(color: Colors.transparent),
                        textStyle: TextStyle(fontSize: 0),
                      ),
                      child: NavigationBarTheme(
                        data: theme.navigationBarTheme.copyWith(
                          labelTextStyle: labelStyle,
                          indicatorColor: Colors.transparent,
                          overlayColor: const WidgetStatePropertyAll(
                            Colors.transparent,
                          ),
                        ),
                        child: bar,
                      ),
                    ),
                    SizedBox(height: bottomFiller),
                  ],
                ),
              ),
              Positioned.fill(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: kMaxContentWidth,
                    ),
                    child: _NavHighlightRow(
                      count: destCount,
                      activeIndex: _index,
                      activeColor: activeHighlight,
                      hoverColor: hoverHighlight,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NavHighlightRow extends StatefulWidget {
  const _NavHighlightRow({
    required this.count,
    required this.activeIndex,
    required this.activeColor,
    required this.hoverColor,
  });

  final int count;
  final int activeIndex;
  final Color activeColor;
  final Color hoverColor;

  @override
  State<_NavHighlightRow> createState() => _NavHighlightRowState();
}

class _NavHighlightRowState extends State<_NavHighlightRow> {
  int? _hoveredIndex;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < widget.count; i++)
          Expanded(
            child: MouseRegion(
              hitTestBehavior: HitTestBehavior.translucent,
              onEnter: (_) => setState(() => _hoveredIndex = i),
              onExit: (_) {
                if (_hoveredIndex == i) {
                  setState(() => _hoveredIndex = null);
                }
              },
              child: IgnorePointer(
                child: ColoredBox(
                  color: i == widget.activeIndex
                      ? widget.activeColor
                      : i == _hoveredIndex
                      ? widget.hoverColor
                      : Colors.transparent,
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
