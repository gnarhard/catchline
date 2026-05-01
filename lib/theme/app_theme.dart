import 'package:flutter/material.dart';

/// Static color tokens for the deep maroon palette.
///
/// Theme colors that flow through `ColorScheme` derive from [AppColors.maroonSeed],
/// while the surface / scaffold constants are exposed for places that paint
/// outside the Theme (e.g. [WaveBackground]).
class AppColors {
  AppColors._();

  static const Color maroonSeed = Color(0xFF8B1E2C);

  static const Color darkScaffold = Color(0xFF0A0405);
  static const Color darkSurface = Color(0xFF160A0D);
  static const Color darkSurfaceHigh = Color(0xFF1F1014);

  static const Color lightScaffold = Color(0xFFFBF6F6);
  static const Color lightSurface = Color(0xFFF5EBEC);
  static const Color lightSurfaceHigh = Color(0xFFEFE0E2);
}

const String _kFontFamily = 'Inter';

ThemeData buildLightTheme() => _buildTheme(Brightness.light);
ThemeData buildDarkTheme() => _buildTheme(Brightness.dark);

ThemeData _buildTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final colorScheme = ColorScheme.fromSeed(
    seedColor: AppColors.maroonSeed,
    brightness: brightness,
  );

  final scaffold = isDark ? AppColors.darkScaffold : AppColors.lightScaffold;
  final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colorScheme,
    fontFamily: _kFontFamily,
    scaffoldBackgroundColor: scaffold,
    canvasColor: scaffold,
  );

  final textTheme = base.textTheme
      .apply(fontFamily: _kFontFamily)
      .copyWith(
        headlineSmall: base.textTheme.headlineSmall?.copyWith(
          fontFamily: _kFontFamily,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.4,
        ),
        titleLarge: base.textTheme.titleLarge?.copyWith(
          fontFamily: _kFontFamily,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
        ),
        titleMedium: base.textTheme.titleMedium?.copyWith(
          fontFamily: _kFontFamily,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
        bodyLarge: base.textTheme.bodyLarge?.copyWith(
          fontFamily: _kFontFamily,
          height: 1.5,
        ),
        bodyMedium: base.textTheme.bodyMedium?.copyWith(
          fontFamily: _kFontFamily,
          height: 1.5,
        ),
        labelLarge: base.textTheme.labelLarge?.copyWith(
          fontFamily: _kFontFamily,
          fontWeight: FontWeight.w500,
          letterSpacing: 0,
        ),
      );

  final dividerColor = colorScheme.onSurface.withAlpha(isDark ? 28 : 36);

  return base.copyWith(
    textTheme: textTheme,
    primaryTextTheme: textTheme,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: <TargetPlatform, PageTransitionsBuilder>{
        TargetPlatform.android: _NoTransitionsBuilder(),
        TargetPlatform.iOS: _NoTransitionsBuilder(),
        TargetPlatform.macOS: _NoTransitionsBuilder(),
        TargetPlatform.windows: _NoTransitionsBuilder(),
        TargetPlatform.linux: _NoTransitionsBuilder(),
        TargetPlatform.fuchsia: _NoTransitionsBuilder(),
      },
    ),
    dividerColor: dividerColor,
    dividerTheme: DividerThemeData(color: dividerColor, space: 1, thickness: 1),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      foregroundColor: colorScheme.onSurface,
      scrolledUnderElevation: 0,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: textTheme.titleLarge,
      iconTheme: IconThemeData(color: colorScheme.onSurface),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: surface.withAlpha(isDark ? 220 : 235),
      surfaceTintColor: Colors.transparent,
      indicatorColor: colorScheme.primary.withAlpha(isDark ? 80 : 60),
      indicatorShape: const StadiumBorder(),
      height: 64,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: selected
              ? colorScheme.onSurface
              : colorScheme.onSurfaceVariant,
          size: 22,
        );
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontFamily: _kFontFamily,
          fontSize: 11,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          letterSpacing: 0.1,
          color: selected
              ? colorScheme.onSurface
              : colorScheme.onSurfaceVariant,
        );
      }),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: false,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(vertical: 12),
      border: UnderlineInputBorder(borderSide: BorderSide(color: dividerColor)),
      enabledBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: dividerColor),
      ),
      focusedBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
      ),
      hintStyle: TextStyle(
        fontFamily: _kFontFamily,
        color: colorScheme.onSurfaceVariant.withAlpha(140),
        fontWeight: FontWeight.w400,
      ),
      labelStyle: TextStyle(
        fontFamily: _kFontFamily,
        color: colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w500,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: surface.withAlpha(isDark ? 180 : 220),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.symmetric(vertical: 4),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: colorScheme.onSurfaceVariant,
      titleTextStyle: textTheme.titleMedium,
      subtitleTextStyle: textTheme.bodyMedium?.copyWith(
        color: colorScheme.onSurfaceVariant,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: colorScheme.primary,
      foregroundColor: colorScheme.onPrimary,
      elevation: 0,
      focusElevation: 0,
      hoverElevation: 1,
      highlightElevation: 0,
      extendedTextStyle: TextStyle(
        fontFamily: _kFontFamily,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ),
      shape: const StadiumBorder(),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        textStyle: const TextStyle(
          fontFamily: _kFontFamily,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
        ),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        textStyle: const TextStyle(
          fontFamily: _kFontFamily,
          fontWeight: FontWeight.w500,
        ),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: colorScheme.onSurfaceVariant,
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titleTextStyle: textTheme.titleLarge,
      contentTextStyle: textTheme.bodyMedium,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: surface,
      contentTextStyle: textTheme.bodyMedium?.copyWith(
        color: colorScheme.onSurface,
      ),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}

class _NoTransitionsBuilder extends PageTransitionsBuilder {
  const _NoTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => child;
}
