import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/config/ds_print_strings.dart';
import '../../core/config/ds_print_theme.dart';
import '../../core/di/ds_print_injection.dart';
import '../../domain/entities/print_payload.dart';
import '../../domain/entities/printer_device.dart';
import '../cubit/print_job_cubit.dart';
import '../cubit/print_job_state.dart';
import '../cubit/printer_connection_cubit.dart';
import '../cubit/printer_connection_state.dart';
import '../cubit/saved_printers_cubit.dart';
import '../cubit/saved_printers_state.dart';
import '../widgets/ds_print_add_printer_button.dart';
import '../widgets/ds_print_app_bar.dart';
import '../widgets/ds_print_loading.dart';
import '../widgets/ds_print_message_dialog.dart';
import '../widgets/printer_device_tile.dart';

/// The user's printers: the ones they added, with the active one marked.
/// Opening it never scans — new printers come in only through the Add
/// Printer button.
///
/// `payload == null` means "manage printers only" (used from
/// [DsPrint.selectDevice]): tapping a printer just makes it the active one.
/// A non-null payload additionally prints it — to the printer tapped, or to a
/// printer the user adds right here — and pops on success. This collapses the
/// host's three-valued `EnumPrinterScreenMode` into one nullable field — the
/// html/base64 distinction already lives on the [PrintPayload] subtype.
class PrinterPickerScreen extends StatelessWidget {
  final PrintPayload? payload;

  /// Whether Add Printer offers Bluetooth / LAN. Null falls back to
  /// `DsPrintConfig`, and then to showing them.
  final bool? showBluetooth;
  final bool? showLan;

  const PrinterPickerScreen({
    super.key,
    this.payload,
    this.showBluetooth,
    this.showLan,
  });

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => dsPrintResolve<SavedPrintersCubit>()),
        BlocProvider(create: (_) => dsPrintResolve<PrintJobCubit>()),
        BlocProvider(create: (_) => dsPrintResolve<PrinterConnectionCubit>()),
      ],
      child: _PrinterPickerView(
        payload: payload,
        showBluetooth: showBluetooth,
        showLan: showLan,
      ),
    );
  }
}

class _PrinterPickerView extends StatefulWidget {
  final PrintPayload? payload;
  final bool? showBluetooth;
  final bool? showLan;

  const _PrinterPickerView({this.payload, this.showBluetooth, this.showLan});

  @override
  State<_PrinterPickerView> createState() => _PrinterPickerViewState();
}

class _PrinterPickerViewState extends State<_PrinterPickerView> {
  @override
  void initState() {
    super.initState();
    context.read<SavedPrintersCubit>().load();
  }

  void _handleTap(PrinterDevice device) {
    context.read<SavedPrintersCubit>().select(device);
    _printIfRequested(device);
  }

  /// The sheet has already saved [device] and made it the active printer.
  void _handleAdded(PrinterDevice device) {
    context.read<SavedPrintersCubit>().onPrinterAdded(device);
    _printIfRequested(device);
  }

  void _printIfRequested(PrinterDevice device) {
    final payload = widget.payload;
    if (payload != null) {
      context.read<PrintJobCubit>().printTo(device, payload);
    }
  }

  Future<bool> _confirmRemove() async {
    final theme = DsPrintTheme.of(context);
    final strings = DsPrintStrings.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: theme.surface,
        content: Text(strings.removePrinterQuestion, style: theme.bodyStyle),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(strings.cancel,
                style: theme.actionStyle.copyWith(color: theme.primary)),
          ),
          TextButton(
            key: const Key('ds_print_confirm_remove'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(strings.remove,
                style: theme.actionStyle.copyWith(color: Colors.red)),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final strings = DsPrintStrings.of(context);
    final theme = DsPrintTheme.of(context);
    return MultiBlocListener(
      listeners: [
        BlocListener<PrintJobCubit, PrintJobState>(
          listener: (context, state) {
            if (state is PrintJobCompleted) {
              Navigator.of(context).pop();
            } else if (state is PrintJobFailure) {
              DsPrintMessageDialog.show(
                  context, strings.forFailure(state.failure));
            }
          },
        ),
        // Re-check only when the set of printers changed, not on a mere
        // change of the selected one.
        BlocListener<SavedPrintersCubit, SavedPrintersState>(
          listenWhen: (previous, current) =>
              current is SavedPrintersLoaded &&
              (previous is! SavedPrintersLoaded ||
                  !listEquals(previous.printers, current.printers)),
          listener: (context, state) {
            if (state is SavedPrintersLoaded) {
              context.read<PrinterConnectionCubit>().checkAll(state.printers);
            }
          },
        ),
      ],
      child: Scaffold(
        backgroundColor: theme.background,
        appBar: DsPrintAppBar(title: strings.printers),
        body: Stack(
          children: [
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                  child: SizedBox(
                    width: double.infinity,
                    child: DsPrintAddPrinterButton(
                      onPrinterAdded: _handleAdded,
                      showBluetooth: widget.showBluetooth,
                      showLan: widget.showLan,
                    ),
                  ),
                ),
                Expanded(
                  child: BlocBuilder<SavedPrintersCubit, SavedPrintersState>(
                    builder: (context, state) => switch (state) {
                      SavedPrintersLoading() => const DsPrintLoadingIndicator(),
                      SavedPrintersLoaded(printers: final printers)
                          when printers.isEmpty =>
                        Center(
                          child: Text(strings.noPrintersAdded,
                              style: theme.bodyStyle),
                        ),
                      SavedPrintersLoaded(
                        printers: final printers,
                        selected: final selected
                      ) =>
                        RefreshIndicator(
                          onRefresh: () => context
                              .read<PrinterConnectionCubit>()
                              .checkAll(printers),
                          child: ListView.separated(
                            // Always scrollable so pull-to-refresh works with
                            // a short list.
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(24),
                            itemCount: printers.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 16),
                            itemBuilder: (context, index) {
                              final device = printers[index];
                              return Dismissible(
                                key: ValueKey(
                                    '${device.interfaceType.name}:${device.id}'),
                                direction: DismissDirection.endToStart,
                                confirmDismiss: (_) => _confirmRemove(),
                                onDismissed: (_) => context
                                    .read<SavedPrintersCubit>()
                                    .remove(device),
                                background: const _RemoveBackground(),
                                child: BlocSelector<
                                    PrinterConnectionCubit,
                                    PrinterConnectionState,
                                    PrinterConnectionStatus?>(
                                  selector: (state) => state.statuses[device],
                                  builder: (context, status) =>
                                      PrinterDeviceTile(
                                    device: device,
                                    isSelected: device == selected,
                                    connectionStatus: status,
                                    onTap: () => _handleTap(device),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      SavedPrintersFailure(failure: final failure) => Center(
                          child: Text(strings.forFailure(failure),
                              style: theme.bodyStyle),
                        ),
                    },
                  ),
                ),
              ],
            ),
            BlocBuilder<PrintJobCubit, PrintJobState>(
              builder: (context, state) => state is PrintJobInProgress
                  ? const Positioned.fill(child: DsPrintCapturingScrim())
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

class _RemoveBackground extends StatelessWidget {
  const _RemoveBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: AlignmentDirectional.centerEnd,
      padding: const EdgeInsetsDirectional.only(end: 24),
      decoration: BoxDecoration(
        color: Colors.red.shade400,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Icon(Icons.delete_outline, color: Colors.white),
    );
  }
}
