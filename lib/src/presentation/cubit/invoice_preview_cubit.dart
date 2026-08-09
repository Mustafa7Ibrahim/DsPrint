import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/ports/invoice_render_port.dart';
import '../../domain/usecases/capture_invoice_usecase.dart';
import 'invoice_preview_state.dart';

class InvoicePreviewCubit extends Cubit<InvoicePreviewState> {
  final CaptureInvoiceUseCase _captureInvoice;

  InvoicePreviewCubit(this._captureInvoice)
      : super(const InvoicePreviewLoading());

  void onPageStarted() => emit(const InvoicePreviewLoading());

  void onPageFinished() => emit(const InvoicePreviewReady());

  /// Replaces the legacy `if (_isLoading.value || _isCapturing.value) return;`
  /// guard: only a fully-loaded, idle preview can start a capture.
  ///
  /// [renderer] lets the screen capture the webview it already has on display
  /// instead of the injected headless one. It is passed rather than held as a
  /// field because it belongs to a widget that can be disposed while this cubit
  /// lives on — the cubit orchestrates, it doesn't own the surface.
  Future<void> capture(String url, {InvoiceRenderPort? renderer}) async {
    if (state is! InvoicePreviewReady) return;
    emit(const InvoicePreviewCapturing());
    final result = await _captureInvoice(url, renderer: renderer);
    result.fold(
      (failure) => emit(InvoicePreviewFailure(failure)),
      (payload) => emit(InvoicePreviewCaptured(payload)),
    );
  }
}
