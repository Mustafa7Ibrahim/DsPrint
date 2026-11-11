import 'dart:developer';

import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';

import 'core/config/ds_print_config.dart';
import 'core/context/root_context_resolver.dart';
import 'core/di/ds_print_injection.dart';
import 'core/error/ds_print_failure.dart';
import 'domain/entities/print_payload.dart';
import 'domain/entities/printer_device.dart';
import 'domain/entities/printer_interface_type.dart';
import 'domain/usecases/auto_print_usecase.dart';
import 'domain/usecases/capture_invoice_usecase.dart';
import 'domain/usecases/check_printer_connection_usecase.dart';
import 'domain/usecases/discover_printers_usecase.dart';
import 'domain/usecases/get_saved_printers_usecase.dart';
import 'domain/usecases/get_selected_printer_usecase.dart';
import 'domain/usecases/resolve_print_device_usecase.dart';
import 'presentation/screens/invoice_preview_screen.dart';
import 'presentation/screens/printer_picker_screen.dart';
import 'presentation/widgets/ds_print_add_printer_sheet.dart';

/// Public entry point for ds_print. Zero configuration required: every
/// method below either resolves through [dsPrintResolve] itself or pushes a
/// screen that does (both initialise the DI container lazily, idempotently),
/// so a host app only needs a path dependency on this package and a call to
/// one of these static methods — no setup call, no injected
/// theme/strings/storage.
class DsPrint {
  const DsPrint._();

  /// Optional. Overrides the navigator ds_print resolves a [BuildContext]
  /// from, the theme it renders with, or the native-print result timeout.
  /// Everything below works without ever calling this.
  static void configure(DsPrintConfig config) {
    DsPrintConfig.current = config;
  }

  /// Pushes the invoice preview screen (which owns its own Print action) on
  /// top of the nearest resolvable navigator.
  static Future<void> url(String url,
      {BuildContext? context, String? title}) async {
    log('DsPrint.url: url=$url');
    final resolvedContext = RootContextResolver.resolve(explicit: context);
    if (resolvedContext == null) {
      throw StateError(
        'DsPrint.url: could not resolve a BuildContext — pass `context:` '
        'explicitly, or call DsPrint.configure with a navigatorKey.',
      );
    }
    // An imperative root-navigator push, not go_router: the host app's
    // CLAUDE.md documents that context.push on a shell-nested go_router path
    // from a route outside the shell crashes with a duplicate-Page-key
    // assertion. A plain MaterialPageRoute pushed on the root Navigator
    // sidesteps go_router — and that failure mode — entirely.
    await Navigator.of(
      resolvedContext,
      rootNavigator: true,
    ).push(MaterialPageRoute(
        builder: (_) => InvoicePreviewScreen(url: url, title: title)));
  }

  /// Captures [url] headlessly (no visible screen) and prints it straight to
  /// the printer the user selected.
  ///
  /// Returns `Left(NoPrinterSelectedFailure)` and does nothing at all when no
  /// printer is selected — no render, no overlay, no scrim, and no discovery
  /// scan: pairing is manual (see [addPrinter]). Callers that print
  /// automatically (order creation) can therefore fire this unconditionally:
  /// a store without a printer simply gets nothing, silently.
  ///
  /// Before rendering, the selected printer gets a short connection check
  /// (`DsPrintConfig.connectionCheckTimeout`, 3 s USB/LAN and 5 s Bluetooth by
  /// default). A printer that does not answer returns
  /// `Left(PrinterUnreachableFailure)` immediately — no render, no scrim —
  /// instead of failing after the capture and a long connect timeout. If the
  /// check itself errors, printing proceeds as normal so a faulty probe never
  /// blocks a print.
  ///
  /// Pass [connectionCheck] (from [checkSelectedPrinterConnection]) to reuse a
  /// check the host started earlier instead of starting a new one here.
  static Future<Either<DsPrintFailure, Unit>> printUrlSilently(
    String url, {
    int copies = 1,
    Future<Either<DsPrintFailure, bool>>? connectionCheck,
  }) async {
    // Logged before anything else runs, so the incoming link is on record even
    // when the call returns early because no printer was found — otherwise a
    // silent no-op is indistinguishable from a bad url.
    log('DsPrint.printUrlSilently: url=$url copies=$copies');
    // Find the printer *first*. Rendering an invoice takes a WebView, a
    // couple of seconds and a blocking scrim — so the original
    // capture-then-look-for-a-device order made a store with no printer
    // freeze, then print nothing. The resolve inside AutoPrintUseCase below
    // is the same cheap cached read.
    final deviceResult = await dsPrintResolve<ResolvePrintDeviceUseCase>()();
    return deviceResult.fold(
      (failure) async => Left(failure),
      (device) async {
        final connection = await (connectionCheck ??
            dsPrintResolve<CheckPrinterConnectionUseCase>()(device));
        final unreachable = connection.fold((failure) {
          log('DsPrint.printUrlSilently: connection check errored, '
              'printing anyway - ${failure.debugMessage}');
          return false;
        }, (reachable) => !reachable);
        if (unreachable) return const Left(PrinterUnreachableFailure());

        final captureResult =
            await dsPrintResolve<CaptureInvoiceUseCase>()(url);
        return captureResult.fold(
          (failure) async => Left(failure),
          (payload) =>
              dsPrintResolve<AutoPrintUseCase>()(payload, copies: copies),
        );
      },
    );
  }

