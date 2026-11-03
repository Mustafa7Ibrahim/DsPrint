import '../../domain/entities/printer_interface_type.dart';

/// Exceptions thrown by ds_print datasources only. Repositories catch these
/// and map them to [DsPrintFailure]s for the domain/use case layer.
sealed class DsPrintException implements Exception {
  const DsPrintException();

  String get message;
}

class EmptyPayloadException extends DsPrintException {
  const EmptyPayloadException();

  @override
  String get message => 'ds_print: nothing to print, payload is empty';
}

class NoDeviceFoundException extends DsPrintException {
  const NoDeviceFoundException();

  @override
  String get message => 'ds_print: discovery returned no devices';
}

class UnsupportedPlatformException extends DsPrintException {
  const UnsupportedPlatformException();

  @override
  String get message => 'ds_print: printing/discovery attempted off Android';
}

class CaptureException extends DsPrintException {
  final String? details;

  const CaptureException(this.details);

  @override
  String get message => 'ds_print: invoice render/capture failed'
      '${details == null ? '' : ' - $details'}';
}

class NativePrintException extends DsPrintException {
  final String? details;

  const NativePrintException(this.details);

  @override
  String get message => 'ds_print: native side reported failure'
      '${details == null ? '' : ' - $details'}';
}

class StorageException extends DsPrintException {
  final String? details;

  const StorageException(this.details);

  @override
  String get message => 'ds_print: reading/writing the paired device failed'
      '${details == null ? '' : ' - $details'}';
}

/// The user denied a runtime permission discovery needs (Bluetooth's
/// `BLUETOOTH_CONNECT`, or Android 17's `ACCESS_LOCAL_NETWORK`). Both sit in
/// Android's "Nearby devices" group, so one exception covers either.
class PermissionDeniedException extends DsPrintException {
  const PermissionDeniedException();

  @override
  String get message =>
      'ds_print: a runtime permission needed for discovery was denied';
}

/// The host device's radio for [interfaceType] is off or missing — the Star
/// SDK's `BluetoothUnavailable` / `NetworkUnavailable` / `UsbUnavailable`.
class InterfaceUnavailableException extends DsPrintException {
  final PrinterInterfaceType interfaceType;

  const InterfaceUnavailableException(this.interfaceType);

  @override
  String get message =>
      'ds_print: ${interfaceType.nativeName} is unavailable on this device';
}

class DiscoveryException extends DsPrintException {
  final String? details;

  const DiscoveryException(this.details);

  @override
  String get message => 'ds_print: printer discovery failed'
      '${details == null ? '' : ' - $details'}';
}
