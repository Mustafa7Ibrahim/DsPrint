import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/config/ds_print_strings.dart';
import '../../core/config/ds_print_theme.dart';
import '../../core/di/ds_print_injection.dart';
import '../../domain/entities/print_payload.dart';
import '../../domain/entities/printer_device.dart';
import '../cubit/print_job_cubit.dart';
import '../cubit/print_job_state.dart';
import '../cubit/printer_discovery_cubit.dart';
import '../cubit/printer_discovery_state.dart';
import '../widgets/ds_print_message_dialog.dart';
import '../widgets/printer_device_tile.dart';

/// `payload == null` means "pick/pair a device only" (used from
/// [DsPrint.selectDevice]); a non-null payload additionally prints it to
/// whichever device is tapped. This collapses the host's three-valued
/// `EnumPrinterScreenMode` into one nullable field — the html/base64
/// distinction already lives on the [PrintPayload] subtype.
class PrinterPickerScreen extends StatelessWidget {
  final PrintPayload? payload;

  const PrinterPickerScreen({super.key, this.payload});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => dsPrintSl<PrinterDiscoveryCubit>()),
        BlocProvider(create: (_) => dsPrintSl<PrintJobCubit>()),
      ],
      child: _PrinterPickerView(payload: payload),
    );
  }
}

class _PrinterPickerView extends StatefulWidget {
  final PrintPayload? payload;

  const _PrinterPickerView({this.payload});

  @override
  State<_PrinterPickerView> createState() => _PrinterPickerViewState();
}

class _PrinterPickerViewState extends State<_PrinterPickerView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<PrinterDiscoveryCubit>().discover();
    });
  }

  void _handleTap(PrinterDevice device) {
    context.read<PrinterDiscoveryCubit>().select(device);
    final payload = widget.payload;
    if (payload != null) {
      context.read<PrintJobCubit>().printTo(device, payload);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = DsPrintStrings.of(context);
    return BlocListener<PrintJobCubit, PrintJobState>(
      listener: (context, state) {
        if (state is PrintJobCompleted) {
          Navigator.of(context).pop();
        } else if (state is PrintJobFailure) {
          DsPrintMessageDialog.show(context, strings.forFailure(state.failure));
        }
      },
      child: Scaffold(
        appBar: AppBar(title: Text(strings.printers), centerTitle: true),
        body: BlocBuilder<PrinterDiscoveryCubit, PrinterDiscoveryState>(
          builder: (context, state) => switch (state) {
            PrinterDiscoveryInitial() ||
            PrinterDiscoveryLoading() =>
              const Center(
                child: CircularProgressIndicator(),
              ),
            PrinterDiscoverySuccess(devices: final devices)
                when devices.isEmpty =>
              const Center(
                child: AddPrinterButton(),
              ),
            PrinterDiscoverySuccess(
              devices: final devices,
              selected: final selected
            ) =>
              ListView.separated(
                padding: const EdgeInsets.all(25),
                itemCount: devices.length,
                separatorBuilder: (_, __) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final device = devices[index];
                  return PrinterDeviceTile(
                    device: device,
                    isSelected: device == selected,
                    onTap: () => _handleTap(device),
                  );
                },
              ),
            PrinterDiscoveryFailure(failure: final failure) => Center(
                child: Text(strings.forFailure(failure),
                    style: DsPrintTheme.of(context).bodyStyle),
              ),
          },
        ),
      ),
    );
  }
}

class AddPrinterButton extends StatelessWidget {
  const AddPrinterButton({super.key});

  Future<void> _handlePressed(BuildContext context) async {
    final cubit = context.read<PrinterDiscoveryCubit>();
    await cubit.discover();
    if (!context.mounted) return;
    final state = cubit.state;
    final stillEmpty =
        state is PrinterDiscoverySuccess && state.devices.isEmpty;
    if (stillEmpty) {
      await DsPrintMessageDialog.show(
          context, DsPrintStrings.of(context).noPrinterConnected);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () => _handlePressed(context),
      child: Text(DsPrintStrings.of(context).addPrinter),
    );
  }
}