  /// Opens and closes a connection to [device] with a short timeout
  /// (`DsPrintConfig.connectionCheckTimeout`, 3 s USB/LAN and 5 s Bluetooth by
  /// default) to see whether it is reachable. `Right(false)` means it did not answer. Serialized with
  /// print jobs, so it waits for a running job instead of competing with it.
  static Future<Either<DsPrintFailure, bool>> checkConnection(
      PrinterDevice device) {
    return dsPrintResolve<CheckPrinterConnectionUseCase>()(device);
  }

  /// Starts a connection check of the selected printer without printing.
  /// `Left(NoPrinterSelectedFailure)` when none is selected. A host that prints
  /// right after a network call can start this before the call and hand the
  /// future to [printUrlSilently] (`connectionCheck:`), so the check overlaps
  /// the request instead of running after it.
  static Future<Either<DsPrintFailure, bool>>
      checkSelectedPrinterConnection() async {
    final deviceResult = await dsPrintResolve<ResolvePrintDeviceUseCase>()();
    return deviceResult.fold(
      (failure) async => Left(failure),
      (device) => dsPrintResolve<CheckPrinterConnectionUseCase>()(device),
    );
  }

  /// Prints to the selected printer; `Left(NoPrinterSelectedFailure)` when
  /// there is none.
  static Future<Either<DsPrintFailure, Unit>> printBase64(String base64,
      {int copies = 1}) {
    return dsPrintResolve<AutoPrintUseCase>()(ImageBase64Payload.single(base64),
        copies: copies);
  }

  /// Prints to the selected printer; `Left(NoPrinterSelectedFailure)` when
  /// there is none.
  static Future<Either<DsPrintFailure, Unit>> printHtml(String html) {
    return dsPrintResolve<AutoPrintUseCase>()(HtmlPayload(html));
  }

  /// Pushes the printers screen with no payload attached — add printers and
  /// choose the active one without printing anything. [showBluetooth] /
  /// [showLan] hide that option in Add Printer; null falls back to
  /// [DsPrintConfig].
  static Future<void> selectDevice({
    BuildContext? context,
    bool? showBluetooth,
    bool? showLan,
  }) async {
    final resolvedContext = RootContextResolver.resolve(explicit: context);
    if (resolvedContext == null) {
      throw StateError(
        'DsPrint.selectDevice: could not resolve a BuildContext — pass '
        '`context:` explicitly, or call DsPrint.configure with a navigatorKey.',
      );
    }
    await Navigator.of(
      resolvedContext,
      rootNavigator: true,
    ).push(MaterialPageRoute(
        builder: (_) => PrinterPickerScreen(
              showBluetooth: showBluetooth,
              showLan: showLan,
            )));
  }

  /// Opens the Add Printer sheet over whatever is on screen: the user picks
  /// USB / LAN / Bluetooth, scans that type (or types a LAN IP address) and
  /// taps a printer.
  ///
  /// Completes with the added printer — already saved and made the active
  /// printer every print call uses — or `null` if the user closed the sheet.
  /// [DsPrintAddPrinterButton] is this, as a ready-made button.
  ///
  /// [showBluetooth] / [showLan] hide that option; null falls back to
  /// [DsPrintConfig], and then to showing it.
  static Future<PrinterDevice?> addPrinter({
    BuildContext? context,
    bool? showBluetooth,
    bool? showLan,
  }) {
    final resolvedContext = RootContextResolver.resolve(explicit: context);
    if (resolvedContext == null) {
      throw StateError(
        'DsPrint.addPrinter: could not resolve a BuildContext — pass '
        '`context:` explicitly, or call DsPrint.configure with a navigatorKey.',
      );
    }
    return DsPrintAddPrinterSheet.show(
      resolvedContext,
      showBluetooth: showBluetooth,
      showLan: showLan,
    );
  }

  /// Every printer the user has added, in the order they were added.
  static Future<Either<DsPrintFailure, List<PrinterDevice>>> savedPrinters() {
    return dsPrintResolve<GetSavedPrintersUseCase>()();
  }

  /// The printer every print call goes to, or `null` when none is selected.
  static Future<Either<DsPrintFailure, PrinterDevice?>> selectedPrinter() {
    return dsPrintResolve<GetSelectedPrinterUseCase>()();
  }

  /// Scans for printers without saving anything. [interfaceType] restricts
  /// the scan to one connection type; `null` scans USB and LAN.
  static Future<Either<DsPrintFailure, List<PrinterDevice>>> discover({
    PrinterInterfaceType? interfaceType,
  }) {
    return dsPrintResolve<DiscoverPrintersUseCase>()(
        interfaceType: interfaceType);
  }
}
