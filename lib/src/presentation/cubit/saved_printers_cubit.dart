import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/printer_device.dart';
import '../../domain/usecases/get_saved_printers_usecase.dart';
import '../../domain/usecases/get_selected_printer_usecase.dart';
import '../../domain/usecases/remove_printer_usecase.dart';
import '../../domain/usecases/select_printer_usecase.dart';
import 'saved_printers_state.dart';

/// The printers screen's list: what the user has added, and which one is
/// active. It never scans — printers only get here through the Add Printer
/// sheet.
class SavedPrintersCubit extends Cubit<SavedPrintersState> {
  final GetSavedPrintersUseCase _getSavedPrinters;
  final GetSelectedPrinterUseCase _getSelectedPrinter;
  final SelectPrinterUseCase _selectPrinter;
  final RemovePrinterUseCase _removePrinter;

  SavedPrintersCubit({
    required GetSavedPrintersUseCase getSavedPrinters,
    required GetSelectedPrinterUseCase getSelectedPrinter,
    required SelectPrinterUseCase selectPrinter,
    required RemovePrinterUseCase removePrinter,
  })  : _getSavedPrinters = getSavedPrinters,
        _getSelectedPrinter = getSelectedPrinter,
        _selectPrinter = selectPrinter,
        _removePrinter = removePrinter,
        super(const SavedPrintersLoading());

  Future<void> load() async {
    final savedResult = await _getSavedPrinters();
    await savedResult.fold(
      (failure) async => emit(SavedPrintersFailure(failure)),
      (printers) async {
        final selectedResult = await _getSelectedPrinter();
        // A failed read of the active printer shouldn't hide the list —
        // fall back to "none selected".
        final selected = selectedResult.fold((_) => null, (device) => device);
        emit(SavedPrintersLoaded(printers, selected));
      },
    );
  }

  /// Makes [device] the printer every later print call uses.
  Future<void> select(PrinterDevice device) async {
    final result = await _selectPrinter(device);
    result.fold(
      (failure) => emit(SavedPrintersFailure(failure)),
      (_) => emit(SavedPrintersLoaded(_printers, device)),
    );
  }

  /// Drops [device] from the list straight away — a swiped-away
  /// [Dismissible] must leave the tree on the very next frame — then
  /// persists the removal. Removing the active printer clears the selection.
  Future<void> remove(PrinterDevice device) async {
    final current = state;
    if (current is SavedPrintersLoaded) {
      emit(SavedPrintersLoaded(
        current.printers.where((printer) => printer != device).toList(),
        current.selected == device ? null : current.selected,
      ));
    }
    final result = await _removePrinter(device);
    result.fold((failure) => emit(SavedPrintersFailure(failure)), (_) {});
  }

  /// The Add Printer sheet has already saved and activated [device]; re-read
  /// so the list shows it.
  Future<void> onPrinterAdded(PrinterDevice device) => load();

  List<PrinterDevice> get _printers => switch (state) {
        SavedPrintersLoaded(:final printers) => printers,
        _ => const [],
      };
}
