import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ds_print/src/core/config/ds_print_strings.dart';
import 'package:ds_print/src/core/error/ds_print_failure.dart';

void main() {
  // Every getter on DsPrintStrings, used to drive the "en vs ar differ and
  // are non-empty" sweep below without hand-listing them twice.
  List<String> allGetterValues(DsPrintStrings s) => [
        s.taxInvoice,
        s.print_,
        s.printers,
        s.addPrinter,
        s.noPrinterConnected,
        s.noDevicesConnected,
        s.searchingForDevices,
        s.selectOneDevice,
        s.nothingToPrint,
        s.captureFailed,
        s.androidOnly,
        s.printFailed,
        s.storageFailed,
        s.ok,
      ];

  group('DsPrintStrings(languageCode)', () {
    test('en and ar return different, non-empty values for every getter', () {
      final en = allGetterValues(const DsPrintStrings('en'));
      final ar = allGetterValues(const DsPrintStrings('ar'));

      expect(en.length, ar.length);
      for (var i = 0; i < en.length; i++) {
        expect(en[i], isNotEmpty, reason: 'en getter at index $i was empty');
        expect(ar[i], isNotEmpty, reason: 'ar getter at index $i was empty');
        expect(en[i], isNot(equals(ar[i])),
            reason: 'en/ar identical at index $i');
      }
    });
  });

  group('DsPrintStrings.of', () {
    testWidgets(
        'falls back to Arabic when no Locale is resolvable from the context',
        (tester) async {
      late BuildContext capturedContext;
      // Deliberately no MaterialApp/WidgetsApp here - neither wraps a
      // Localizations widget, so Localizations.maybeLocaleOf is null and
      // DsPrintStrings.of must fall back to 'ar' per its own doc comment.
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Builder(
            builder: (context) {
              capturedContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      final strings = DsPrintStrings.of(capturedContext);

      expect(strings.languageCode, 'ar');
      expect(strings.taxInvoice, const DsPrintStrings('ar').taxInvoice);
    });
  });

  group('DsPrintStrings.forFailure', () {
    test('returns a non-empty string for every DsPrintFailure subtype', () {
      const strings = DsPrintStrings('en');
      // Enumerated explicitly (not looped over a generated list) so a new
      // DsPrintFailure subtype without a case here fails this test, not just
      // the exhaustive switch inside forFailure.
      const failures = <DsPrintFailure>[
        EmptyPayloadFailure(),
        NoDeviceFoundFailure(),
        NoPrinterSelectedFailure(),
        UnsupportedPlatformFailure(),
        CaptureFailure(null),
        NativePrintFailure(null),
        StorageFailure(null),
        NotConfiguredFailure('no navigator'),
      ];
      expect(failures.length, 8);

      for (final failure in failures) {
        expect(
          strings.forFailure(failure),
          isNotEmpty,
          reason: '${failure.runtimeType} has no user-facing copy',
        );
      }
    });
  });
}
