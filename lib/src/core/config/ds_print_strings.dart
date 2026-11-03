import 'package:flutter/widgets.dart';

import '../../domain/entities/printer_interface_type.dart';
import '../error/ds_print_failure.dart';

/// The package's own tiny localisation layer — deliberately independent of
/// easy_localization and the host app's `assets/translations/*.json`, so
/// ds_print stays zero-configuration for any host.
class DsPrintStrings {
  final String languageCode;

  const DsPrintStrings(this.languageCode);

  /// Defaults to `'ar'`, not `'en'`, because the host app defaults to
  /// Arabic when no [Localizations] widget is present yet in the tree.
  factory DsPrintStrings.of(BuildContext context) {
    final languageCode =
        Localizations.maybeLocaleOf(context)?.languageCode ?? 'ar';
    return DsPrintStrings(languageCode);
  }

  bool get _isArabic => languageCode == 'ar';

  String get taxInvoice => _isArabic ? 'الفاتورة الضريبية' : 'Tax Invoice';

  String get print_ => _isArabic ? 'طباعة' : 'Print';

  String get printers => _isArabic ? 'الطابعات' : 'Printers';

  String get addPrinter => _isArabic ? 'اضافة طابعة' : 'Add Printer';

  String get noPrinterConnected =>
      _isArabic ? 'لا يوجد طابعة متصلة' : 'No printer connected';

  String get noDevicesConnected =>
      _isArabic ? 'لا يوجد أجهزة متصلة' : 'No devices connected';

  String get chooseConnectionMethod =>
      _isArabic ? 'إختر وسيلة الربط' : 'Choose connection method';

  String get next => _isArabic ? 'التالي' : 'Next';

  String get retry => _isArabic ? 'إعادة المحاولة' : 'Retry';

  String get back => _isArabic ? 'رجوع' : 'Back';

  String get add => _isArabic ? 'إضافة' : 'Add';

  String get enterIpManually => _isArabic
      ? 'أو أدخل عنوان IP الخاص بالطابعة يدوياً'
      : "Or enter the printer's IP address manually";

  String get ipAddress => _isArabic ? 'عنوان IP' : 'IP address';

  String get invalidIpAddress =>
      _isArabic ? 'عنوان IP غير صالح' : 'Invalid IP address';

  String get noPrintersAdded =>
      _isArabic ? 'لم تتم إضافة أي طابعة بعد' : 'No printers added yet';

  String get removePrinterQuestion =>
      _isArabic ? 'هل تريد حذف هذه الطابعة؟' : 'Remove this printer?';

  String get remove => _isArabic ? 'حذف' : 'Remove';

  String get cancel => _isArabic ? 'إلغاء' : 'Cancel';

  String get pairBluetoothFirst => _isArabic
      ? 'قم بإقران الطابعة من إعدادات البلوتوث في جهازك أولاً'
      : "Pair the printer in your device's Bluetooth settings first";

  String get permissionDenied => _isArabic
      ? 'يرجى السماح بصلاحية "الأجهزة القريبة" للبحث عن الطابعات'
      : 'Allow the "Nearby devices" permission to search for printers';

  String get discoveryFailed => _isArabic
      ? 'تعذر البحث عن الطابعات. برجاء المحاولة مرة أخرى.'
      : 'Could not search for printers. Please try again.';

  /// How a connection type is shown to the user — the tile title and the
  /// options in the Add Printer sheet.
  String interfaceLabel(PrinterInterfaceType type) => switch (type) {
        PrinterInterfaceType.usb => 'USB',
        PrinterInterfaceType.lan => _isArabic ? 'شبكة (LAN)' : 'Network (LAN)',
        PrinterInterfaceType.bluetooth => _isArabic ? 'بلوتوث' : 'Bluetooth',
      };

  String searchingFor(PrinterInterfaceType type) => _isArabic
      ? 'جاري البحث عن طابعات ${interfaceLabel(type)} ...'
      : 'Searching for ${interfaceLabel(type)} printers ...';

  String interfaceUnavailable(PrinterInterfaceType type) => switch (type) {
        PrinterInterfaceType.usb =>
          _isArabic ? 'منفذ USB غير متاح على هذا الجهاز' : 'USB is unavailable',
        PrinterInterfaceType.lan => _isArabic
            ? 'برجاء الاتصال بالشبكة أولاً'
            : 'Connect to the network first',
        PrinterInterfaceType.bluetooth =>
          _isArabic ? 'برجاء تشغيل البلوتوث أولاً' : 'Turn on Bluetooth first',
      };

  String get selectOneDevice =>
      _isArabic ? 'اختر جهاز واحد' : 'Select one device';

  String get nothingToPrint =>
      _isArabic ? 'لا يوجد فاتورة للطباعة' : 'There is no invoice to print';

  String get captureFailed => _isArabic
      ? 'فشل في تجهيز صورة الفاتورة. برجاء المحاولة مرة أخرى.'
      : 'Failed to capture invoice. Please try again.';

  String get androidOnly => _isArabic
      ? 'الطباعة متاحة على أندرويد فقط'
      : 'Printing is only available on Android';

  String get printFailed => _isArabic
      ? 'فشلت الطباعة. برجاء المحاولة مرة أخرى.'
      : 'Printing failed. Please try again.';

  String get storageFailed => _isArabic
      ? 'تعذر قراءة الطابعة المحفوظة.'
      : 'Could not read the saved printer.';

  String get ok => _isArabic ? 'حسناً' : 'OK';

  /// The single place a [DsPrintFailure] becomes user-facing copy. The
  /// exhaustive switch (no `default`) makes adding a new [DsPrintFailure]
  /// subtype a compile error here until it's given a translation.
  String forFailure(DsPrintFailure failure) {
    return switch (failure) {
      EmptyPayloadFailure() => nothingToPrint,
      NoDeviceFoundFailure() => noPrinterConnected,
      NoPrinterSelectedFailure() => selectOneDevice,
      UnsupportedPlatformFailure() => androidOnly,
      CaptureFailure() => captureFailed,
      NativePrintFailure() => printFailed,
      StorageFailure() => storageFailed,
      NotConfiguredFailure() => printFailed,
      PermissionDeniedFailure() => permissionDenied,
      InterfaceUnavailableFailure(:final interfaceType) =>
        interfaceUnavailable(interfaceType),
      DiscoveryFailure() => discoveryFailed,
    };
  }
}
