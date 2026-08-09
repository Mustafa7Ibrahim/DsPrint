import 'package:flutter/material.dart';

import '../../core/config/ds_print_strings.dart';
import '../../core/config/ds_print_theme.dart';

/// The package's only error surface — never a SnackBar.
class DsPrintMessageDialog extends StatelessWidget {
  final String message;

  const DsPrintMessageDialog({super.key, required this.message});

  static Future<void> show(BuildContext context, String message) {
    return showDialog<void>(
      context: context,
      builder: (_) => DsPrintMessageDialog(message: message),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = DsPrintTheme.of(context);
    final strings = DsPrintStrings.of(context);
    return AlertDialog(
      backgroundColor: theme.surface,
      content: Text(message, style: theme.bodyStyle),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(strings.ok,
              style: theme.actionStyle.copyWith(color: theme.primary)),
        ),
      ],
    );
  }
}
