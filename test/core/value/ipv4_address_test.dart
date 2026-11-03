import 'package:flutter_test/flutter_test.dart';

import 'package:ds_print/src/core/value/ipv4_address.dart';

void main() {
  test('accepts dotted-quad addresses', () {
    for (final ip in [
      '192.168.1.50',
      '10.0.0.1',
      '0.0.0.0',
      '255.255.255.255',
      ' 172.16.4.9 ',
    ]) {
      expect(isValidIpv4(ip), isTrue, reason: ip);
    }
  });

  test('rejects anything else', () {
    for (final ip in [
      '',
      'abc',
      '256.1.1.1',
      '192.168.1',
      '192.168.1.50.1',
      '192.168.1.',
      '192..1.50',
      '-1.2.3.4',
      '1.2.3.4a',
      '192.168.001.050', // leading zeros can be read as octal
      '1 2.3.4.5',
    ]) {
      expect(isValidIpv4(ip), isFalse, reason: ip);
    }
  });
}
