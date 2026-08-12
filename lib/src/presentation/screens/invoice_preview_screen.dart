import 'package:ds_print/ds_print.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/config/ds_print_strings.dart';
import '../../core/di/ds_print_injection.dart';
import '../cubit/invoice_preview_cubit.dart';
import '../cubit/invoice_preview_state.dart';
import '../widgets/ds_print_app_bar.dart';
import '../widgets/ds_print_loading.dart';
import '../widgets/ds_print_message_dialog.dart';
import '../widgets/ds_print_web_surface.dart';

class InvoicePreviewScreen extends StatelessWidget {
  final String url;
  final String? title;

  const InvoicePreviewScreen({super.key, required this.url, this.title});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => dsPrintResolve<InvoicePreviewCubit>(),
      child: _InvoicePreviewView(url: url, title: title),
    );
  }
}

class _InvoicePreviewView extends StatefulWidget {
  final String url;
  final String? title;

  const _InvoicePreviewView({required this.url, this.title});

  @override
  State<_InvoicePreviewView> createState() => _InvoicePreviewViewState();
}

class _InvoicePreviewViewState extends State<_InvoicePreviewView> {
  DsPrintWebSurfaceHandle? _surface;

  void _handlePrint() {
    // final surface = _surface;
    DsPrint.printUrlSilently(
      widget.url,
    );
    // context.read<InvoicePreviewCubit>().capture(
    //       widget.url,
    //       // Capture the invoice already on screen. Falling back to null (the
    //       // injected headless renderer) only matters if the surface somehow
    //       // hasn't reported in yet — it can't print a page it never rendered.
    //       renderer: surface == null ? null : SurfaceInvoiceRenderer(surface),
    //     );
  }

  void _handleState(BuildContext context, InvoicePreviewState state) {
    if (state is InvoicePreviewCaptured) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PrinterPickerScreen(payload: state.payload),
        ),
      );
    } else if (state is InvoicePreviewFailure) {
      DsPrintMessageDialog.show(
        context,
        DsPrintStrings.of(context).forFailure(state.failure),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = DsPrintStrings.of(context);
    return BlocConsumer<InvoicePreviewCubit, InvoicePreviewState>(
      listener: _handleState,
      builder: (context, state) {
        return Scaffold(
          backgroundColor: DsPrintTheme.of(context).background,
          appBar: DsPrintAppBar(
            title: widget.title ?? strings.taxInvoice,
            actions: [PrintActionButton(onPressed: _handlePrint)],
          ),
          body: SizedBox.expand(
            child: Stack(
              children: [
                DsPrintWebSurface(
                  url: widget.url,
                  onReady: (handle) => _surface = handle,
                  onPageFinished: () =>
                      context.read<InvoicePreviewCubit>().onPageFinished(),
                ),
                if (state is InvoicePreviewLoading)
                  const DsPrintLoadingIndicator(),
                if (state is InvoicePreviewCapturing)
                  const DsPrintCapturingScrim(),
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
            Image.asset(
              'assets/icons/ds_print_printer.png',
              package: 'ds_print',
              width: 24,
              height: 24,
              color: theme.appBarForeground,
            ),
          ],
        ),
      ),
    );
  }
}
