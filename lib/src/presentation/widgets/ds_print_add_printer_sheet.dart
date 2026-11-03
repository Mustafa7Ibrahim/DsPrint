import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/config/ds_print_config.dart';
import '../../core/config/ds_print_strings.dart';
import '../../core/config/ds_print_theme.dart';
import '../../core/di/ds_print_injection.dart';
import '../../core/value/ipv4_address.dart';
import '../../domain/entities/printer_device.dart';
import '../../domain/entities/printer_interface_type.dart';
import '../cubit/add_printer_cubit.dart';
import '../cubit/add_printer_state.dart';
import 'ds_print_loading.dart';
import 'printer_device_tile.dart';

/// The Add Printer bottom sheet: choose USB / LAN / Bluetooth, scan only that
/// type, tap a result to save it. LAN also takes a typed IP address.
///
/// Self-contained — it resolves its own cubit — so it opens from any screen,
/// not just [PrinterPickerScreen].
class DsPrintAddPrinterSheet extends StatelessWidget {
  /// The connection types offered, in display order. USB is always one.
  final List<PrinterInterfaceType> interfaceTypes;

  const DsPrintAddPrinterSheet({super.key, required this.interfaceTypes});

  /// Shows the sheet and completes with the printer the user added — already
  /// saved and made the active printer — or `null` if they closed it.
  ///
  /// [showBluetooth] / [showLan] hide that option for this sheet; null falls
  /// back to [DsPrintConfig], and then to showing it.
  static Future<PrinterDevice?> show(
    BuildContext context, {
    bool? showBluetooth,
    bool? showLan,
  }) {
    final types =
        availableTypes(showBluetooth: showBluetooth, showLan: showLan);
    return showModalBottomSheet<PrinterDevice>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DsPrintAddPrinterSheet(interfaceTypes: types),
    );
  }

  /// The options to offer, in the host app's legacy display order (LAN,
  /// Bluetooth, USB). An explicit argument wins over [DsPrintConfig], which
  /// wins over the default of showing everything. USB can't be hidden — the
  /// sheet always has at least one option.
  static List<PrinterInterfaceType> availableTypes({
    bool? showBluetooth,
    bool? showLan,
  }) {
    final config = DsPrintConfig.current;
    return [
      if (showLan ?? config?.showLan ?? true) PrinterInterfaceType.lan,
      if (showBluetooth ?? config?.showBluetooth ?? true)
        PrinterInterfaceType.bluetooth,
      PrinterInterfaceType.usb,
    ];
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) {
        final cubit = dsPrintResolve<AddPrinterCubit>();
        // With only one option there is nothing to choose — pre-select it so
        // the user goes straight to Next.
        if (interfaceTypes.length == 1) {
          cubit.chooseType(interfaceTypes.single);
        }
        return cubit;
      },
      child: _AddPrinterSheetView(interfaceTypes: interfaceTypes),
    );
  }
}

class _AddPrinterSheetView extends StatelessWidget {
  final List<PrinterInterfaceType> interfaceTypes;

  const _AddPrinterSheetView({required this.interfaceTypes});

  static const _radius = Radius.circular(28);

