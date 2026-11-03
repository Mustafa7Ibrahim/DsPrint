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
// Once: let the user add a printer (USB, LAN or Bluetooth).
DsPrint.selectDevice();

// From then on, every print goes to that printer.
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
| `DsPrint.selectDevice({context})` | Opens the printers screen: add printers, choose the active one | `Future<void>` |
| `DsPrint.addPrinter({context})` | Opens the Add Printer sheet on its own | `Future<PrinterDevice?>` |
| `DsPrint.savedPrinters()` | Every printer the user has added | `Either<DsPrintFailure, List<PrinterDevice>>` |
| `DsPrint.selectedPrinter()` | The active printer every print goes to | `Either<DsPrintFailure, PrinterDevice?>` |
| `DsPrint.discover({interfaceType})` | Scans without saving; `null` scans USB + LAN | `Either<DsPrintFailure, List<PrinterDevice>>` |
| `DsPrint.configure(config)` | Optional overrides — see [Customising](#customising) | `void` |

### Printers — added manually, one active

Nothing is ever discovered or paired behind the user's back. The user adds
printers on the printers screen (`DsPrint.selectDevice()` or
`PrinterPickerScreen`):

1. **Add Printer** opens a sheet: choose **USB**, **Network (LAN)** or
   **Bluetooth**, then **Next**.
2. Only that connection type is scanned. LAN also accepts a typed IP address,
   for a printer the scan can't see (another subnet, say).
3. Tapping a printer saves it and makes it the **active** printer.

The screen lists every saved printer with its connection type and marks the
active one. Tapping another printer makes it active; swiping one away (with a
confirmation) removes it — removing the active printer leaves none active.

**The active printer is used automatically by every print call** —
`printUrlSilently`, `printBase64`, `printHtml`, and the preview screen's Print
button. When none is active, the silent calls return
`NoPrinterSelectedFailure` and the preview screen opens the printers screen
instead.

#### The Add Printer button in your own UI

`DsPrintAddPrinterButton` is the same button, usable on any screen without the
printers screen:

```dart
DsPrintAddPrinterButton(
  onPrinterAdded: (printer) => debugPrint('now printing to ${printer.id}'),
  label: 'Connect a printer',          // optional, defaults to "Add Printer"
  style: ElevatedButton.styleFrom(...), // optional, merged over the default
  showBluetooth: false,                 // optional, hide Bluetooth in the sheet
  showLan: true,                        // optional, hide LAN with false
)
```

#### Choosing which connection types are offered

USB is always offered. Bluetooth and LAN can be hidden app-wide:

```dart
DsPrint.configure(const DsPrintConfig(showBluetooth: false, showLan: true));
```

or for one place, with the same `showBluetooth` / `showLan` parameters on
`DsPrintAddPrinterButton`, `PrinterPickerScreen`, `DsPrint.addPrinter()` and
`DsPrint.selectDevice()` — a value there overrides the app-wide one. Leaving a
flag `null` shows the option. When only USB is left, it's pre-selected so the
user goes straight to **Next**.

Or open the sheet from a control of your own:

```dart
final printer = await DsPrint.addPrinter(); // null if the user closed it
```

#### Bluetooth and LAN on Android

- **Bluetooth** lists printers already **paired in Android's Bluetooth
  settings** — the Star SDK cannot pair one itself. On Android 12+ the sheet
  asks for the "Nearby devices" (`BLUETOOTH_CONNECT`) permission the first
  time; the permission itself is declared by the Star SDK, so there is nothing
  to add to your manifest.
- **LAN** needs nothing extra unless your app **targets SDK 37 (Android 17)**:
  then declare
  `<uses-permission android:name="android.permission.ACCESS_LOCAL_NETWORK" />`
  in your app's manifest, and the sheet will request it before scanning.
  Google advises against declaring it below target 37, so the package doesn't.

### `DsPrint.url` — preview then print

```dart
DsPrint.url(invoiceUrl, title: 'Order #1042');
```

Opens a screen showing the invoice with a **Print** action in the app bar.
Tapping it captures what is on screen and prints it to the active printer. If
no printer is active yet it opens the printers screen; adding or tapping a
printer there prints and pops back.

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

It prints to the **active** printer (see [Printers](#printers--added-manually-one-active)).
It never scans: with no active printer it returns `NoPrinterSelectedFailure`.
The choice survives app restarts, and a failed print does not drop it.

**Safe to call unconditionally.** It checks for the printer *before* it renders
anything, so a store with no printer gets `NoPrinterSelectedFailure` with no
overlay, no indicator and no invoice render — nothing the user can see. Fire it
after every order; the stores that have a printer print, the rest no-op.

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
      PrinterPickerScreen(
          payload: ImageBase64Payload.single(state.extra as String)),
),
```

`PrinterPickerScreen` with no payload manages printers; with a payload it also
prints it — to the printer tapped, or to one added right there — and pops.

---

## Handling failures

Every printing call returns `Either<DsPrintFailure, Unit>` (from `dartz`) rather
than throwing. `DsPrintFailure` is a sealed class, so a `switch` over it is
checked at compile time:

| Failure | Meaning |
| --- | --- |
| `EmptyPayloadFailure` | Nothing to print |
| `NoDeviceFoundFailure` | Discovery returned no printers |
| `NoPrinterSelectedFailure` | No active printer — the user hasn't added/chosen one |
| `PermissionDeniedFailure` | The user refused the "Nearby devices" permission a scan needs |
| `InterfaceUnavailableFailure(interfaceType)` | Bluetooth is off, there is no network, or USB is unavailable |
| `DiscoveryFailure(details)` | The Star SDK failed to scan |
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
| Active printer | `SharedPreferences` | Keys `printer-deviceId` and `printer-device-interface-type` (unchanged, so existing pairings carry over) |
| Saved printers | `SharedPreferences` | Key `ds_print-saved-printers`; seeded once from the active printer on upgrade |
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
  showBluetooth: false,                  // hide Bluetooth in Add Printer
  showLan: false,                        // hide LAN in Add Printer
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
the plugin's own manifest and Gradle file are merged in automatically. The one
exception is `ACCESS_LOCAL_NETWORK` for apps targeting SDK 37 — see
[Bluetooth and LAN on Android](#bluetooth-and-lan-on-android).

---

## Troubleshooting

**"No printer connected" when a printer is plugged in.** USB discovery needs the
Android USB permission dialog to have been accepted for that device. Unplug,
replug, accept.

**Printing works once, then stops.** Usually the saved device id went stale
(different USB port or a reset printer). Remove the printer on the printers
screen and add it again.

**A Bluetooth printer doesn't show up.** Pair it in Android's Bluetooth
settings first, and make sure Bluetooth is on and the "Nearby devices"
permission was allowed.

**A LAN printer doesn't show up.** The phone and the printer must be on the
same network; the scan does not cross subnets. Type the printer's IP address
in the sheet instead.

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

216 tests, all passing. They cover the use cases, the capture pipeline
services, the payload chunker, the print job queue, the cubits and both
screens' DI wiring.

Bluetooth and LAN discovery are tested from the platform channel inward: the
real discovery datasource runs against a mocked native side of
`com.printer.discover/event`, both directly
(`printer_discovery_datasource_test.dart`) and end to end through the printers
screen and Add Printer sheet (`printer_picker_screen_test.dart`). The Kotlin
side — the permission prompt and the Star SDK scan itself — needs a device.

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
