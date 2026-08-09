import '../../core/value/paper_width.dart';
import '../../domain/entities/print_payload.dart';
import '../../domain/entities/printer_interface_type.dart';
import '../services/chunk_status_resolver.dart';

/// Wire-format discriminator deliberately kept out of the domain layer
/// (`PrintPayload` is free of native strings) — this is the data-layer half
/// of that mapping.
enum PrintPayloadWireType { html, base64 }

/// Exhaustive switch (no `default`) so adding a new [PrintPayload] subtype
/// is a compile error here instead of a silent fallback to the wrong type.
PrintPayloadWireType wireTypeFor(PrintPayload payload) => switch (payload) {
      HtmlPayload() => PrintPayloadWireType.html,
      ImageBase64Payload() => PrintPayloadWireType.base64,
    };

class PrintChannelRequestModel {
  final String key;
  final int index;
  final String data;
  final ChunkStatus status;
  final String printerId;
  final PrinterInterfaceType printerType;
  final PaperWidth width;
  final PrintPayloadWireType typeData;

  const PrintChannelRequestModel({
    this.key = 'key_bid_data',
    required this.index,
    required this.data,
    required this.status,
    required this.printerId,
    required this.printerType,
    required this.width,
    required this.typeData,
  });

  /// Hard contract with the Kotlin side, which hard-casts these
  /// (`data["index"] as Int`, `arguments["width_dots"] as Int`, ...) — a
  /// wrong key name or runtime type here is a native crash, not a build
  /// error.
  Map<String, dynamic> toJson() => {
        'key': key,
        'index': index,
        'data': data,
        'status': status.wireName,
        'printer_id': printerId,
        'printerType': printerType.nativeName,
        'width_dots': width.dots,
        'type_data': typeData.name,
      };
}
