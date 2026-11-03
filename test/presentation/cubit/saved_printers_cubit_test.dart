import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:ds_print/src/core/error/ds_print_failure.dart';
import 'package:ds_print/src/domain/entities/printer_device.dart';
import 'package:ds_print/src/domain/entities/printer_interface_type.dart';
import 'package:ds_print/src/domain/usecases/get_saved_printers_usecase.dart';
import 'package:ds_print/src/domain/usecases/get_selected_printer_usecase.dart';
import 'package:ds_print/src/domain/usecases/remove_printer_usecase.dart';
import 'package:ds_print/src/domain/usecases/select_printer_usecase.dart';
import 'package:ds_print/src/presentation/cubit/saved_printers_cubit.dart';
import 'package:ds_print/src/presentation/cubit/saved_printers_state.dart';

class MockGetSavedPrintersUseCase extends Mock
    implements GetSavedPrintersUseCase {}

class MockGetSelectedPrinterUseCase extends Mock
    implements GetSelectedPrinterUseCase {}

class MockSelectPrinterUseCase extends Mock implements SelectPrinterUseCase {}

class MockRemovePrinterUseCase extends Mock implements RemovePrinterUseCase {}

void main() {
  late MockGetSavedPrintersUseCase getSaved;
  late MockGetSelectedPrinterUseCase getSelected;
  late MockSelectPrinterUseCase select;
  late MockRemovePrinterUseCase remove;

  const lan = PrinterDevice(
      id: '192.168.1.50', interfaceType: PrinterInterfaceType.lan);
  const bluetooth = PrinterDevice(
      id: '00:11:62:AA:BB:CC', interfaceType: PrinterInterfaceType.bluetooth);

  setUpAll(() => registerFallbackValue(lan));

  setUp(() {
    getSaved = MockGetSavedPrintersUseCase();
    getSelected = MockGetSelectedPrinterUseCase();
    select = MockSelectPrinterUseCase();
    remove = MockRemovePrinterUseCase();
  });

  SavedPrintersCubit build() => SavedPrintersCubit(
        getSavedPrinters: getSaved,
        getSelectedPrinter: getSelected,
        selectPrinter: select,
        removePrinter: remove,
      );

  blocTest<SavedPrintersCubit, SavedPrintersState>(
    'load lists saved printers with the active one',
    setUp: () {
      when(() => getSaved())
          .thenAnswer((_) async => const Right([lan, bluetooth]));
      when(() => getSelected()).thenAnswer((_) async => const Right(bluetooth));
    },
    build: build,
    act: (cubit) => cubit.load(),
    expect: () => const [
      SavedPrintersLoaded([lan, bluetooth], bluetooth)
    ],
  );

  blocTest<SavedPrintersCubit, SavedPrintersState>(
    'a failed read of the active printer still shows the list',
    setUp: () {
      when(() => getSaved()).thenAnswer((_) async => const Right([lan]));
      when(() => getSelected())
          .thenAnswer((_) async => const Left(StorageFailure('io')));
    },
    build: build,
    act: (cubit) => cubit.load(),
    expect: () => const [
      SavedPrintersLoaded([lan], null)
    ],
  );

  blocTest<SavedPrintersCubit, SavedPrintersState>(
    'select moves the active printer and keeps the list',
    setUp: () =>
        when(() => select(any())).thenAnswer((_) async => const Right(unit)),
    build: build,
    seed: () => const SavedPrintersLoaded([lan, bluetooth], lan),
    act: (cubit) => cubit.select(bluetooth),
    expect: () => const [
      SavedPrintersLoaded([lan, bluetooth], bluetooth)
    ],
    verify: (_) => verify(() => select(bluetooth)).called(1),
  );

  blocTest<SavedPrintersCubit, SavedPrintersState>(
    'removing the active printer drops it and clears the selection at once',
    setUp: () =>
        when(() => remove(any())).thenAnswer((_) async => const Right(unit)),
    build: build,
    seed: () => const SavedPrintersLoaded([lan, bluetooth], lan),
    act: (cubit) => cubit.remove(lan),
    expect: () => const [
      SavedPrintersLoaded([bluetooth], null)
    ],
    verify: (_) => verify(() => remove(lan)).called(1),
  );

  blocTest<SavedPrintersCubit, SavedPrintersState>(
    'removing another printer keeps the selection',
    setUp: () =>
        when(() => remove(any())).thenAnswer((_) async => const Right(unit)),
    build: build,
    seed: () => const SavedPrintersLoaded([lan, bluetooth], lan),
    act: (cubit) => cubit.remove(bluetooth),
    expect: () => const [
      SavedPrintersLoaded([lan], lan)
    ],
  );

  blocTest<SavedPrintersCubit, SavedPrintersState>(
    'onPrinterAdded re-reads storage so the new printer shows as active',
    setUp: () {
      when(() => getSaved())
          .thenAnswer((_) async => const Right([lan, bluetooth]));
      when(() => getSelected()).thenAnswer((_) async => const Right(bluetooth));
    },
    build: build,
    seed: () => const SavedPrintersLoaded([lan], lan),
    act: (cubit) => cubit.onPrinterAdded(bluetooth),
    expect: () => const [
      SavedPrintersLoaded([lan, bluetooth], bluetooth)
    ],
  );
}