  @override
  Widget build(BuildContext context) {
    final theme = DsPrintTheme.of(context);
    final strings = DsPrintStrings.of(context);
    final maxHeight = MediaQuery.sizeOf(context).height * 0.85;
    return BlocListener<AddPrinterCubit, AddPrinterState>(
      listenWhen: (_, state) => state is AddPrinterAdded,
      listener: (context, state) =>
          Navigator.of(context).pop((state as AddPrinterAdded).device),
      child: Padding(
        // Keeps the manual-IP field above the keyboard.
        padding:
            EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Material(
            color: theme.surface,
            borderRadius: const BorderRadius.vertical(top: _radius),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  color: theme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      const SizedBox(width: 48),
                      Expanded(
                        child: Text(
                          strings.addPrinter,
                          textAlign: TextAlign.center,
                          style: theme.appBarTitleStyle,
                        ),
                      ),
                      IconButton(
                        key: const Key('ds_print_add_printer_close'),
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(Icons.cancel,
                            color: theme.appBarForeground, size: 30),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                    child: SafeArea(
                      top: false,
                      child: BlocBuilder<AddPrinterCubit, AddPrinterState>(
                        builder: (context, state) => switch (state) {
                          AddPrinterChoosingType(:final selected) =>
                            _ChooseTypeStep(
                              interfaceTypes: interfaceTypes,
                              selected: selected,
                            ),
                          AddPrinterSearching(:final interfaceType) =>
                            _SearchingStep(interfaceType: interfaceType),
                          AddPrinterResults(
                            :final interfaceType,
                            :final devices
                          ) =>
                            _ResultsStep(
                                interfaceType: interfaceType, devices: devices),
                          AddPrinterFailure(
                            :final interfaceType,
                            :final failure
                          ) =>
                            _MessageStep(
                              interfaceType: interfaceType,
                              message: strings.forFailure(failure),
                            ),
                          AddPrinterSaving() ||
                          AddPrinterAdded() =>
                            const Padding(
                              padding: EdgeInsets.all(32),
                              child: DsPrintLoadingIndicator(),
                            ),
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChooseTypeStep extends StatelessWidget {
  final List<PrinterInterfaceType> interfaceTypes;
  final PrinterInterfaceType? selected;

  const _ChooseTypeStep({required this.interfaceTypes, required this.selected});

  @override
  Widget build(BuildContext context) {
    final theme = DsPrintTheme.of(context);
    final strings = DsPrintStrings.of(context);
    final cubit = context.read<AddPrinterCubit>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(strings.chooseConnectionMethod,
            textAlign: TextAlign.center, style: theme.titleStyle),
        const SizedBox(height: 12),
        for (final type in interfaceTypes)
          InkWell(
            key: Key('ds_print_interface_${type.name}'),
            onTap: () => cubit.chooseType(type),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Checkbox(
                    value: selected == type,
                    activeColor: theme.primary,
                    onChanged: (_) => cubit.chooseType(type),
                  ),
                  const SizedBox(width: 8),
                  Icon(PrinterDeviceTile.iconFor(type), color: theme.primary),
                  const SizedBox(width: 12),
                  Text(strings.interfaceLabel(type), style: theme.titleStyle),
                ],
              ),
            ),
          ),
        const SizedBox(height: 28),
        _PrimaryButton(
          key: const Key('ds_print_add_printer_next'),
          label: strings.next,
          onPressed: selected == null ? null : cubit.search,
        ),
      ],
    );
  }
}

class _SearchingStep extends StatelessWidget {
  final PrinterInterfaceType interfaceType;

  const _SearchingStep({required this.interfaceType});

  @override
  Widget build(BuildContext context) {
    final theme = DsPrintTheme.of(context);
    final strings = DsPrintStrings.of(context);
    return Column(
      children: [
        const SizedBox(height: 16),
        const DsPrintLoadingIndicator(),
        const SizedBox(height: 20),
        Text(strings.searchingFor(interfaceType),
            textAlign: TextAlign.center, style: theme.bodyStyle),
        if (interfaceType == PrinterInterfaceType.bluetooth) ...[
          const SizedBox(height: 8),
          const _BluetoothPairingHint(),
        ],
        const SizedBox(height: 16),
      ],
    );
  }
}

class _ResultsStep extends StatelessWidget {
  final PrinterInterfaceType interfaceType;
  final List<PrinterDevice> devices;

  const _ResultsStep({required this.interfaceType, required this.devices});

  @override
  Widget build(BuildContext context) {
    if (devices.isEmpty) {
      return _MessageStep(
        interfaceType: interfaceType,
        message: DsPrintStrings.of(context).noDevicesConnected,
      );
    }
    final theme = DsPrintTheme.of(context);
    final strings = DsPrintStrings.of(context);
    final cubit = context.read<AddPrinterCubit>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(strings.selectOneDevice,
            textAlign: TextAlign.center, style: theme.titleStyle),
        const SizedBox(height: 16),
        for (final device in devices) ...[
          PrinterDeviceTile(
            device: device,
            isSelected: false,
            showSelectionIndicator: false,
            onTap: () => cubit.addDevice(device),
          ),
          const SizedBox(height: 12),
        ],
        if (interfaceType == PrinterInterfaceType.lan) const _ManualIpForm(),
        _BackButton(onPressed: cubit.back),
      ],
    );
  }
}

/// An empty scan, or a failed one: what happened, Retry, and Back.
class _MessageStep extends StatelessWidget {
  final PrinterInterfaceType interfaceType;
  final String message;

  const _MessageStep({required this.interfaceType, required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = DsPrintTheme.of(context);
    final strings = DsPrintStrings.of(context);
    final cubit = context.read<AddPrinterCubit>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(PrinterDeviceTile.iconFor(interfaceType),
            color: theme.primary, size: 40),
        const SizedBox(height: 12),
        Text(message, textAlign: TextAlign.center, style: theme.titleStyle),
        if (interfaceType == PrinterInterfaceType.bluetooth) ...[
          const SizedBox(height: 8),
          const _BluetoothPairingHint(),
        ],
        const SizedBox(height: 20),
        _PrimaryButton(
          key: const Key('ds_print_add_printer_retry'),
          label: strings.retry,
          onPressed: cubit.search,
        ),
        if (interfaceType == PrinterInterfaceType.lan) ...[
          const SizedBox(height: 20),
          const _ManualIpForm(),
        ],
        _BackButton(onPressed: cubit.back),
      ],
    );
  }
}

/// Bluetooth Classic discovery only lists printers already paired in
/// Android's settings — the Star SDK cannot pair one itself.
class _BluetoothPairingHint extends StatelessWidget {
  const _BluetoothPairingHint();

