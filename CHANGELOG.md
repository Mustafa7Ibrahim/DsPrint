# Changelog

## 0.1.0

Initial release.

- Invoice preview screen (`DsPrint.url`) — renders an invoice URL in a WebView
  with a Print action, captures the on-screen surface and prints it.
- Silent printing (`DsPrint.printUrlSilently`) — renders off-screen behind a
  still frame of the current screen and prints with no navigation.
- `DsPrint.printBase64`, `DsPrint.printHtml`, `DsPrint.selectDevice`,
  `DsPrint.discover`.
- Star Micronics StarXpand (`stario10`) support over USB, Bluetooth and LAN on
  Android (minSdk 26). Printing is Android-only; the preview screen runs
  anywhere.
- Zero-configuration: theme, locale, navigator and storage are resolved from
  the host app at the point of use. Optional overrides via `DsPrint.configure`.
- Typed failures — every printing call returns `Either<DsPrintFailure, Unit>`.
