import 'dart:async';

import 'package:flutter/services.dart';

import '../../core/error/ds_print_exception.dart';
import '../../domain/entities/print_job.dart';
import '../models/print_channel_request_model.dart';
import '../services/chunk_status_resolver.dart';
import '../services/payload_chunker.dart';

abstract class PrinterNativeDataSource {
  /// Completes on native success, throws a [DsPrintException] on failure.
  Future<void> print(PrintJob job);
}

class PrinterNativeDataSourceImpl implements PrinterNativeDataSource {
  final MethodChannel _methodChannel;
  final EventChannel _eventChannel;
  final PayloadChunker _chunker;
  final ChunkStatusResolver _statusResolver;
  final Duration resultTimeout;

  PrinterNativeDataSourceImpl({
    required MethodChannel methodChannel,
    required EventChannel eventChannel,
    PayloadChunker chunker = const PayloadChunker(),
    ChunkStatusResolver statusResolver = const ChunkStatusResolver(),
    this.resultTimeout = const Duration(seconds: 20),
  })  : _methodChannel = methodChannel,
        _eventChannel = eventChannel,
        _chunker = chunker,
        _statusResolver = statusResolver;

  Stream<dynamic>? _resultStream;

  /// Subscribed once, lazily, and reused across every print. The legacy
  /// `_setupListenerFromNative` called `.listen()` on a fresh subscription
  /// for every print and never cancelled it, so after N prints N handlers
  /// fired for every subsequent result.
  Stream<dynamic> get _stream =>
      _resultStream ??= _eventChannel.receiveBroadcastStream();

  @override
  Future<void> print(PrintJob job) async {
    if (job.payload.isEmpty) {
      throw const EmptyPayloadException();
    }
    final chunks = _chunker.split(job.payload.raw);

    for (var copy = 0; copy < job.copies; copy++) {
      // Sequential, not interleaved — each copy waits for its own native
      // result before the next copy's chunks are sent.
      await _sendOnce(job, chunks);
    }
  }

  Future<void> _sendOnce(PrintJob job, List<String> chunks) async {
    // Start awaiting the result BEFORE sending the first chunk — otherwise a
    // fast native reply can arrive before we subscribe and be missed.
    final resultFuture = _stream
        .firstWhere((event) => event == 'success' || event == 'failed')
        .timeout(resultTimeout, onTimeout: () => 'timeout');

    for (var i = 0; i < chunks.length; i++) {
      final request = PrintChannelRequestModel(
        index: i,
        data: chunks[i],
        status: _statusResolver.resolve(index: i, total: chunks.length),
        printerId: job.device.id,
        printerType: job.device.interfaceType,
        width: job.paperWidth,
        typeData: wireTypeFor(job.payload),
      );
      await _methodChannel.invokeMethod('fromFlutter', request.toJson());
    }

    final result = await resultFuture;
    if (result == 'failed') {
      throw const NativePrintException('failed');
    }
    if (result == 'timeout') {
      throw const NativePrintException('timeout');
    }
  }
}
