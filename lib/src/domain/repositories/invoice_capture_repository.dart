import 'package:dartz/dartz.dart';

import '../../core/error/ds_print_failure.dart';
import '../entities/print_payload.dart';

abstract class InvoiceCaptureRepository {
  Future<Either<DsPrintFailure, ImageBase64Payload>> captureUrl(String url);
}
