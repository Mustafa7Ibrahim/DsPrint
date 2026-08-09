import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../core/error/ds_print_exception.dart';
import '../../domain/entities/printer_interface_type.dart';
import '../models/printer_device_model.dart';

abstract class PrinterDiscoveryDataSource {
  /// Emits every discovered device, then closes on `"finished"`. Emits
  /// [UnsupportedPlatformException] as a stream error off Android or on the
  /// native `"failed-not-android-platform"` event.
  Stream<PrinterDeviceModel> watch(PrinterInterfaceType interfaceType);

  /// Collects [watch] until it closes, with a safety [timeout] in case the
  /// native side never emits `"finished"`. De-duplicates by device id — the
  /// legacy code could list the same printer twice across repeated scans.
  Future<List<PrinterDeviceModel>> discoverOnce(
    PrinterInterfaceType interfaceType, {
    Duration timeout,
  });
}

class PrinterDiscoveryDataSourceImpl implements PrinterDiscoveryDataSource {
  final EventChannel _eventChannel;

  const PrinterDiscoveryDataSourceImpl({required EventChannel eventChannel})
      : _eventChannel = eventChannel;

  @override
  Stream<PrinterDeviceModel> watch(PrinterInterfaceType interfaceType) {
    // Discovery is Android-only, mirroring
    // `DiscoverPrinterUSBDartMethodChannelController.setup`.
    if (defaultTargetPlatform != TargetPlatform.android) {
      return Stream.error(const UnsupportedPlatformException());
    }

    final controller = StreamController<PrinterDeviceModel>();
    late final StreamSubscription<dynamic> subscription;
    subscription =
        _eventChannel.receiveBroadcastStream(interfaceType.nativeName).listen(
      (event) {
        if (event == 'finished') {
          controller.close();
          subscription.cancel();
          return;
        }
        if (event == 'failed-not-android-platform') {
          controller.addError(const UnsupportedPlatformException());
          controller.close();
          subscription.cancel();
          return;
        }
        if (event is Map) {
          controller.add(PrinterDeviceModel.fromChannel(event));
        }
      },
      onError: controller.addError,
      onDone: controller.close,
    );
    controller.onCancel = subscription.cancel;
    return controller.stream;
  }

  @override
  Future<List<PrinterDeviceModel>> discoverOnce(
    PrinterInterfaceType interfaceType, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final devices = <String, PrinterDeviceModel>{};
    try {
      await watch(interfaceType)
          .timeout(timeout)
          .forEach((device) => devices[device.id] = device);
    } on TimeoutException {
      // Safety cap only — native discovery may never emit "finished" on
      // some devices/interfaces.
    }
    return devices.values.toList();
  }
}
