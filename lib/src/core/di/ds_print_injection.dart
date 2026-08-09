import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';

import '../../data/datasources/printer_discovery_datasource.dart';
import '../../data/datasources/printer_native_datasource.dart';
import '../../data/datasources/selected_printer_datasource.dart';
import '../../data/repositories/invoice_capture_repository_impl.dart';
import '../../data/repositories/printer_discovery_repository_impl.dart';
import '../../data/repositories/printer_repository_impl.dart';
import '../../data/repositories/selected_printer_repository_impl.dart';
import '../../data/services/print_job_queue.dart';
import '../../domain/ports/invoice_render_port.dart';
import '../../domain/repositories/invoice_capture_repository.dart';
import '../../domain/repositories/printer_discovery_repository.dart';
import '../../domain/repositories/printer_repository.dart';
import '../../domain/repositories/selected_printer_repository.dart';
import '../../domain/usecases/auto_print_usecase.dart';
import '../../domain/usecases/capture_invoice_usecase.dart';
import '../../domain/usecases/clear_selected_printer_usecase.dart';
import '../../domain/usecases/discover_printers_usecase.dart';
import '../../domain/usecases/get_selected_printer_usecase.dart';
import '../../domain/usecases/print_job_usecase.dart';
import '../../domain/usecases/select_printer_usecase.dart';
import '../../presentation/cubit/invoice_preview_cubit.dart';
import '../../presentation/cubit/print_job_cubit.dart';
import '../../presentation/cubit/printer_discovery_cubit.dart';
import '../../presentation/renderer/overlay_invoice_renderer.dart';

/// Private to ds_print — deliberately not the host app's global `sl`, so this
/// package's registrations never collide with the ~1200 lines already
/// registered there.
final GetIt dsPrintSl = GetIt.asNewInstance();

bool _isDsPrintInitialised = false;

// Native channel names — must match `DsPrintPlugin.kt` exactly; a mismatch
// here is a silent runtime no-op on the Android side, not a build error.
const _discoveryEventChannelName = 'com.printer.discover/event';
const _printMethodChannelName = 'com.printer.html/sendToNative';
const _printResultEventChannelName = 'com.printer.html/listenFromNative';

/// Registers every ds_print dependency: datasources → repositories → use
/// cases → cubits. Safe to call more than once — the facade calls this
/// lazily before every public entry point, so the host never has to.
void dsPrintInjection() {
  if (_isDsPrintInitialised) return;

  // datasources
  dsPrintSl.registerLazySingleton<PrinterDiscoveryDataSource>(
    () => PrinterDiscoveryDataSourceImpl(
        eventChannel: const EventChannel(_discoveryEventChannelName)),
  );
  dsPrintSl.registerLazySingleton<PrinterNativeDataSource>(
    () => PrinterNativeDataSourceImpl(
      methodChannel: const MethodChannel(_printMethodChannelName),
      eventChannel: const EventChannel(_printResultEventChannelName),
    ),
  );
  dsPrintSl.registerLazySingleton<SelectedPrinterDataSource>(
      () => const SelectedPrinterDataSourceImpl());
  dsPrintSl
      .registerLazySingleton<InvoiceRenderPort>(() => OverlayInvoiceRenderer());
  dsPrintSl.registerLazySingleton(() => PrintJobQueue());

  // repositories
  dsPrintSl.registerLazySingleton<InvoiceCaptureRepository>(
    () => InvoiceCaptureRepositoryImpl(dsPrintSl<InvoiceRenderPort>()),
  );
  dsPrintSl.registerLazySingleton<PrinterDiscoveryRepository>(
    () =>
        PrinterDiscoveryRepositoryImpl(dsPrintSl<PrinterDiscoveryDataSource>()),
  );
  dsPrintSl.registerLazySingleton<PrinterRepository>(
    () => PrinterRepositoryImpl(
      dataSource: dsPrintSl<PrinterNativeDataSource>(),
      queue: dsPrintSl<PrintJobQueue>(),
    ),
  );
  dsPrintSl.registerLazySingleton<SelectedPrinterRepository>(
    () => SelectedPrinterRepositoryImpl(dsPrintSl<SelectedPrinterDataSource>()),
  );

  // use cases
  dsPrintSl.registerLazySingleton(
      () => CaptureInvoiceUseCase(dsPrintSl<InvoiceCaptureRepository>()));
  dsPrintSl.registerLazySingleton(() =>
      ClearSelectedPrinterUseCase(dsPrintSl<SelectedPrinterRepository>()));
  dsPrintSl.registerLazySingleton(
      () => DiscoverPrintersUseCase(dsPrintSl<PrinterDiscoveryRepository>()));
  dsPrintSl.registerLazySingleton(
      () => GetSelectedPrinterUseCase(dsPrintSl<SelectedPrinterRepository>()));
  dsPrintSl.registerLazySingleton(
      () => PrintJobUseCase(dsPrintSl<PrinterRepository>()));
  dsPrintSl.registerLazySingleton(
      () => SelectPrinterUseCase(dsPrintSl<SelectedPrinterRepository>()));
  dsPrintSl.registerLazySingleton(
    () => AutoPrintUseCase(
      getSelectedPrinter: dsPrintSl<GetSelectedPrinterUseCase>(),
      selectPrinter: dsPrintSl<SelectPrinterUseCase>(),
      clearSelectedPrinter: dsPrintSl<ClearSelectedPrinterUseCase>(),
      discoverPrinters: dsPrintSl<DiscoverPrintersUseCase>(),
      printJob: dsPrintSl<PrintJobUseCase>(),
    ),
  );

  // cubits
  dsPrintSl.registerFactory(
      () => InvoicePreviewCubit(dsPrintSl<CaptureInvoiceUseCase>()));
  dsPrintSl.registerFactory(
    () => PrintJobCubit(
        autoPrint: dsPrintSl<AutoPrintUseCase>(),
        printJob: dsPrintSl<PrintJobUseCase>()),
  );
  dsPrintSl.registerFactory(
    () => PrinterDiscoveryCubit(
      discoverPrinters: dsPrintSl<DiscoverPrintersUseCase>(),
      getSelectedPrinter: dsPrintSl<GetSelectedPrinterUseCase>(),
      selectPrinter: dsPrintSl<SelectPrinterUseCase>(),
    ),
  );

  _isDsPrintInitialised = true;
}

bool get isDsPrintInitialised => _isDsPrintInitialised;
