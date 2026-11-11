import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/printer_device.dart';
import '../../domain/usecases/check_printer_connection_usecase.dart';
import 'printer_connection_state.dart';

/// Reachability of each saved printer, for the Printers screen. Printers are
/// probed one at a time — they may share a radio, and the native side
/// serializes connections anyway.
class PrinterConnectionCubit extends Cubit<PrinterConnectionState> {
  final CheckPrinterConnectionUseCase _checkConnection;

  PrinterConnectionCubit(
      {required CheckPrinterConnectionUseCase checkConnection})
      : _checkConnection = checkConnection,
        super(const PrinterConnectionState());

  /// Bumped by every [checkAll] so an older, still-running pass stops
  /// emitting once a newer one starts.
  int _generation = 0;

  Future<void> checkAll(List<PrinterDevice> printers) async {
    final generation = ++_generation;
    var statuses = {
      for (final printer in printers) printer: PrinterConnectionStatus.checking,
    };
    if (isClosed) return;
    emit(PrinterConnectionState(Map.unmodifiable(statuses)));

    for (final printer in printers) {
      final result = await _checkConnection(printer);
      if (isClosed || generation != _generation) return;
      statuses = {
        ...statuses,
        printer: result.fold(
          (_) => PrinterConnectionStatus.disconnected,
          (reachable) => reachable
              ? PrinterConnectionStatus.connected
              : PrinterConnectionStatus.disconnected,
        ),
      };
      emit(PrinterConnectionState(Map.unmodifiable(statuses)));
    }
  }
}
