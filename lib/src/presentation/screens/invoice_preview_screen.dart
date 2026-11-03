import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/config/ds_print_strings.dart';
import '../../core/config/ds_print_theme.dart';
import '../../core/di/ds_print_injection.dart';
import '../../core/error/ds_print_failure.dart';
import '../cubit/invoice_preview_cubit.dart';
import '../cubit/invoice_preview_state.dart';
import '../cubit/print_job_cubit.dart';
import '../cubit/print_job_state.dart';
import '../renderer/surface_invoice_renderer.dart';
import '../widgets/ds_print_app_bar.dart';
import '../widgets/ds_print_loading.dart';
import '../widgets/ds_print_message_dialog.dart';
import '../widgets/ds_print_web_surface.dart';
import 'printer_picker_screen.dart';

class InvoicePreviewScreen extends StatelessWidget {
  final String url;
  final String? title;

  const InvoicePreviewScreen({super.key, required this.url, this.title});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => dsPrintResolve<InvoicePreviewCubit>()),
        BlocProvider(create: (_) => dsPrintResolve<PrintJobCubit>()),
      ],
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
  InvoicePreviewCaptured? _lastCapture;

  void _handlePrint() {
    final surface = _surface;
    context.read<InvoicePreviewCubit>().capture(
          widget.url,
          // Capture the invoice already on screen. Falling back to null (the
          // injected headless renderer) only matters if the surface somehow
          // hasn't reported in yet — it can't print a page it never rendered.
          renderer: surface == null ? null : SurfaceInvoiceRenderer(surface),
        );
  }

  /// A captured invoice goes straight to the printer the user selected — the
  /// picker only appears when there isn't one yet.
  void _handleState(BuildContext context, InvoicePreviewState state) {
    if (state is InvoicePreviewCaptured) {
      _lastCapture = state;
      context.read<PrintJobCubit>().autoPrint(state.payload);
    } else if (state is InvoicePreviewFailure) {
      DsPrintMessageDialog.show(
        context,
        DsPrintStrings.of(context).forFailure(state.failure),
      );
    }
  }

  void _handlePrintState(BuildContext context, PrintJobState state) {
    if (state is! PrintJobFailure) return;
    final capture = _lastCapture;
    if (state.failure is NoPrinterSelectedFailure && capture != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PrinterPickerScreen(payload: capture.payload),
        ),
      );
    } else {
      DsPrintMessageDialog.show(
        context,
        DsPrintStrings.of(context).forFailure(state.failure),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = DsPrintStrings.of(context);
    final isPrinting =
        context.watch<PrintJobCubit>().state is PrintJobInProgress;
    return BlocListener<PrintJobCubit, PrintJobState>(
      listener: _handlePrintState,
      child: BlocConsumer<InvoicePreviewCubit, InvoicePreviewState>(
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
                  if (state is InvoicePreviewCapturing || isPrinting)
                    const DsPrintCapturingScrim(),
                ],
              ),
            ),
          );
        },
      ),
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
