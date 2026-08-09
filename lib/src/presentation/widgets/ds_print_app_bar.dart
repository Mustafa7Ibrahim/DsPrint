import 'package:flutter/material.dart';

import '../../core/config/ds_print_theme.dart';

/// The package's app bar, matching the host app's `BaseAppBar`: flavor-coloured
/// background, white centred title, flat.
///
/// A plain [AppBar] can't be used — the host's global `appBarTheme` is
/// `backgroundColor: Colors.white`, which no real screen actually renders
/// (every one of them passes `BaseAppBar` instead). Inheriting it produced a
/// white bar with a white "Print" label on it.
class DsPrintAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;

  const DsPrintAppBar({super.key, required this.title, this.actions});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final theme = DsPrintTheme.of(context);
    return AppBar(
      backgroundColor: theme.appBarBackground,
      foregroundColor: theme.appBarForeground,
      // Material 3 tints the bar towards `surfaceTintColor` once content
      // scrolls under it, which would visibly drift the flavor colour mid-
      // scroll. Transparent pins it.
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      title: Text(title, style: theme.appBarTitleStyle),
      automaticallyImplyLeading: false,
      leading: Navigator.canPop(context) ? const DsPrintBackButton() : null,
      actions: actions,
    );
  }
}

/// Back affordance matching `BaseAppBar.buttonBack` (`arrow_back_ios_rounded`
/// in the app bar's foreground colour) rather than Material's default arrow.
class DsPrintBackButton extends StatelessWidget {
  const DsPrintBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () => Navigator.of(context).maybePop(),
      icon: Icon(
        Icons.arrow_back_ios_rounded,
        color: DsPrintTheme.of(context).appBarForeground,
      ),
    );
  }
}
