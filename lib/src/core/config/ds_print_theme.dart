import 'package:flutter/material.dart';

/// Theming derived entirely from the host app's ambient [ThemeData] so
/// ds_print looks on-brand (and matches per-flavor colours) with zero setup.
class DsPrintTheme {
  final Color primary;
  final Color background;
  final Color surface;
  final Color onSurface;
  final Color border;
  final Color selectedIndicator;
  final Color unselectedIndicator;
  final TextStyle titleStyle;
  final TextStyle bodyStyle;
  final TextStyle actionStyle;

  const DsPrintTheme({
    required this.primary,
    required this.background,
    required this.surface,
    required this.onSurface,
    required this.border,
    required this.selectedIndicator,
    required this.unselectedIndicator,
    required this.titleStyle,
    required this.bodyStyle,
    required this.actionStyle,
  });

  /// `theme.primaryColor` is `AppColors.primaryShade600` in the host app's
  /// `getAppTheme` — i.e. the flavor-driven brand colour, for free.
  factory DsPrintTheme.of(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final primary = theme.primaryColor;
    return DsPrintTheme(
      primary: primary,
      background: theme.scaffoldBackgroundColor,
      surface: colorScheme.surface,
      onSurface: colorScheme.onSurface,
      border: theme.dividerColor,
      selectedIndicator: primary,
      unselectedIndicator: theme.disabledColor,
      titleStyle: (textTheme.titleMedium ?? const TextStyle()).copyWith(
        fontWeight: FontWeight.w600,
        color: colorScheme.onSurface,
      ),
      bodyStyle: (textTheme.bodyMedium ?? const TextStyle()).copyWith(
        color: colorScheme.onSurface,
      ),
      actionStyle: (textTheme.labelLarge ?? const TextStyle()).copyWith(
        fontWeight: FontWeight.w600,
        color: colorScheme.onPrimary,
      ),
    );
  }
}