  @override
  Widget build(BuildContext context) {
    return Text(
      DsPrintStrings.of(context).pairBluetoothFirst,
      textAlign: TextAlign.center,
      style: DsPrintTheme.of(context).bodyStyle,
    );
  }
}

class _ManualIpForm extends StatefulWidget {
  const _ManualIpForm();

  @override
  State<_ManualIpForm> createState() => _ManualIpFormState();
}

class _ManualIpFormState extends State<_ManualIpForm> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    context.read<AddPrinterCubit>().addManualLan(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    final theme = DsPrintTheme.of(context);
    final strings = DsPrintStrings.of(context);
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(strings.enterIpManually, style: theme.bodyStyle),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  key: const Key('ds_print_manual_ip_field'),
                  controller: _controller,
                  textDirection: TextDirection.ltr,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  validator: (value) => isValidIpv4(value ?? '')
                      ? null
                      : strings.invalidIpAddress,
                  decoration: InputDecoration(
                    labelText: strings.ipAddress,
                    hintText: '192.168.1.100',
                    hintTextDirection: TextDirection.ltr,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: theme.primary, width: 2),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  key: const Key('ds_print_manual_ip_add'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.primary,
                    foregroundColor: theme.appBarForeground,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _submit,
                  child: Text(strings.add),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const _PrimaryButton({super.key, required this.label, this.onPressed});

  @override
  Widget build(BuildContext context) {
    final theme = DsPrintTheme.of(context);
    return SizedBox(
      height: 56,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.primary,
          foregroundColor: theme.appBarForeground,
          disabledBackgroundColor: theme.primary.withValues(alpha: 0.4),
          disabledForegroundColor: theme.appBarForeground,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: onPressed,
        child: Text(label),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _BackButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final theme = DsPrintTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: TextButton(
        key: const Key('ds_print_add_printer_back'),
        onPressed: onPressed,
        child: Text(DsPrintStrings.of(context).back,
            style: theme.actionStyle.copyWith(color: theme.primary)),
      ),
    );
  }
}
