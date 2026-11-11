# ds_print

Reusable invoice preview + thermal-printing plugin for Star Micronics
(StarXpand) printers.

Renders an invoice URL in a WebView, captures it as an image, and sends it to a
USB/Bluetooth/LAN thermal printer — either through a preview screen with a Print
button, or silently in the background.

- **How this package is built internally:** [`doc/ARCHITECTURE.md`](doc/ARCHITECTURE.md)
- **A runnable host app using every API:** [`example/`](example/)

---

## Install

Add the git dependency:

```yaml
dependencies:
  ds_print:
    git:
      url: https://github.com/Mustafa7Ibrahim/DsPrint.git
      ref: v2.0.0
```

Each release is a git tag. To move to a newer one, change `ref` and run
`flutter pub get` — see [`doc/RELEASING.md`](doc/RELEASING.md).

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
| `DsPrint.printUrlSilently(url, {copies, connectionCheck})` | Checks the active printer is reachable, then renders `url` off-screen and prints it with no UI | `Future<Either<DsPrintFailure, Unit>>` |
| `DsPrint.checkSelectedPrinterConnection()` | Tests whether the active printer answers, without printing | `Future<Either<DsPrintFailure, bool>>` |
| `DsPrint.checkConnection(device)` | Tests whether a given printer answers | `Future<Either<DsPrintFailure, bool>>` |
| `DsPrint.printBase64(base64, {copies})` | Prints an already-captured PNG | `Future<Either<DsPrintFailure, Unit>>` |
| `DsPrint.printHtml(html)` | Prints raw HTML (rendered natively) | `Future<Either<DsPrintFailure, Unit>>` |
| `DsPrint.selectDevice({context})` | Opens the printers screen: add printers, choose the active one | `Future<void>` |
| `DsPrint.addPrinter({context})` | Opens the Add Printer sheet on its own | `Future<PrinterDevice?>` |
| `DsPrint.savedPrinters()` | Every printer the user has added | `Future<Either<DsPrintFailure, List<PrinterDevice>>>` |
| `DsPrint.selectedPrinter()` | The active printer every print goes to | `Future<Either<DsPrintFailure, PrinterDevice?>>` |
| `DsPrint.discover({interfaceType})` | Scans without saving; `null` scans USB + LAN | `Future<Either<DsPrintFailure, List<PrinterDevice>>>` |
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

