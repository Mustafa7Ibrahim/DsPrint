import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../core/error/ds_print_exception.dart';
import '../../domain/entities/printer_interface_type.dart';
import '../models/printer_device_model.dart';

abstract class PrinterDiscoveryDataSource {
  /// Emits every device the native scan finds, then closes on `"finished"`.
  ///
  /// [interfaceType] restricts the scan to one connection type; `null` keeps
  /// the legacy USB + LAN scan. Failures arrive as stream errors:
  /// [UnsupportedPlatformException] off Android, [PermissionDeniedException]
  /// when the user refuses the "Nearby devices" prompt,
  /// [InterfaceUnavailableException] when the radio is off, and
  /// [DiscoveryException] for anything else the Star SDK reports.
  Stream<PrinterDeviceModel> watch({PrinterInterfaceType? interfaceType});

  /// Collects [watch] until it closes, with a safety [timeout] in case the
  /// native side never emits `"finished"`. The timeout is suspended while
  /// Android's permission dialog is up — a user reading it must not have the
  /// scan time out underneath them.
  ///
  /// De-duplicates by device, and drops invalid ids and devices whose type
  /// differs from [interfaceType] — so a Bluetooth search can never offer a
  /// USB printer, whatever the native side sends.
  Future<List<PrinterDeviceModel>> discoverOnce({
    PrinterInterfaceType? interfaceType,
    Duration timeout,
  });
}

class PrinterDiscoveryDataSourceImpl implements PrinterDiscoveryDataSource {
  final EventChannel _eventChannel;

  const PrinterDiscoveryDataSourceImpl({required EventChannel eventChannel})
      : _eventChannel = eventChannel;

  // Native → Dart protocol on the discovery channel. Must match the strings
  // `DsPrintPlugin.kt` sends; a mismatch is a silent no-op, not an error.
  static const finishedEvent = 'finished';
  static const notAndroidEvent = 'failed-not-android-platform';
  static const permissionDeniedEvent = 'failed-permission-denied';
  static const permissionRequestedEvent = 'permission-requested';
  static const permissionGrantedEvent = 'permission-granted';

  // `StarIO10ErrorCode` names the native side forwards as the error code.
  static const _unavailableInterfaces = {
    'BluetoothUnavailable': PrinterInterfaceType.bluetooth,
    'NetworkUnavailable': PrinterInterfaceType.lan,
    'UsbUnavailable': PrinterInterfaceType.usb,
  };

  @override
  Stream<PrinterDeviceModel> watch({PrinterInterfaceType? interfaceType}) {
    return _events(interfaceType)
        .where((event) => event is _DeviceFound)
        .map((event) => (event as _DeviceFound).device);
  }

  @override
  Future<List<PrinterDeviceModel>> discoverOnce({
    PrinterInterfaceType? interfaceType,
    Duration timeout = const Duration(seconds: 10),
  }) {
    final devices = <PrinterDeviceModel>{};
    final completer = Completer<List<PrinterDeviceModel>>();
    Timer? timer;
    late final StreamSubscription<_DiscoveryEvent> subscription;

    void finish([Object? error]) {
      if (completer.isCompleted) return;
      timer?.cancel();
      subscription.cancel();
      if (error != null) {
        completer.completeError(error);
      } else {
        completer.complete(devices.toList());
      }
    }

    // Safety cap only — native discovery may never emit "finished" on some
    // devices/interfaces.
    void armTimeout() {
      timer?.cancel();
      timer = Timer(timeout, finish);
    }

    subscription = _events(interfaceType).listen(
      (event) {
        switch (event) {
          case _DeviceFound(:final device):
            final wrongType =
                interfaceType != null && device.interfaceType != interfaceType;
            if (device.isValid && !wrongType) devices.add(device);
          case _AwaitingPermission():
            timer?.cancel();
          case _PermissionGranted():
            armTimeout();
        }
      },
      onError: (Object error) => finish(error),
      onDone: finish,
    );
    armTimeout();
    return completer.future;
  }

  /// The native event protocol, parsed. Closes on `"finished"`; a failure
  /// event or platform error closes it with the matching [DsPrintException].
  /// Cancelling it cancels the native scan.
  Stream<_DiscoveryEvent> _events(PrinterInterfaceType? interfaceType) {
    // Discovery is Android-only, mirroring
    // `DiscoverPrinterUSBDartMethodChannelController.setup`.
    if (defaultTargetPlatform != TargetPlatform.android) {
      return Stream.error(const UnsupportedPlatformException());
    }

    final controller = StreamController<_DiscoveryEvent>();
    late final StreamSubscription<dynamic> nativeSubscription;

    void close([DsPrintException? error]) {
      if (controller.isClosed) return;
      if (error != null) controller.addError(error);
      controller.close();
      nativeSubscription.cancel();
    }

    nativeSubscription =
        _eventChannel.receiveBroadcastStream(interfaceType?.nativeName).listen(
      (event) {
        switch (event) {
          case finishedEvent:
            close();
          case notAndroidEvent:
            close(const UnsupportedPlatformException());
          case permissionDeniedEvent:
            close(const PermissionDeniedException());
          case permissionRequestedEvent:
            controller.add(const _AwaitingPermission());
          case permissionGrantedEvent:
            controller.add(const _PermissionGranted());
          case Map():
            controller.add(_DeviceFound(PrinterDeviceModel.fromChannel(event)));
        }
      },
      onError: (Object error) => close(error is PlatformException
          ? _mapError(error)
          : DiscoveryException('$error')),
      onDone: controller.close,
    );
    // Deliberately not `= nativeSubscription.cancel`. A stream only delivers
    // its done event once the cancel future it was handed completes, and
    // this one resolves only when native acknowledges the cancel. Returning
    // it would hold "finished" — and every caller — hostage to that round
    // trip. Cancel natively, but don't wait on it.
    controller.onCancel = () {
      nativeSubscription.cancel();
    };
    return controller.stream;
  }

  DsPrintException _mapError(PlatformException error) {
    final unavailable = _unavailableInterfaces[error.code];
    if (unavailable != null) return InterfaceUnavailableException(unavailable);
    return DiscoveryException(error.message ?? error.code);
  }
}

sealed class _DiscoveryEvent {
  const _DiscoveryEvent();
}

final class _DeviceFound extends _DiscoveryEvent {
  final PrinterDeviceModel device;

  const _DeviceFound(this.device);
}

/// Android's runtime-permission dialog is on screen.
final class _AwaitingPermission extends _DiscoveryEvent {
  const _AwaitingPermission();
}

/// The user allowed it; the native scan is starting now.
final class _PermissionGranted extends _DiscoveryEvent {
  const _PermissionGranted();
}
