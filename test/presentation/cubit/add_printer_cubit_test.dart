import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:ds_print/src/core/error/ds_print_failure.dart';
import 'package:ds_print/src/domain/entities/printer_device.dart';
import 'package:ds_print/src/domain/entities/printer_interface_type.dart';
import 'package:ds_print/src/domain/usecases/add_printer_usecase.dart';
import 'package:ds_print/src/domain/usecases/discover_printers_usecase.dart';
import 'package:ds_print/src/presentation/cubit/add_printer_cubit.dart';
import 'package:ds_print/src/presentation/cubit/add_printer_state.dart';

class MockDiscoverPrintersUseCase extends Mock
    implements DiscoverPrintersUseCase {}

class MockAddPrinterUseCase extends Mock implements AddPrinterUseCase {}

void main() {
  late MockDiscoverPrintersUseCase discover;
  late MockAddPrinterUseCase addPrinter;

  const lan = PrinterDevice(
      id: '192.168.1.50', interfaceType: PrinterInterfaceType.lan);
  const bluetooth = PrinterDevice(
      id: '00:11:62:AA:BB:CC', interfaceType: PrinterInterfaceType.bluetooth);
  const usb =
      PrinterDevice(id: 'usb-1', interfaceType: PrinterInterfaceType.usb);

  setUpAll(() => registerFallbackValue(lan));

  setUp(() {
    discover = MockDiscoverPrintersUseCase();
    addPrinter = MockAddPrinterUseCase();
  });

  AddPrinterCubit build() =>
      AddPrinterCubit(discoverPrinters: discover, addPrinter: addPrinter);

  void stubDiscover(PrinterInterfaceType type,
      Either<DsPrintFailure, List<PrinterDevice>> result) {
    when(() => discover(interfaceType: type)).thenAnswer((_) async => result);
  }

  test('starts on the type step with nothing chosen', () {
    expect(build().state, const AddPrinterChoosingType());
  });

  blocTest<AddPrinterCubit, AddPrinterState>(
    'chooseType marks the type; search does nothing until one is chosen',
    build: build,
    act: (cubit) async {
      await cubit.search();
      cubit.chooseType(PrinterInterfaceType.bluetooth);
    },
    expect: () =>
        const [AddPrinterChoosingType(PrinterInterfaceType.bluetooth)],
    verify: (_) =>
        verifyNever(() => discover(interfaceType: any(named: 'interfaceType'))),
  );

  for (final (type, device) in [
    (PrinterInterfaceType.lan, lan),
    (PrinterInterfaceType.bluetooth, bluetooth),
    (PrinterInterfaceType.usb, usb),
  ]) {
    blocTest<AddPrinterCubit, AddPrinterState>(
      '${type.name}: Next scans only ${type.name} and lists what it finds',
      setUp: () => stubDiscover(type, Right([device])),
      build: build,
      act: (cubit) {
        cubit.chooseType(type);
        return cubit.search();
      },
      expect: () => [
        AddPrinterChoosingType(type),
        AddPrinterSearching(type),
        AddPrinterResults(type, [device]),
      ],
      verify: (_) => verify(() => discover(interfaceType: type)).called(1),
    );
  }

  blocTest<AddPrinterCubit, AddPrinterState>(
    'an empty scan is Results([]), not a failure',
    setUp: () => stubDiscover(PrinterInterfaceType.lan, const Right([])),
    build: build,
    act: (cubit) {
      cubit.chooseType(PrinterInterfaceType.lan);
      return cubit.search();
    },
    skip: 2,
    expect: () => const [AddPrinterResults(PrinterInterfaceType.lan, [])],
  );

  blocTest<AddPrinterCubit, AddPrinterState>(
    'a denied Bluetooth permission is a Failure the sheet can show',
    setUp: () => stubDiscover(
        PrinterInterfaceType.bluetooth, const Left(PermissionDeniedFailure())),
    build: build,
    act: (cubit) {
      cubit.chooseType(PrinterInterfaceType.bluetooth);
      return cubit.search();
    },
    skip: 2,
    expect: () => const [
      AddPrinterFailure(
          PrinterInterfaceType.bluetooth, PermissionDeniedFailure()),
    ],
  );

  blocTest<AddPrinterCubit, AddPrinterState>(
    'Bluetooth off -> InterfaceUnavailableFailure(bluetooth)',
    setUp: () => stubDiscover(
        PrinterInterfaceType.bluetooth,
        const Left(
            InterfaceUnavailableFailure(PrinterInterfaceType.bluetooth))),
    build: build,
    act: (cubit) {
      cubit.chooseType(PrinterInterfaceType.bluetooth);
      return cubit.search();
    },
    skip: 2,
    expect: () => const [
      AddPrinterFailure(PrinterInterfaceType.bluetooth,
          InterfaceUnavailableFailure(PrinterInterfaceType.bluetooth)),
    ],
  );

  blocTest<AddPrinterCubit, AddPrinterState>(
    'Retry after a failed scan scans the same type again',
    setUp: () {
      var calls = 0;
      when(() => discover(interfaceType: PrinterInterfaceType.lan)).thenAnswer(
          (_) async => calls++ == 0
              ? const Left(DiscoveryFailure('timeout'))
              : const Right([lan]));
    },
    build: build,
    act: (cubit) async {
      cubit.chooseType(PrinterInterfaceType.lan);
      await cubit.search();
      await cubit.search();
    },
    skip: 1,
    expect: () => const [
      AddPrinterSearching(PrinterInterfaceType.lan),
      AddPrinterFailure(PrinterInterfaceType.lan, DiscoveryFailure('timeout')),
      AddPrinterSearching(PrinterInterfaceType.lan),
      AddPrinterResults(PrinterInterfaceType.lan, [lan]),
    ],
  );

  blocTest<AddPrinterCubit, AddPrinterState>(
    'Back returns to the type step keeping the chosen type',
    setUp: () => stubDiscover(PrinterInterfaceType.lan, const Right([])),
    build: build,
    act: (cubit) async {
      cubit.chooseType(PrinterInterfaceType.lan);
      await cubit.search();
      cubit.back();
    },
    skip: 3,
    expect: () => const [AddPrinterChoosingType(PrinterInterfaceType.lan)],
  );

  blocTest<AddPrinterCubit, AddPrinterState>(
    'tapping a found printer saves it and ends with Added(device)',
    setUp: () => when(() => addPrinter(any()))
        .thenAnswer((_) async => const Right(unit)),
    build: build,
    act: (cubit) => cubit.addDevice(bluetooth),
    expect: () => const [
      AddPrinterSaving(PrinterInterfaceType.bluetooth),
      AddPrinterAdded(bluetooth),
    ],
    verify: (_) => verify(() => addPrinter(bluetooth)).called(1),
  );

  blocTest<AddPrinterCubit, AddPrinterState>(
    'a failed save is a Failure, not Added',
    setUp: () => when(() => addPrinter(any()))
        .thenAnswer((_) async => const Left(StorageFailure('io'))),
    build: build,
    act: (cubit) => cubit.addDevice(lan),
    expect: () => const [
      AddPrinterSaving(PrinterInterfaceType.lan),
      AddPrinterFailure(PrinterInterfaceType.lan, StorageFailure('io')),
    ],
  );

  group('addManualLan', () {
    blocTest<AddPrinterCubit, AddPrinterState>(
      'a valid IP is saved as a LAN printer with the IP as its id',
      setUp: () => when(() => addPrinter(any()))
          .thenAnswer((_) async => const Right(unit)),
      build: build,
      act: (cubit) async =>
          expect(await cubit.addManualLan(' 192.168.1.50 '), isTrue),
      expect: () => const [
        AddPrinterSaving(PrinterInterfaceType.lan),
        AddPrinterAdded(lan),
      ],
      verify: (_) => verify(() => addPrinter(lan)).called(1),
    );

    for (final bad in ['', 'abc', '256.1.1.1', '192.168.1']) {
      blocTest<AddPrinterCubit, AddPrinterState>(
        '"$bad" is rejected and nothing is saved',
        build: build,
        act: (cubit) async => expect(await cubit.addManualLan(bad), isFalse),
        expect: () => const <AddPrinterState>[],
        verify: (_) => verifyNever(() => addPrinter(any())),
      );
    }
  });
}
