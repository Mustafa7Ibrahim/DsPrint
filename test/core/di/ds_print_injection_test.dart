// Regression coverage for a real-device crash:
//   "Bad state: GetIt: Object/factory with type InvoicePreviewCubit is not
//   registered inside GetIt."
//
// Root cause: `dsPrintInjection()` used to only run from inside the
// `DsPrint.*` facade methods. But `InvoicePreviewScreen` and
// `PrinterPickerScreen` are also exported directly from `lib/ds_print.dart`,
// so a host app's router can build them without ever calling a `DsPrint.*`
// method — that path never touched the facade, so `dsPrintSl<X>()` crashed
// on an empty container. `dsPrintResolve<T>()` fixes this structurally by
// always initialising before resolving; these tests pin that behaviour down
// and also cover the bool-flag/container desync that made the bug
// untestable in the first place (see `dsPrintInjection.dart` for the fix).
import 'package:flutter_test/flutter_test.dart';

import 'package:ds_print/src/core/di/ds_print_injection.dart';
import 'package:ds_print/src/domain/usecases/auto_print_usecase.dart';
import 'package:ds_print/src/presentation/cubit/invoice_preview_cubit.dart';
import 'package:ds_print/src/presentation/cubit/print_job_cubit.dart';
import 'package:ds_print/src/presentation/cubit/printer_discovery_cubit.dart';

void main() {
  // Every test starts from, and leaves, an empty container — `dsPrintSl` is
  // a package-global singleton shared with every other test file that
  // imports it.
  tearDown(() => dsPrintSl.reset());

  group('dsPrintResolve', () {
    test(
      'resolves InvoicePreviewCubit on an empty container '
      '(the exact crash reported from the device)',
      () async {
        await dsPrintSl.reset();
        expect(() => dsPrintResolve<InvoicePreviewCubit>(), returnsNormally);
      },
    );

    test('resolves PrinterDiscoveryCubit on an empty container', () async {
      await dsPrintSl.reset();
      expect(() => dsPrintResolve<PrinterDiscoveryCubit>(), returnsNormally);
    });

    test('resolves PrintJobCubit on an empty container', () async {
      await dsPrintSl.reset();
      expect(() => dsPrintResolve<PrintJobCubit>(), returnsNormally);
    });
  });

  group('dsPrintInjection', () {
    test(
      'calling it twice in a row does not throw '
      '(a second registration of an already-registered type would)',
      () async {
        await dsPrintSl.reset();
        dsPrintInjection();
        expect(dsPrintInjection, returnsNormally);
      },
    );
  });

  group('isDsPrintInitialised', () {
    test(
      'reports false after dsPrintSl.reset() — proves the getter reads '
      'container state and cannot desync from it the way a cached bool could',
      () async {
        dsPrintInjection();
        expect(isDsPrintInitialised, isTrue);
        expect(dsPrintSl.isRegistered<AutoPrintUseCase>(), isTrue);

        await dsPrintSl.reset();

        expect(isDsPrintInitialised, isFalse);
      },
    );
  });
}
