import 'package:dartz/dartz.dart';

import '../../core/error/ds_print_exception.dart';
import '../../core/error/ds_print_failure.dart';
import '../../domain/entities/print_payload.dart';
import '../../domain/ports/invoice_render_port.dart';
import '../../domain/repositories/invoice_capture_repository.dart';

class InvoiceCaptureRepositoryImpl implements InvoiceCaptureRepository {
  final InvoiceRenderPort _renderer;

  const InvoiceCaptureRepositoryImpl(this._renderer);

  @override
  Future<Either<DsPrintFailure, ImageBase64Payload>> captureUrl(
    String url, {
    InvoiceRenderPort? renderer,
  }) async {
    try {
      final base64 = await (renderer ?? _renderer).renderUrlToBase64Png(url);
      return Right(ImageBase64Payload(base64));
    } on CaptureException catch (e) {
      return Left(CaptureFailure(e.details));
    } on DsPrintException catch (e) {
      return Left(CaptureFailure(e.message));
    } catch (e) {
      return Left(CaptureFailure(e.toString()));
    }
  }
}
