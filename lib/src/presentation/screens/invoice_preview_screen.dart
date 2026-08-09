import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/config/ds_print_strings.dart';
import '../../core/config/ds_print_theme.dart';
import '../../core/di/ds_print_injection.dart';
import '../cubit/invoice_preview_cubit.dart';
import '../cubit/invoice_preview_state.dart';
import '../widgets/ds_print_message_dialog.dart';
import '../widgets/ds_print_web_surface.dart';
import 'printer_picker_screen.dart';

class InvoicePreviewScreen extends StatelessWidget {
  final String url;
  final String? title;

  const InvoicePreviewScreen({super.key, required this.url, this.title});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => dsPrintSl<InvoicePreviewCubit>(),
      child: _InvoicePreviewView(url: url, title: title),
    );
  }
}

class _InvoicePreviewView extends StatelessWidget {
  final String url;
  final String? title;

  const _InvoicePreviewView({required this.url, this.title});

  @override
  Widget build(BuildContext context) {
    final strings = DsPrintStrings.of(context);
    return BlocConsumer<InvoicePreviewCubit, InvoicePreviewState>(
      listener: (context, state) {
        if (state is InvoicePreviewCaptured) {
          Navigator.of(
            context,
          ).push(MaterialPageRoute(
              builder: (_) => PrinterPickerScreen(payload: state.payload)));
        } else if (state is InvoicePreviewFailure) {
          DsPrintMessageDialog.show(context, strings.forFailure(state.failure));
        }
      },
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            title: Text(title ?? strings.taxInvoice),
            centerTitle: true,
            actions: [
              PrintActionButton(
                  onPressed: () =>
                      context.read<InvoicePreviewCubit>().capture(url)),
            ],
          ),
          body: SizedBox.expand(
            child: Stack(
              children: [
                DsPrintWebSurface(
                  url: url,
                  onPageFinished: () =>
                      context.read<InvoicePreviewCubit>().onPageFinished(),
                ),
                if (state is InvoicePreviewLoading)
                  const Center(child: CircularProgressIndicator()),
                if (state is InvoicePreviewCapturing)
                  const ColoredBox(
                      color: Colors.black26,
                      child: Center(child: CircularProgressIndicator())),
              ],
            ),
          ),
        );
      },
    );
  }
}

class PrintActionButton extends StatelessWidget {
  final VoidCallback onPressed;

  const PrintActionButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final strings = DsPrintStrings.of(context);
    final theme = DsPrintTheme.of(context);
    return InkWell(
      onTap: onPressed,
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(strings.print_, style: theme.actionStyle),
            const SizedBox(width: 2),
            Image.asset('assets/icons/ds_print_printer.png',
                package: 'ds_print', width: 24, height: 24),
          ],
        ),
      ),
    );
  }
}
