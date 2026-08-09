import 'package:flutter_bloc/flutter_bloc.dart';

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
  Future<void> capture(String url) async {
    if (state is! InvoicePreviewReady) return;
    emit(const InvoicePreviewCapturing());
    final result = await _captureInvoice(url);
    result.fold(
      (failure) => emit(InvoicePreviewFailure(failure)),
      (payload) => emit(InvoicePreviewCaptured(payload)),
    );
  }
}
