import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/printer_device.dart';
import '../../domain/usecases/discover_printers_usecase.dart';
import '../../domain/usecases/get_selected_printer_usecase.dart';
import '../../domain/usecases/select_printer_usecase.dart';
import 'printer_discovery_state.dart';

class PrinterDiscoveryCubit extends Cubit<PrinterDiscoveryState> {
  final DiscoverPrintersUseCase _discoverPrinters;
  final GetSelectedPrinterUseCase _getSelectedPrinter;
  final SelectPrinterUseCase _selectPrinter;

  PrinterDiscoveryCubit({
    required DiscoverPrintersUseCase discoverPrinters,
    required GetSelectedPrinterUseCase getSelectedPrinter,
    required SelectPrinterUseCase selectPrinter,
  })  : _discoverPrinters = discoverPrinters,
        _getSelectedPrinter = getSelectedPrinter,
        _selectPrinter = selectPrinter,
        super(const PrinterDiscoveryInitial());

  /// An empty result is a valid [PrinterDiscoverySuccess] (not a failure) —
  /// the picker screen renders its own "Add Printer" empty state from that.
  Future<void> discover() async {
    emit(const PrinterDiscoveryLoading());
    final discoveredResult = await _discoverPrinters();
    await discoveredResult.fold(
      (failure) async => emit(PrinterDiscoveryFailure(failure)),
      (devices) async {
        final selectedResult = await _getSelectedPrinter();
        selectedResult.fold(
          // A failed read of the cached selection shouldn't hide the devices
          // that were just discovered — fall back to "no selection".
          (_) => emit(PrinterDiscoverySuccess(devices, null)),
          (selected) => emit(PrinterDiscoverySuccess(devices, selected)),
        );
      },
    );
  }

  Future<void> select(PrinterDevice device) async {
    final currentState = state;
    final devices = currentState is PrinterDiscoverySuccess
        ? currentState.devices
        : const <PrinterDevice>[];
    final saveResult = await _selectPrinter(device);
    saveResult.fold(
      (failure) => emit(PrinterDiscoveryFailure(failure)),
      (_) => emit(PrinterDiscoverySuccess(devices, device)),
    );
  }
}
