import 'package:dartz/dartz.dart';

import '../../core/error/ds_print_failure.dart';
import '../entities/print_payload.dart';
import '../repositories/invoice_capture_repository.dart';

class CaptureInvoiceUseCase {
  final InvoiceCaptureRepository _repository;

  const CaptureInvoiceUseCase(this._repository);

  Future<Either<DsPrintFailure, ImageBase64Payload>> call(String url) {
    return _repository.captureUrl(url);
  }
}
