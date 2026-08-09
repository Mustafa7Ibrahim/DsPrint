/// Splits a payload into fixed-size chunks for the native print channel.
///
/// 1000 is the legacy chunk size (`_splitByLength` in the old
/// `printer_html_dart_channel_controller.dart`) — keep it exactly.
class PayloadChunker {
  final int chunkSize;

  const PayloadChunker({this.chunkSize = 1000});

  /// Lossless: `split(s).join() == s` for every `s`. Empty input returns an
  /// empty list (not `['']`) — callers rely on this to skip sending anything.
  List<String> split(String input) {
    if (input.isEmpty) return const [];
    final chunks = <String>[];
    for (var i = 0; i < input.length; i += chunkSize) {
      final end = (i + chunkSize < input.length) ? i + chunkSize : input.length;
      chunks.add(input.substring(i, end));
    }
    return chunks;
  }
}
