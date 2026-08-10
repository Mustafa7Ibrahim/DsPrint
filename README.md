# ds_print

Reusable invoice preview + thermal-printing plugin for Star Micronics
(StarXpand) printers.

Renders an invoice URL in a WebView, captures it as an image, and sends it to a
USB/Bluetooth/LAN thermal printer — either through a preview screen with a Print
button, or silently in the background.

- **How this package is built internally:** [`doc/ARCHITECTURE.md`](doc/ARCHITECTURE.md)

---

## Install

Add the git dependency:

```yaml
dependencies:
  ds_print:
    git:
      url: https://github.com/Mustafa7Ibrahim/DsPrint.git
      ref: v0.1.0
```

**That is the entire integration.** There is no setup call, no `init()`, no
config object to build, no DI to register, no translation keys to add, and no
Android edits. Import it and call it:

```dart
import 'package:ds_print/ds_print.dart';
```

The package resolves its own dependency container, theme, language, navigator
and storage from the host app at the moment of first use. See
[Zero-configuration](#zero-configuration) for how, and what it assumes about the
host.

---

## Quick start

```dart
// Open the invoice preview screen. The user taps Print, picks a device, done.
DsPrint.url('https://api.example.com/invoices/1042');
```

No `BuildContext` needed — the package finds the root navigator itself.

---

## API

| Call | What it does | Returns |
| --- | --- | --- |
| `DsPrint.url(url, {context, title})` | Pushes the invoice preview screen with a Print action | `Future<void>` |
| `DsPrint.printUrlSilently(url, {copies})` | Renders `url` off-screen and prints it with no UI | `Either<DsPrintFailure, Unit>` |
| `DsPrint.printBase64(base64, {copies})` | Prints an already-captured PNG | `Either<DsPrintFailure, Unit>` |
| `DsPrint.printHtml(html)` | Prints raw HTML (rendered natively) | `Either<DsPrintFailure, Unit>` |
| `DsPrint.selectDevice({context})` | Opens the picker to pair a printer without printing | `Future<void>` |
| `DsPrint.discover()` | Lists connected devices | `Either<DsPrintFailure, List<PrinterDevice>>` |
| `DsPrint.configure(config)` | Optional overrides — see [Customising](#customising) | `void` |

### `DsPrint.url` — preview then print

```dart
DsPrint.url(invoiceUrl, title: 'Order #1042');
```

Opens a screen showing the invoice with a **Print** action in the app bar.
Tapping it captures what is on screen and pushes the device picker; tapping a
device prints and pops back.

`title` defaults to a localised "Tax Invoice".

### `DsPrint.printUrlSilently` — no UI

For printing at the end of a flow, where the user should not see a preview:

```dart
final result = await DsPrint.printUrlSilently(invoiceUrl, copies: 2);

result.fold(
  (failure) => debugPrint(failure.debugMessage),
  (_) => debugPrint('printed'),
);
```

It prints to the **paired** printer, and if none is paired yet, to the first
device discovered — which it then pairs for next time. The pairing survives app
restarts.

**Safe to call unconditionally.** It looks for the printer *before* it renders
anything, so a store with no printer attached gets `NoDeviceFoundFailure` with
no overlay, no indicator and no invoice render — nothing the user can see. Fire
it after every order; the stores that have a printer print, the rest no-op.

"No UI" means no *navigation*: for the 1–3 seconds the render takes, the screen
keeps showing what it was showing, dimmed by a scrim with a loading indicator.
It is a still frame rather than the live screen — the invoice has to render in a
real, on-screen WebView to be capturable, so that WebView is covered with a
photograph of the screen taken the moment before. Taps are blocked for the
duration, since the frame underneath cannot react to them.

### Screens as routes

Both screens are exported and can be built directly by a router — they wire up
their own dependencies:

```dart
GoRoute(
  path: 'tax-invoice',
  builder: (context, state) => InvoicePreviewScreen(url: state.extra as String),
),
GoRoute(
  path: 'printer/add',
  builder: (context, state) => const PrinterPickerScreen(),
),
GoRoute(
  path: 'printer/base64',
  builder: (context, state) =>
      PrinterPickerScreen(payload: ImageBase64Payload(state.extra as String)),
),
```

`PrinterPickerScreen` with no payload pairs a device; with a payload it also
prints it to whichever device is tapped.

---

## Handling failures

Every printing call returns `Either<DsPrintFailure, Unit>` (from `dartz`) rather
than throwing. `DsPrintFailure` is a sealed class, so a `switch` over it is
checked at compile time:

| Failure | Meaning |
| --- | --- |
| `EmptyPayloadFailure` | Nothing to print |
| `NoDeviceFoundFailure` | Discovery returned no printers |
| `NoPrinterSelectedFailure` | A device was chosen but has no id/interface |
| `UnsupportedPlatformFailure` | Printing attempted off Android |
| `CaptureFailure(details)` | The invoice failed to render or snapshot |
| `NativePrintFailure(details)` | The printer or SDK reported an error, or timed out |
| `StorageFailure(details)` | Reading/writing the paired device failed |
| `NotConfiguredFailure(reason)` | No navigator/context could be resolved |

`debugMessage` is English and meant for logs. User-facing copy lives inside the
package and is already localised (see below) — the host does not need to
translate anything.

The package's own screens never use a `SnackBar`; errors are shown in a dialog.

---

## Zero-configuration

Everything the package needs, it reads from the host at the point of use:

| Need | Resolved from | Notes |
| --- | --- | --- |
| Colours | `Theme.of(context).primaryColor` | The flavor's brand colour; app bars, buttons, spinners and tile borders all follow it |
| Language | `Localizations.maybeLocaleOf(context)` | Arabic and English strings ship inside the package; defaults to Arabic |
| Navigator | Root `Navigator` found by walking the widget tree | Overridable with a `navigatorKey` |
| Paired printer | `SharedPreferences` | Keys `printer-deviceId` and `printer-device-interface-type` |
| Dependencies | A private `GetIt` instance | Never touches the host's `sl` |

Two consequences worth knowing:

- The package uses `theme.primaryColor`, **not** `colorScheme.primary`. Hosts
  that build `ThemeData` without a `colorScheme` get a Material 3 baseline
  scheme (a purple) that has nothing to do with their brand;`primaryColor` is
  the field such apps actually set.
- The package does **not** inherit `appBarTheme`, deliberately — see
  [Customising](#customising) if you need a different app bar.

## Customising

Optional. Call once before first use, typically in `main()`:

```dart
DsPrint.configure(DsPrintConfig(
  navigatorKey: myNavigatorKey,          // if tree-walking finds the wrong one
  printResultTimeout: Duration(seconds: 30), // default 20s
  themeOverride: DsPrintTheme(...),      // bypasses ambient theme entirely
));
```

`themeOverride` takes a fully-built `DsPrintTheme`; when set, the ambient
`ThemeData` is ignored completely. Use it when the host's `primaryColor` is not
the colour you want the print screens to use.

---

## Platform support

| | Preview screen | Discovery & printing |
| --- | --- | --- |
| Android (SDK 26+) | ✅ | ✅ |
| iOS | ✅ | ❌ `UnsupportedPlatformFailure` |

Printing is Android-only: the Star Micronics `stario10` SDK is bundled in the
package's Android library, and there is no iOS counterpart. The preview screen
and capture pipeline are pure Flutter and run anywhere.

Nothing needs adding to the host's `AndroidManifest.xml` or `build.gradle` —
the plugin's own manifest and Gradle file are merged in automatically.

---

## Troubleshooting

**"No printer connected" when a printer is plugged in.** USB discovery needs the
Android USB permission dialog to have been accepted for that device. Unplug,
replug, accept.

**Printing works once, then stops.** Usually the paired device id went stale
(different USB port or a reset printer). The package clears its cached pairing
automatically on a native failure and re-discovers on the next attempt.

**The invoice prints cut off at the bottom.** The capture waits for the page
height to stabilise, capped at 20 seconds. A page that keeps growing past that —
lazy-loaded images, web fonts arriving late — is snapshotted at whatever height
it had reached.

**The preview is blank/black on Android.** The WebView renders through Hybrid
Composition, which cannot paint into an offscreen layer. The package works
around this by mounting the capture boundary only while capturing; if you fork
the widget, keep that behaviour.

---

## Tests

```bash
flutter test
```

107 tests, all passing. They cover the use cases, the capture pipeline
services, the payload chunker, the print job queue, the cubits and both
screens' DI wiring.

Note for contributors: `CircularProgressIndicator` schedules frames forever, so
any test that ends on a loading state must use bounded `pump(Duration)` calls —
`pumpAndSettle()` will time out rather than settle.

## Developing against a host app

To iterate on the package while a host app consumes it, override the git
dependency with a local path in the **host's** `pubspec.yaml`:

```yaml
dependency_overrides:
  ds_print:
    path: ../DsPrint
```

Remove the override before committing.
