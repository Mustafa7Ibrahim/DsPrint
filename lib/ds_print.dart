/// ds_print — reusable invoice preview and thermal-printing plugin
/// (Star Micronics StarXpand).
///
/// Zero-configuration by design: the host app adds this package as a path
/// dependency and calls the exported API — nothing else to wire up.
/// Repositories, use cases, datasources and dependency injection are
/// internal and intentionally not exported.
// ignore_for_file: unnecessary_library_name

library ds_print;

export 'src/core/config/ds_print_config.dart';
export 'src/core/config/ds_print_theme.dart';
export 'src/core/error/ds_print_failure.dart';
export 'src/core/value/paper_width.dart';
export 'src/domain/entities/print_payload.dart';
export 'src/domain/entities/printer_device.dart';
export 'src/domain/entities/printer_interface_type.dart';
export 'src/ds_print_facade.dart';
// `show` keeps this package's public surface to exactly the screens
// themselves — both files also declare internal helper widgets
// (PrintActionButton, AddPrinterButton) that aren't part of the API.
export 'src/presentation/screens/invoice_preview_screen.dart'
    show InvoicePreviewScreen;
export 'src/presentation/screens/printer_picker_screen.dart'
    show PrinterPickerScreen;
