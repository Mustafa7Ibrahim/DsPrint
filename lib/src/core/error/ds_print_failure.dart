import 'package:equatable/equatable.dart';

/// All failures produced by the ds_print domain layer.
///
/// `debugMessage` is developer-facing (English, for logs) — user-facing copy
/// and localization are the presentation layer's responsibility.
sealed class DsPrintFailure extends Equatable {
  const DsPrintFailure();

  String get debugMessage;
}

class EmptyPayloadFailure extends DsPrintFailure {
  const EmptyPayloadFailure();

  @override
  String get debugMessage => 'ds_print: nothing to print, payload is empty';

  @override
  List<Object?> get props => [];
}

class NoDeviceFoundFailure extends DsPrintFailure {
  const NoDeviceFoundFailure();

  @override
  String get debugMessage => 'ds_print: discovery returned no devices';

  @override
  List<Object?> get props => [];
}

class NoPrinterSelectedFailure extends DsPrintFailure {
  const NoPrinterSelectedFailure();

  @override
  String get debugMessage =>
      'ds_print: no printer selected (missing device id/interface)';

  @override
  List<Object?> get props => [];
}

class UnsupportedPlatformFailure extends DsPrintFailure {
  const UnsupportedPlatformFailure();

  @override
  String get debugMessage =>
      'ds_print: printing/discovery attempted off Android';

  @override
  List<Object?> get props => [];
}

class CaptureFailure extends DsPrintFailure {
  final String? details;

  const CaptureFailure(this.details);

  @override
  String get debugMessage => 'ds_print: invoice render/capture failed'
      '${details == null ? '' : ' - $details'}';

  @override
  List<Object?> get props => [details];
}

class NativePrintFailure extends DsPrintFailure {
  final String? details;

  const NativePrintFailure(this.details);

  @override
  String get debugMessage => 'ds_print: native side reported failure'
      '${details == null ? '' : ' - $details'}';

  @override
  List<Object?> get props => [details];
}

class StorageFailure extends DsPrintFailure {
  final String? details;

  const StorageFailure(this.details);

  @override
  String get debugMessage =>
      'ds_print: reading/writing the paired device failed'
      '${details == null ? '' : ' - $details'}';

  @override
  List<Object?> get props => [details];
}

class NotConfiguredFailure extends DsPrintFailure {
  final String reason;

  const NotConfiguredFailure(this.reason);

  @override
  String get debugMessage =>
      'ds_print: API used before it could resolve a context/navigator - $reason';

  @override
  List<Object?> get props => [reason];
}
