import 'package:flutter/material.dart';

import 'ds_print_config.dart';

/// Theming derived entirely from the host app's ambient [ThemeData] so
/// ds_print looks on-brand (and matches per-flavor colours) with zero setup.
///
/// A host that wants something else passes a fully-built instance to
/// `DsPrint.configure(DsPrintConfig(themeOverride: ...))`; [DsPrintTheme.of]
/// returns it verbatim and never touches the ambient theme.
class DsPrintTheme {
  final Color primary;
  final Color background;
  final Color surface;
  final Color onSurface;
  final Color border;
  final Color selectedIndicator;
  final Color unselectedIndicator;
  final Color appBarBackground;
  final Color appBarForeground;
  final Color progressIndicator;
  final TextStyle titleStyle;
  final TextStyle bodyStyle;
  final TextStyle actionStyle;
  final TextStyle appBarTitleStyle;

  const DsPrintTheme({
    required this.primary,
    required this.background,
    required this.surface,
    required this.onSurface,
    required this.border,
    required this.selectedIndicator,
    required this.unselectedIndicator,
    required this.appBarBackground,
    required this.appBarForeground,
    required this.progressIndicator,
    required this.titleStyle,
    required this.bodyStyle,
    required this.actionStyle,
    required this.appBarTitleStyle,
  });

  /// `theme.primaryColor` is `AppColors.primaryShade600` in the host app's
  /// `getAppTheme` — which resolves to `FlavorConfig.instance.values
  /// .primaryColor`, i.e. the flavor-driven brand colour, for free.
  ///
  /// Deliberately *not* `colorScheme.primary`: the host builds its `ThemeData`
  /// without a `colorScheme`/`primarySwatch`, so Flutter fills one in from the
  /// Material 3 baseline (a purple) and `colorScheme.primary` has nothing to do
  /// with the flavor. Same reason the app bar can't inherit `appBarTheme` —
  /// the host's global one is white, and every real screen overrides it with
  /// `BaseAppBar`'s primary background + white title.
  factory DsPrintTheme.of(BuildContext context) {
    final override = DsPrintConfig.current?.themeOverride;
    if (override != null) return override;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final primary = theme.primaryColor;
    // The host hardcodes white on primary everywhere; computing it keeps that
    // result while staying legible if a flavor ever ships a light brand colour.
    final onPrimary =
        ThemeData.estimateBrightnessForColor(primary) == Brightness.dark
            ? Colors.white
            : Colors.black87;
    final progress = ProgressIndicatorTheme.of(context).color ?? primary;
    return DsPrintTheme(
      primary: primary,
      background: theme.scaffoldBackgroundColor,
      surface: colorScheme.surface,
      onSurface: colorScheme.onSurface,
      // Mirrors `AppDecoration.cardPrimaryBoarder` — a primary-coloured 1px
      // outline, not the neutral `dividerColor`.
      border: primary,
      selectedIndicator: primary,
      unselectedIndicator: theme.dividerColor,
      appBarBackground: primary,
      appBarForeground: onPrimary,
      progressIndicator: progress,
      titleStyle: (textTheme.titleMedium ?? const TextStyle()).copyWith(
        fontWeight: FontWeight.w600,
        color: colorScheme.onSurface,
      ),
      bodyStyle: (textTheme.bodyMedium ?? const TextStyle()).copyWith(
        color: colorScheme.onSurface,
      ),
      actionStyle: (textTheme.labelLarge ?? const TextStyle()).copyWith(
        fontWeight: FontWeight.w600,
        color: onPrimary,
      ),
      appBarTitleStyle: (textTheme.titleLarge ?? const TextStyle()).copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: onPrimary,
      ),
    );
  }
}
