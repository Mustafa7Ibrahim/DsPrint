import 'package:equatable/equatable.dart';

import '../../core/error/ds_print_failure.dart';
import '../../domain/entities/print_payload.dart';

sealed class InvoicePreviewState extends Equatable {
  const InvoicePreviewState();

  /// The two states that must reject a new capture request — the page is
  /// still arriving, or one capture is already in flight.
  ///
  /// Deliberately expressed as "busy", not "ready": [InvoicePreviewCaptured]
  /// and [InvoicePreviewFailure] are terminal, so a `state is Ready` test
  /// would leave the Print action dead for the rest of the screen's life once
  /// the first print finished. Listed exhaustively rather than with a `_`
  /// wildcard so a new state can't silently default to "not busy".
  bool get isBusy => switch (this) {
        InvoicePreviewLoading() || InvoicePreviewCapturing() => true,
        InvoicePreviewReady() ||
        InvoicePreviewCaptured() ||
        InvoicePreviewFailure() =>
          false,
      };

  @override
  List<Object?> get props => [];
}

/// The webview page itself is still loading (mirrors legacy `_isLoading`).
final class InvoicePreviewLoading extends InvoicePreviewState {
  const InvoicePreviewLoading();
}

/// Page finished loading; idle and eligible for [InvoicePreviewCubit.capture].
final class InvoicePreviewReady extends InvoicePreviewState {
  const InvoicePreviewReady();
}

final class InvoicePreviewCapturing extends InvoicePreviewState {
  const InvoicePreviewCapturing();
}

final class InvoicePreviewCaptured extends InvoicePreviewState {
  final ImageBase64Payload payload;

  const InvoicePreviewCaptured(this.payload);

  @override
  List<Object?> get props => [payload];
}

final class InvoicePreviewFailure extends InvoicePreviewState {
  final DsPrintFailure failure;

  const InvoicePreviewFailure(this.failure);

  @override
  List<Object?> get props => [failure];
}
