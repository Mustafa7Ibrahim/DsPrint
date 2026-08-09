import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:ds_print/src/core/error/ds_print_failure.dart';
import 'package:ds_print/src/domain/entities/printer_device.dart';
import 'package:ds_print/src/domain/entities/printer_interface_type.dart';
import 'package:ds_print/src/domain/usecases/discover_printers_usecase.dart';
import 'package:ds_print/src/domain/usecases/get_selected_printer_usecase.dart';
import 'package:ds_print/src/domain/usecases/select_printer_usecase.dart';
import 'package:ds_print/src/presentation/cubit/printer_discovery_cubit.dart';
import 'package:ds_print/src/presentation/cubit/printer_discovery_state.dart';

class MockDiscoverPrintersUseCase extends Mock
    implements DiscoverPrintersUseCase {}

class MockGetSelectedPrinterUseCase extends Mock
    implements GetSelectedPrinterUseCase {}

class MockSelectPrinterUseCase extends Mock implements SelectPrinterUseCase {}

void main() {
  late MockDiscoverPrintersUseCase mockDiscoverPrinters;
  late MockGetSelectedPrinterUseCase mockGetSelectedPrinter;
  late MockSelectPrinterUseCase mockSelectPrinter;

  const device1 =
      PrinterDevice(id: 'device-1', interfaceType: PrinterInterfaceType.usb);
  const device2 =
      PrinterDevice(id: 'device-2', interfaceType: PrinterInterfaceType.lan);

  setUpAll(() {
    registerFallbackValue(device1);
  });

  setUp(() {
    mockDiscoverPrinters = MockDiscoverPrintersUseCase();
    mockGetSelectedPrinter = MockGetSelectedPrinterUseCase();
    mockSelectPrinter = MockSelectPrinterUseCase();
  });

  PrinterDiscoveryCubit buildCubit() => PrinterDiscoveryCubit(
        discoverPrinters: mockDiscoverPrinters,
        getSelectedPrinter: mockGetSelectedPrinter,
        selectPrinter: mockSelectPrinter,
      );

  blocTest<PrinterDiscoveryCubit, PrinterDiscoveryState>(
    'discover emits [Loading, Success] with the device list on the state',
    setUp: () {
      when(() => mockDiscoverPrinters())
          .thenAnswer((_) async => const Right([device1, device2]));
      when(() => mockGetSelectedPrinter())
          .thenAnswer((_) async => const Right(null));
    },
    build: buildCubit,
    act: (cubit) => cubit.discover(),
    expect: () => const [
      PrinterDiscoveryLoading(),
      PrinterDiscoverySuccess([device1, device2], null),
    ],
  );

  blocTest<PrinterDiscoveryCubit, PrinterDiscoveryState>(
    'discover: an empty result is Success(const []), not a failure',
    setUp: () {
      when(() => mockDiscoverPrinters())
          .thenAnswer((_) async => const Right(<PrinterDevice>[]));
      when(() => mockGetSelectedPrinter())
          .thenAnswer((_) async => const Right(null));
    },
    build: buildCubit,
    act: (cubit) => cubit.discover(),
    expect: () => const [
      PrinterDiscoveryLoading(),
      PrinterDiscoverySuccess(<PrinterDevice>[], null),
    ],
  );

  blocTest<PrinterDiscoveryCubit, PrinterDiscoveryState>(
    'discover emits Failure when the repository fails',
    setUp: () {
      when(() => mockDiscoverPrinters())
          .thenAnswer((_) async => const Left(UnsupportedPlatformFailure()));
    },
    build: buildCubit,
    act: (cubit) => cubit.discover(),
    expect: () => const [
      PrinterDiscoveryLoading(),
      PrinterDiscoveryFailure(UnsupportedPlatformFailure()),
    ],
    verify: (_) {
      verifyNever(() => mockGetSelectedPrinter());
    },
  );

  blocTest<PrinterDiscoveryCubit, PrinterDiscoveryState>(
    'select re-emits Success preserving the device list with the new selection',
    setUp: () {
      when(() => mockSelectPrinter(device2))
          .thenAnswer((_) async => const Right(unit));
    },
    build: buildCubit,
    seed: () => const PrinterDiscoverySuccess([device1, device2], null),
    act: (cubit) => cubit.select(device2),
    expect: () => const [
      PrinterDiscoverySuccess([device1, device2], device2),
    ],
  );

  blocTest<PrinterDiscoveryCubit, PrinterDiscoveryState>(
    'select emits Failure when saving fails, without touching the device list',
    setUp: () {
      when(() => mockSelectPrinter(device2))
          .thenAnswer((_) async => const Left(StorageFailure('disk full')));
    },
    build: buildCubit,
    seed: () => const PrinterDiscoverySuccess([device1, device2], null),
    act: (cubit) => cubit.select(device2),
    expect: () => const [
      PrinterDiscoveryFailure(StorageFailure('disk full')),
    ],
  );
}
