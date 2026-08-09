import 'package:equatable/equatable.dart';

import '../../core/value/paper_width.dart';
import 'print_payload.dart';
import 'printer_device.dart';

class PrintJob extends Equatable {
  final PrintPayload payload;
  final PrinterDevice device;
  final int copies;
  final PaperWidth paperWidth;

  const PrintJob({
    required this.payload,
    required this.device,
    required this.paperWidth,
    this.copies = 1,
  }) : assert(copies >= 1);

  factory PrintJob.forPayload({
    required PrintPayload payload,
    required PrinterDevice device,
    int copies = 1,
    PaperWidth? paperWidth,
  }) {
    return PrintJob(
      payload: payload,
      device: device,
      copies: copies,
      paperWidth: paperWidth ?? payload.defaultWidth,
    );
  }

  @override
  List<Object?> get props => [payload, device, copies, paperWidth];
}
