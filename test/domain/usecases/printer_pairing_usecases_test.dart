import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:ds_print/src/core/error/ds_print_failure.dart';
import 'package:ds_print/src/domain/entities/printer_device.dart';
import 'package:ds_print/src/domain/entities/printer_interface_type.dart';
import 'package:ds_print/src/domain/repositories/saved_printers_repository.dart';
import 'package:ds_print/src/domain/usecases/add_printer_usecase.dart';
import 'package:ds_print/src/domain/usecases/clear_selected_printer_usecase.dart';
import 'package:ds_print/src/domain/usecases/get_selected_printer_usecase.dart';
import 'package:ds_print/src/domain/usecases/remove_printer_usecase.dart';
import 'package:ds_print/src/domain/usecases/resolve_print_device_usecase.dart';
import 'package:ds_print/src/domain/usecases/select_printer_usecase.dart';

class MockSavedPrintersRepository extends Mock
    implements SavedPrintersRepository {}

class MockSelectPrinterUseCase extends Mock implements SelectPrinterUseCase {}

class MockGetSelectedPrinterUseCase extends Mock
    implements GetSelectedPrinterUseCase {}

class MockClearSelectedPrinterUseCase extends Mock
    implements ClearSelectedPrinterUseCase {}

void main() {
  late MockSavedPrintersRepository savedPrinters;
  late MockSelectPrinterUseCase selectPrinter;
  late MockGetSelectedPrinterUseCase getSelectedPrinter;
  late MockClearSelectedPrinterUseCase clearSelectedPrinter;

  const lan = PrinterDevice(
      id: '192.168.1.50', interfaceType: PrinterInterfaceType.lan);
  const bluetooth = PrinterDevice(
      id: '00:11:62:AA:BB:CC', interfaceType: PrinterInterfaceType.bluetooth);

  setUpAll(() => registerFallbackValue(lan));

  setUp(() {
    savedPrinters = MockSavedPrintersRepository();
    selectPrinter = MockSelectPrinterUseCase();
    getSelectedPrinter = MockGetSelectedPrinterUseCase();
    clearSelectedPrinter = MockClearSelectedPrinterUseCase();
  });

  group('AddPrinterUseCase', () {
    late AddPrinterUseCase addPrinter;

    setUp(() => addPrinter = AddPrinterUseCase(
        savedPrinters: savedPrinters, selectPrinter: selectPrinter));

    test('saves the printer, then makes it the active one', () async {
      when(() => savedPrinters.add(any()))
          .thenAnswer((_) async => const Right(unit));
      when(() => selectPrinter(any()))
          .thenAnswer((_) async => const Right(unit));

      final result = await addPrinter(bluetooth);

      expect(result, const Right<DsPrintFailure, Unit>(unit));
      verifyInOrder([
        () => savedPrinters.add(bluetooth),
        () => selectPrinter(bluetooth),
      ]);
    });

    test('a failed save does not change the active printer', () async {
      when(() => savedPrinters.add(any()))
          .thenAnswer((_) async => const Left(StorageFailure('full')));

      final result = await addPrinter(lan);

      expect(result, const Left<DsPrintFailure, Unit>(StorageFailure('full')));
      verifyNever(() => selectPrinter(any()));
    });

    test('an empty id is rejected before touching storage', () async {
      final result = await addPrinter(const PrinterDevice(
          id: ' ', interfaceType: PrinterInterfaceType.lan));

      expect(
          result, const Left<DsPrintFailure, Unit>(NoPrinterSelectedFailure()));
      verifyNever(() => savedPrinters.add(any()));
    });
  });

  group('RemovePrinterUseCase', () {
    late RemovePrinterUseCase removePrinter;

    setUp(() {
      removePrinter = RemovePrinterUseCase(
        savedPrinters: savedPrinters,
        getSelectedPrinter: getSelectedPrinter,
        clearSelectedPrinter: clearSelectedPrinter,
      );
      when(() => savedPrinters.remove(any()))
          .thenAnswer((_) async => const Right(unit));
      when(() => clearSelectedPrinter())
          .thenAnswer((_) async => const Right(unit));
    });

    test('removing the active printer clears the selection', () async {
      when(() => getSelectedPrinter())
          .thenAnswer((_) async => const Right(lan));

      await removePrinter(lan);

      verify(() => savedPrinters.remove(lan)).called(1);
      verify(() => clearSelectedPrinter()).called(1);
    });

    test('removing another printer keeps the selection', () async {
      when(() => getSelectedPrinter())
          .thenAnswer((_) async => const Right(lan));

      final result = await removePrinter(bluetooth);

      expect(result, const Right<DsPrintFailure, Unit>(unit));
      verifyNever(() => clearSelectedPrinter());
    });

    test('a failed removal leaves the selection alone', () async {
      when(() => savedPrinters.remove(any()))
          .thenAnswer((_) async => const Left(StorageFailure('io')));

      final result = await removePrinter(lan);

      expect(result, const Left<DsPrintFailure, Unit>(StorageFailure('io')));
      verifyNever(() => getSelectedPrinter());
      verifyNever(() => clearSelectedPrinter());
    });
  });

  group('ResolvePrintDeviceUseCase', () {
    late ResolvePrintDeviceUseCase resolve;

    setUp(() => resolve =
        ResolvePrintDeviceUseCase(getSelectedPrinter: getSelectedPrinter));

    test('returns the selected printer', () async {
      when(() => getSelectedPrinter())
          .thenAnswer((_) async => const Right(bluetooth));

      expect(await resolve(),
          const Right<DsPrintFailure, PrinterDevice>(bluetooth));
    });

    test('nothing selected -> NoPrinterSelectedFailure', () async {
      when(() => getSelectedPrinter())
          .thenAnswer((_) async => const Right(null));

      expect(
          await resolve(),
          const Left<DsPrintFailure, PrinterDevice>(
              NoPrinterSelectedFailure()));
    });
  });
}
