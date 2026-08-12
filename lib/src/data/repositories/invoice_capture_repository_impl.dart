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
      final slices =
          await (renderer ?? _renderer).renderUrlToPngSlices(url);
      if (slices.isEmpty) {
        return const Left(CaptureFailure('capture produced no slices'));
      }
      return Right(ImageBase64Payload(slices));
    } on CaptureException catch (e) {
      return Left(CaptureFailure(e.details));
    } on DsPrintException catch (e) {
      return Left(CaptureFailure(e.message));
    } catch (e) {
      return Left(CaptureFailure(e.toString()));
    }
  }
}
