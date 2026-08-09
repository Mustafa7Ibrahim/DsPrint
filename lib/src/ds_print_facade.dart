import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';

import 'core/config/ds_print_config.dart';
import 'core/context/root_context_resolver.dart';
import 'core/di/ds_print_injection.dart';
import 'core/error/ds_print_failure.dart';
import 'domain/entities/print_payload.dart';
import 'domain/entities/printer_device.dart';
import 'domain/usecases/auto_print_usecase.dart';
import 'domain/usecases/capture_invoice_usecase.dart';
import 'domain/usecases/discover_printers_usecase.dart';
import 'presentation/screens/invoice_preview_screen.dart';
import 'presentation/screens/printer_picker_screen.dart';

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
  /// the cached, or else first-discovered-and-cached, device.
  static Future<Either<DsPrintFailure, Unit>> printUrlSilently(String url,
      {int copies = 1}) async {
    final captureResult = await dsPrintResolve<CaptureInvoiceUseCase>()(url);
    return captureResult.fold(
      (failure) async => Left(failure),
      (payload) => dsPrintResolve<AutoPrintUseCase>()(payload, copies: copies),
    );
  }

  static Future<Either<DsPrintFailure, Unit>> printBase64(String base64,
      {int copies = 1}) {
    return dsPrintResolve<AutoPrintUseCase>()(ImageBase64Payload(base64),
        copies: copies);
  }

  static Future<Either<DsPrintFailure, Unit>> printHtml(String html) {
    return dsPrintResolve<AutoPrintUseCase>()(HtmlPayload(html));
  }

  /// Pushes the device picker with no payload attached — pick/pair a
  /// printer without printing anything.
  static Future<void> selectDevice({BuildContext? context}) async {
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
    ).push(MaterialPageRoute(builder: (_) => const PrinterPickerScreen()));
  }

  static Future<Either<DsPrintFailure, List<PrinterDevice>>> discover() {
    return dsPrintResolve<DiscoverPrintersUseCase>()();
  }
}
