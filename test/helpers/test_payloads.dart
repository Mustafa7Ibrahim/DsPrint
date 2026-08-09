/// Shared helper for tests that need a large (multi-megabyte) payload
/// string without paying for a slow `List.generate(...).join()` build.
///
/// Cycles through the digits 0-9 by code unit so that a misordered
/// reconstruction (e.g. chunks joined out of order) is detectable, unlike a
/// payload made of a single repeated character.
String bigPayload(int length) {
  final buffer = StringBuffer();
  for (var i = 0; i < length; i++) {
    buffer.writeCharCode(0x30 + (i % 10));
  }
  return buffer.toString();
}

/// ~2.5 MB, matching the size the ds_print test plan calls out explicitly
/// (large enough to require thousands of 1000-char chunks).
String get twoPointFiveMbPayload => bigPayload(2500000);
