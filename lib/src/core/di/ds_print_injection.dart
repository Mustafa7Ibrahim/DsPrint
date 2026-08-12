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
import '../../domain/usecases/resolve_print_device_usecase.dart';
import '../../domain/usecases/select_printer_usecase.dart';
import '../../presentation/cubit/invoice_preview_cubit.dart';
import '../../presentation/cubit/print_job_cubit.dart';
import '../../presentation/cubit/printer_discovery_cubit.dart';
import '../../presentation/renderer/overlay_invoice_renderer.dart';
import '../config/ds_print_config.dart';

/// Private to ds_print — deliberately not the host app's global `sl`, so this
/// package's registrations never collide with the ~1200 lines already
/// registered there.
final GetIt dsPrintSl = GetIt.asNewInstance();

// Native channel names — must match `DsPrintPlugin.kt` exactly; a mismatch
// here is a silent runtime no-op on the Android side, not a build error.
const _discoveryEventChannelName = 'com.printer.discover/event';
const _printMethodChannelName = 'com.printer.html/sendToNative';
const _printResultEventChannelName = 'com.printer.html/listenFromNative';

/// Registers every ds_print dependency: datasources → repositories → use
/// cases → cubits. Safe to call more than once — every entry point calls
/// this lazily, so the host never has to.
///
/// Guarded by container state, not a bool flag: a bool can desync from
/// [dsPrintSl] (e.g. `dsPrintSl.reset()` empties the container but would
/// leave a flag `true`), silently skipping re-registration. [AutoPrintUseCase]
/// is registered near the end of the sequence below, so its presence is a
/// reliable sentinel for "fully registered".
void dsPrintInjection() {
  if (dsPrintSl.isRegistered<AutoPrintUseCase>()) return;

  // datasources
  dsPrintSl.registerLazySingleton<PrinterDiscoveryDataSource>(
    () => const PrinterDiscoveryDataSourceImpl(
        eventChannel: EventChannel(_discoveryEventChannelName)),
  );
  dsPrintSl.registerLazySingleton<PrinterNativeDataSource>(
    () => PrinterNativeDataSourceImpl(
      methodChannel: const MethodChannel(_printMethodChannelName),
      eventChannel: const EventChannel(_printResultEventChannelName),
      // Read inside the factory, not at registration time, so a
      // `DsPrint.configure()` made any time before the first print still
      // applies. Null keeps the datasource's own 20s default.
      resultTimeout: DsPrintConfig.current?.printResultTimeout ??
          const Duration(seconds: 20),
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
    () => ResolvePrintDeviceUseCase(
      getSelectedPrinter: dsPrintSl<GetSelectedPrinterUseCase>(),
      selectPrinter: dsPrintSl<SelectPrinterUseCase>(),
      discoverPrinters: dsPrintSl<DiscoverPrintersUseCase>(),
    ),
  );
  dsPrintSl.registerLazySingleton(
    () => AutoPrintUseCase(
      resolveDevice: dsPrintSl<ResolvePrintDeviceUseCase>(),
      clearSelectedPrinter: dsPrintSl<ClearSelectedPrinterUseCase>(),
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
}

bool get isDsPrintInitialised => dsPrintSl.isRegistered<AutoPrintUseCase>();

/// Resolves a ds_print dependency, initialising the container first.
///
/// Every entry point must go through here rather than touching [dsPrintSl]
/// directly. The exported screens are entry points too — a host app's
/// router can build `InvoicePreviewScreen` without ever calling a
/// `DsPrint.*` method, and resolving straight from [dsPrintSl] in that case
/// threw "InvoicePreviewCubit is not registered".
T dsPrintResolve<T extends Object>() {
  dsPrintInjection();
  return dsPrintSl<T>();
}
