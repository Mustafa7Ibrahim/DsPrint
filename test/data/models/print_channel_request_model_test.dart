// The Kotlin side (`PrintChannelRequest.kt`) hard-casts these values
// (`stringKeyed["index"] as Int`, `["width_dots"] as Int`, `["data"] as
// String`, ...) with no compile-time link back to this file. A renamed key
// or a wrong runtime type here is a native crash, not a build error - this
// file is the only thing standing between a Dart-side refactor and that
// crash, so it asserts the wire contract explicitly and exhaustively.
import 'package:ds_print/src/core/value/paper_width.dart';
import 'package:ds_print/src/data/models/print_channel_request_model.dart';
import 'package:ds_print/src/data/services/chunk_status_resolver.dart';
import 'package:ds_print/src/domain/entities/print_payload.dart';
import 'package:ds_print/src/domain/entities/printer_interface_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PrintChannelRequestModel.toJson', () {
    test('key set is exactly the Kotlin-side contract (added keys fail too)',
        () {
      const model = PrintChannelRequestModel(
        index: 0,
        data: 'chunk-data',
        status: ChunkStatus.oneIndex,
        printerId: 'device-1',
        printerType: PrinterInterfaceType.usb,
        width: PaperWidth.html,
        typeData: PrintPayloadWireType.html,
      );

      expect(
        model.toJson().keys.toSet(),
        equals(<String>{
          'key',
          'index',
          'data',
          'status',
          'printer_id',
          'printerType',
          'width_dots',
          'type_data',
        }),
      );
    });

    test('index and width_dots are int; every other value is a String', () {
      const model = PrintChannelRequestModel(
        index: 7,
        data: 'chunk-data',
        status: ChunkStatus.progress,
        printerId: 'device-2',
        printerType: PrinterInterfaceType.lan,
        width: PaperWidth.image,
        typeData: PrintPayloadWireType.base64,
      );
      final json = model.toJson();

      expect(json['index'], isA<int>());
      expect(json['width_dots'], isA<int>());
      for (final key in [
        'key',
        'data',
        'status',
        'printer_id',
        'printerType',
        'type_data',
      ]) {
        expect(json[key], isA<String>(),
            reason: 'json["$key"] must be a String');
      }
    });

    test('key defaults to key_bid_data', () {
      const model = PrintChannelRequestModel(
        index: 0,
        data: 'x',
        status: ChunkStatus.oneIndex,
        printerId: 'device-1',
        printerType: PrinterInterfaceType.usb,
        width: PaperWidth.html,
        typeData: PrintPayloadWireType.html,
      );

      expect(model.key, 'key_bid_data');
      expect(model.toJson()['key'], 'key_bid_data');
    });

    test(
        'printerType serialises to Usb/Lan/Bluetooth for all three enum values',
        () {
      const expected = {
        PrinterInterfaceType.usb: 'Usb',
        PrinterInterfaceType.lan: 'Lan',
        PrinterInterfaceType.bluetooth: 'Bluetooth',
      };

      for (final entry in expected.entries) {
        final model = PrintChannelRequestModel(
          index: 0,
          data: 'x',
          status: ChunkStatus.oneIndex,
          printerId: 'device-1',
          printerType: entry.key,
          width: PaperWidth.html,
          typeData: PrintPayloadWireType.html,
        );
        expect(
          model.toJson()['printerType'],
          entry.value,
          reason: '${entry.key} must serialise to "${entry.value}"',
        );
      }
    });

    test(
        'type_data is html for HtmlPayload and base64 for ImageBase64Payload via wireTypeFor',
        () {
      expect(wireTypeFor(const HtmlPayload('<html></html>')),
          PrintPayloadWireType.html);
      expect(wireTypeFor(const ImageBase64Payload(['base64=='])),
          PrintPayloadWireType.base64);

      final htmlModel = PrintChannelRequestModel(
        index: 0,
        data: 'x',
        status: ChunkStatus.oneIndex,
        printerId: 'device-1',
        printerType: PrinterInterfaceType.usb,
        width: PaperWidth.html,
        typeData: wireTypeFor(const HtmlPayload('<html></html>')),
      );
      expect(htmlModel.toJson()['type_data'], 'html');

      final imageModel = PrintChannelRequestModel(
        index: 0,
        data: 'x',
        status: ChunkStatus.oneIndex,
        printerId: 'device-1',
        printerType: PrinterInterfaceType.usb,
        width: PaperWidth.image,
        typeData: wireTypeFor(const ImageBase64Payload(['base64=='])),
      );
      expect(imageModel.toJson()['type_data'], 'base64');
    });
  });
}
