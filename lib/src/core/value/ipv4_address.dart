/// Whether [value] is a dotted-quad IPv4 address, such as `192.168.1.50`.
///
/// This is what the Star SDK accepts as a LAN printer identifier, alongside a
/// MAC address. Leading zeros (`192.168.001.050`) are rejected: some network
/// stacks read a zero-prefixed octet as octal, so `010` would quietly become
/// `8` and print to the wrong machine.
bool isValidIpv4(String value) {
  final octets = value.trim().split('.');
  if (octets.length != 4) return false;
  for (final octet in octets) {
    if (!RegExp(r'^(0|[1-9]\d{0,2})$').hasMatch(octet)) return false;
    if (int.parse(octet) > 255) return false;
  }
  return true;
}
