import 'package:flutter/widgets.dart';

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

  String get searchingForDevices => _isArabic
      ? 'جاري البحث عن أجهزة يو اس بي متصلة ...'
      : 'searching for connected usb devices ...';

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
    };
  }
}
