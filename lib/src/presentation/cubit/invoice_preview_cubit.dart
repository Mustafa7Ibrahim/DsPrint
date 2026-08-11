import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/ports/invoice_render_port.dart';
import '../../domain/usecases/auto_print_usecase.dart';
import '../../domain/usecases/capture_invoice_usecase.dart';
import 'invoice_preview_state.dart';

class InvoicePreviewCubit extends Cubit<InvoicePreviewState> {
  final CaptureInvoiceUseCase _captureInvoice;
  final AutoPrintUseCase _autoPrint;

  InvoicePreviewCubit(this._captureInvoice, this._autoPrint)
      : super(const InvoicePreviewLoading());

  void onPageStarted() => emit(const InvoicePreviewLoading());

  void onPageFinished() => emit(const InvoicePreviewReady());

  /// Replaces the legacy `if (_isLoading.value || _isCapturing.value) return;`
  /// guard, which this mirrors via [InvoicePreviewState.isBusy]: a capture is
  /// rejected only while one is already running or the page is still loading.
  ///
  /// Printing the same invoice a second time is a normal thing to do — the
  /// user comes back from the printer picker and taps Print again — so the
  /// terminal states must stay re-entrant.
  ///
  /// [renderer] lets the screen capture the webview it already has on display
  /// instead of the injected headless one. It is passed rather than held as a
  /// field because it belongs to a widget that can be disposed while this cubit
  /// lives on — the cubit orchestrates, it doesn't own the surface.
  Future<void> capture(
    String url, {
    InvoiceRenderPort? renderer,
    int copies = 1,
  }) async {
    if (state.isBusy) return;
    emit(const InvoicePreviewCapturing());
    final captureResult = await _captureInvoice(url, renderer: renderer);
    await captureResult.fold(
      (failure) async => emit(InvoicePreviewFailure(failure)),
      (payload) async {
        emit(InvoicePreviewCaptured(payload));
        final printResult = await _autoPrint(payload, copies: copies);
        printResult.fold(
          (failure) => emit(InvoicePreviewFailure(failure)),
          (_) => emit(const InvoicePreviewReady()),
        );
      },
    );
  }
}
