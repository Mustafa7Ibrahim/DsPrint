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