Under each printer a coloured dot and a label show whether it is reachable:
**Checking…**, **Connected** or **Not connected** (English and Arabic). The
printers are checked one at a time when the screen opens and whenever the set
of printers changes (adding or removing one — not merely choosing another
active printer). Pull down on the list to check them again. A printer that
errors during the check is shown as **Not connected**. The dot colours come
from `DsPrintTheme.connectedIndicator` / `disconnectedIndicator`
(see [Customising](#customising)).

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

In order, it:

1. Finds the active printer. None → `Left(NoPrinterSelectedFailure)`, and
   nothing else runs.
2. **Checks the printer is reachable** (see
   [Connection check](#connection-check)). The printer did not answer →
   `Left(PrinterUnreachableFailure)` immediately: no render, no scrim, nothing
   on screen. The check itself erroring is logged and ignored — printing
   proceeds, so a faulty probe never blocks a print.
3. Renders the invoice off-screen and captures it.
4. Sends it to the printer.

**Safe to call unconditionally.** Steps 1 and 2 happen *before* anything is
rendered, so a store with no printer — or a printer that is switched off —
gets a failure with no overlay, no indicator and no invoice render, nothing
the user can see. Fire it after every order; the stores whose printer is
there print, the rest get a failure you can ignore or act on.

"No UI" means no *navigation*: for the 1–3 seconds the render takes, the screen
keeps showing what it was showing, dimmed by a scrim with a loading indicator.
It is a still frame rather than the live screen — the invoice has to render in a
real, on-screen WebView to be capturable, so that WebView is covered with a
photograph of the screen taken the moment before. Taps are blocked for the
duration, since the frame underneath cannot react to them.

#### Overlapping the check with your own request

The check is one extra open/close of the printer before every print. Unless you
overlap it, a *successful* print pays for it. The usual flow — create an order,
get an invoice URL back, print it — lets you hide it behind the network call:
start the check **before** the request and hand the future to
`printUrlSilently`.

```dart
// 1. Start the check now. Do not await it yet.
final connectionCheck = DsPrint.checkSelectedPrinterConnection();

// 2. Do the request that produces the invoice URL.
final order = await orderRepository.create(cart);

// 3. By now the answer is usually ready, so printing starts at once.
final result = await DsPrint.printUrlSilently(
  order.invoiceUrl,
  connectionCheck: connectionCheck,
);
```

`printUrlSilently` awaits the future you pass instead of starting its own, and
applies the same rules as above (`Right(false)` → `PrinterUnreachableFailure`;
`Left` → logged, print anyway). Do **not** keep a future around and reuse it
for a later retry — it describes the printer at the moment it ran. Start a
fresh check each time.

### Connection check

Both methods open a connection to the printer with a short timeout and close it
again. Neither prints anything.

```dart
// The active printer.
final selected = await DsPrint.checkSelectedPrinterConnection();

// Any printer, e.g. one from DsPrint.savedPrinters().
final one = await DsPrint.checkConnection(printer);

selected.fold(
  (failure) => debugPrint(failure.debugMessage),   // could not run the check
  (reachable) => debugPrint(reachable ? 'ready' : 'not answering'),
);
```

Result, as `Either<DsPrintFailure, bool>`:

| Result | Meaning |
| --- | --- |
| `Right(true)` | The printer answered (or is already held by another connection — it is there) |
| `Right(false)` | The printer did not answer within the timeout: off, unplugged, out of range |
| `Left(NoPrinterSelectedFailure)` | `checkSelectedPrinterConnection` with no active printer, or a `checkConnection` device with no id |
| `Left(UnsupportedPlatformFailure)` | Off Android |
| `Left(NativePrintFailure)` | The native side could not run the check |

How long it waits: `DsPrintConfig.connectionCheckTimeout` if set, otherwise 3 s
for USB and LAN and 5 s for Bluetooth. A USB printer is the fast case — when no
Star USB device is attached at all, the answer is `Right(false)` instantly, with
no connection attempt. LAN and Bluetooth need a real attempt, so an absent
printer costs the full timeout.

A check is queued behind any print job that is running, so it never competes
with one for the printer; it just waits its turn.

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
than throwing; the connection checks return `Either<DsPrintFailure, bool>`. `DsPrintFailure` is a sealed class, so a `switch` over it is
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
| `PrinterUnreachableFailure` | The active printer did not answer the connection check — off, unplugged or out of range. Returned by `printUrlSilently` only; the check methods report it as `Right(false)` |

A `switch` over `DsPrintFailure` must handle every case — when upgrading to 2.0,
add one for `PrinterUnreachableFailure`.

### Telling the user the printer is not connected

`PrinterUnreachableFailure` is the failure worth acting on rather than
logging. `printUrlSilently` returns it instantly, before anything renders, so
you can ask the user what to do right away. (If every store is expected to have
a printer, treat `NoPrinterSelectedFailure` the same way.)

```dart
final result = await DsPrint.printUrlSilently(
  order.invoiceUrl,
  connectionCheck: connectionCheck,
);

result.fold(
  (failure) {
    switch (failure) {
      case PrinterUnreachableFailure():
        showPrinterOfflineDialog(
          message: 'The printer is not connected', // your own localised text
          onRetry: () => DsPrint.printUrlSilently(order.invoiceUrl),
          onChoosePrinter: () => DsPrint.selectDevice(),
        );
      case NoPrinterSelectedFailure():
        break; // store without a printer: nothing to do
      default:
        debugPrint(failure.debugMessage);
    }
  },
  (_) => debugPrint('printed'),
);
```

`showPrinterOfflineDialog` and its text are yours: the package's own localised
copy ("The printer is not connected" / "الطابعة غير متصلة") is shown only by its
own screens and is not exported. Retrying calls `printUrlSilently`
*without* the old `connectionCheck` future, so it starts a fresh check.
`DsPrint.selectDevice()` opens the printers screen, where the user can see
which printers are connected and pick another one.

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
  connectionCheckTimeout: Duration(seconds: 4), // default 3s USB/LAN, 5s Bluetooth
  themeOverride: DsPrintTheme(...),      // bypasses ambient theme entirely
  showBluetooth: false,                  // hide Bluetooth in Add Printer
  showLan: false,                        // hide LAN in Add Printer
));
```

`themeOverride` takes a fully-built `DsPrintTheme`; when set, the ambient
`ThemeData` is ignored completely. Use it when the host's `primaryColor` is not
the colour you want the print screens to use.

`DsPrintTheme` has two fields for the printers screen's connection status, both
**required** when you construct one yourself:

| Field | Used for | Default in `DsPrintTheme.of` |
| --- | --- | --- |
| `connectedIndicator` | The dot beside "Connected" | `Colors.green.shade600` |
| `disconnectedIndicator` | The dot beside "Not connected" | `colorScheme.error` |

(The "Checking…" dot uses `unselectedIndicator`.) Hosts that only rely on the
ambient theme need to do nothing; a host that builds `DsPrintTheme(...)` by hand
for `themeOverride` must add both when upgrading to 2.0.

`connectionCheckTimeout` is how long a [connection check](#connection-check)
waits for the printer — for `printUrlSilently`, the two `checkConnection`
methods and the printers screen alike. Leave it `null` for 3 s (USB, LAN) and
5 s (Bluetooth). Raise it if a slow network or Bluetooth link reports a printer
as not connected when it is fine; keep it short, because it is also how long an
absent LAN or Bluetooth printer delays a print.

---

## Platform support

| | Preview screen | Discovery & printing |
| --- | --- | --- |
| Android (SDK 26+) | ✅ | ✅ |
| iOS | ✅ | ❌ `UnsupportedPlatformFailure` |

Printing is Android-only: the Star Micronics `stario10` SDK is bundled in the
package's Android library, and there is no iOS counterpart. The preview screen
and capture pipeline are pure Flutter and run anywhere.

Nothing needs adding to the host's `build.gradle` — the plugin's own manifest
and Gradle file are merged in automatically. Two things can need a line in the
host's `AndroidManifest.xml`, both optional:

- `ACCESS_LOCAL_NETWORK` for apps targeting SDK 37 — see
  [Bluetooth and LAN on Android](#bluetooth-and-lan-on-android).
- `keyboard|keyboardHidden|navigation` in `android:configChanges` of the
  host's `MainActivity`, if you use a Star printer over USB — see
  [Troubleshooting](#troubleshooting).

---

## Troubleshooting

**"No printer connected" when a printer is plugged in.** USB discovery needs the
Android USB permission dialog to have been accepted for that device. Unplug,
replug, accept.

**The app restarts when a Star printer is plugged in or unplugged over USB.**
Star models with USB peripheral ports (the mC-Print3, for one) expose whatever is
attached to them — barcode scanners, keyboards, a wireless keyboard/mouse
dongle — to Android as HID devices while the printer is plugged in. Plugging or
unplugging the printer therefore changes the Activity's configuration
(`keyboard`, `keyboardHidden` and, on devices with a D-pad, `navigation`). If
your `MainActivity` does not declare those in `android:configChanges`, Android
destroys and recreates it, and the Flutter app looks as if it restarted. Add
them in the **host** manifest:

```xml
<activity
    android:name=".MainActivity"
    android:configChanges="orientation|screenSize|keyboard|keyboardHidden|navigation|..." />
```

(keep whatever your activity already lists, and make sure all three are
present). To confirm this is the cause, run `adb logcat` while plugging the
printer and look for
`WindowManager: Checking to restart ... not-handles={CONFIG_NAVIGATION}` (the
`not-handles` set names the missing flags).

**A printer shows "Not connected" (or `PrinterUnreachableFailure`) although it is
fine.** The check is deliberately short (3 s USB/LAN, 5 s Bluetooth), so a slow
link can miss it — raise `DsPrintConfig.connectionCheckTimeout`. For USB, the
first open of a printer triggers Android's USB-permission dialog; a check that
runs while the dialog is still open times out and reports "not connected". Accept
the dialog (a print or a pull-to-refresh on the printers screen then succeeds). A
printer that is *busy* with another connection counts as connected, not as
failed.

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

216 tests cover the use cases, the capture pipeline services, the payload
chunker, the print job queue, the cubits and both screens' DI wiring. The
connection check (2.0.0) has no dedicated tests yet; the existing suites fake it
so they stay hermetic.

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

Remove the override before committing. When the change is ready for the host
to pin, cut a release: [`doc/RELEASING.md`](doc/RELEASING.md).
