# Changelog

## 2.0.0

A silent print no longer waits out the Star SDK's connect timeout when the
printer is simply not there. The selected printer is probed first, with a short
timeout, and an unreachable one returns a typed failure straight away — before
any WebView render or scrim — so the host can tell the user at once.

Measured on a Star mC-Print3 over USB OTG with the printer unplugged: every
silent print used to wait the full Star `openTimeout` (about 5 s) before
failing; the USB case now answers instantly. LAN and Bluetooth still need a
real connection attempt, bounded by the check timeout.

- **Connection check.** New `DsPrint.checkConnection(device)` and
  `DsPrint.checkSelectedPrinterConnection()` return
  `Future<Either<DsPrintFailure, bool>>`; `Right(false)` means the printer did
  not answer. Natively (new `checkConnection` method on the
  `com.printer.html/sendToNative` channel) it opens and closes a connection with
  a timeout. A USB printer is answered instantly from `UsbManager` when no Star
  device (vendor id `0x0519`) is attached; a printer already held by another
  connection counts as reachable.
- **`printUrlSilently` checks first.** Order: resolve the selected printer,
  check its connection, then render and print. A `Right(false)` check returns
  `Left(PrinterUnreachableFailure)` immediately. A `Left` from the check itself
  is logged and printing proceeds (fail-open), so a faulty probe never blocks a
  print. New optional `connectionCheck:` takes a check the host started earlier
  (see the README) so it can overlap the network request that produces the
  invoice URL.
- **Checks never compete with jobs.** They run through the same queue as print
  jobs, so a check waits for a running job instead of being refused by a busy
  printer.
- **`PrinterUnreachableFailure`** with user-facing English and Arabic copy
  ("The printer is not connected" / "الطابعة غير متصلة").
- **Printers screen shows connection status.** Each saved printer gets a dot and
  a label (Checking… / Connected / Not connected, English and Arabic). Printers
  are checked one at a time when the list loads or the set of printers changes
  (not when only the selection changes); pull to refresh re-checks.
- **`DsPrintConfig.connectionCheckTimeout`** overrides the per-interface
  defaults (3 s for USB and LAN, 5 s for Bluetooth).
- **`DsPrintTheme`** gains `connectedIndicator` (default: green) and
  `disconnectedIndicator` (default: `colorScheme.error`).
- Documented: a Star printer with USB peripheral ports can make Android
  recreate the host Activity when plugged in or out, which looks like an app
  restart — add `keyboard|keyboardHidden|navigation` to `android:configChanges`
  (README, Troubleshooting).

Cost: a successful silent print now does one extra open/close of the printer
before capturing, unless the host overlaps it with the request via
`connectionCheck:`.

Breaking:

- `DsPrintFailure` has a new subtype, `PrinterUnreachableFailure`, so an
  exhaustive `switch` over it needs a new case.
- `printUrlSilently` returns `PrinterUnreachableFailure` for a selected but
  unreachable printer, with no render, instead of capturing the invoice and
  failing later with `NativePrintFailure`.
- `DsPrintTheme` has two new **required** constructor fields,
  `connectedIndicator` and `disconnectedIndicator`. Hosts that build one by
  hand (for `DsPrintConfig.themeOverride`) must supply them; `DsPrintTheme.of`
  already does.

## 1.0.0

Printers are now added manually, by connection type, and one of them is the
active printer every print goes to.

- **Printers screen no longer scans on open.** It lists the printers the user
  has added, with each one's connection type (USB / Network / Bluetooth) and
  icon, and marks the active one. Tap to make a printer active; swipe (with a
  confirmation) to remove it.
- **Add Printer sheet.** Choose USB, LAN or Bluetooth, scan only that type, tap
  a result. LAN also takes a typed IP address. The added printer becomes active.
- **`DsPrintAddPrinterButton`** (new, exported) puts the same button on any
  screen of the host app; `DsPrint.addPrinter()` opens the sheet from a custom
  control. Also new: `DsPrint.savedPrinters()`, `DsPrint.selectedPrinter()`,
  and `DsPrint.discover(interfaceType:)`.
- **`showBluetooth` / `showLan`** hide those options in the Add Printer sheet —
  app-wide on `DsPrintConfig`, or per use on the button, `PrinterPickerScreen`,
  `DsPrint.addPrinter()` and `DsPrint.selectDevice()`. USB is always offered.
- **Bluetooth and LAN discovery work.** Native discovery used to ignore the
  requested type, always scanned USB + LAN, and left Bluetooth out entirely.
  It now scans the requested interface, asks for the "Nearby devices"
  permission on Android 12+ (and for `ACCESS_LOCAL_NETWORK` on Android 17 when
  the host targets SDK 37), scans LAN for 5 s instead of 1 s, and reports a
  radio that is off instead of silently timing out.
- **The preview's Print button prints straight to the active printer**, and
  only opens the printers screen when there is none.
- Fixed: a printer fresh from discovery never compared equal to the same
  printer read back from storage (`PrinterDevice` equality included the
  runtime type), so the active printer could show as unselected.

Breaking:

- **Silent printing no longer pairs on its own.** `printUrlSilently`,
  `printBase64` and `printHtml` return `NoPrinterSelectedFailure` (previously
  `NoDeviceFoundFailure` after a scan) until the user adds a printer.
- **A native print failure no longer clears the active printer.**
- `DsPrintFailure` has three new subtypes — `PermissionDeniedFailure`,
  `InterfaceUnavailableFailure` and `DiscoveryFailure` — so an exhaustive
  `switch` over it needs new cases.
- Existing pairings carry over: the active printer keeps its storage keys and
  seeds the new saved-printers list on first read.

## 0.1.1

Fixes a native crash (`SIGABRT` on Android's RenderThread, reported as
`Failed to set damage region on surface, error=EGL_BAD_ACCESS`) when printing
anything but a short receipt.

The capture pipeline was asking the GPU for textures larger than Mali's
per-dimension `GL_MAX_TEXTURE_SIZE`, in two places: the pixel ratio budgeted
total *area* (~8 MP) with no per-dimension bound, and the WebView platform view
was laid out at the full document height. Allocations failed repeatedly and HWUI
eventually aborted the process.

- **Sliced capture.** The WebView is now a fixed size and the document is
  scrolled past it one viewport at a time. Slices abut exactly and print as one
  unbroken invoice with a single cut, so long invoices keep full resolution
  instead of being downscaled.
- **Printer-driven pixel ratio.** Captures target the paper width (595 dots)
  rather than an ~8 MP area budget. Anything wider was being rescaled away by
  `ImageParameter` anyway, at the cost of a proportionally larger texture. Every
  dimension is additionally hard-capped, with no legibility floor.
- **The platform view is no longer destroyed mid-capture.** `DsPrintWebSurface`
  builds one constant tree; it previously swapped between two structurally
  different ones, recreating the native view (and its `Surface`) twice per
  capture.
- The preview is now constrained to the capture width at all times, so it
  matches what the printer produces and the document cannot reflow between
  preview and capture. On tablets this narrows the preview to a receipt-width
  column.
- Capturing scrolls to the top of the document first and returns there
  afterwards.

Breaking, for direct users of the internal API: `ImageBase64Payload` now holds
`List<String> slices` — use `ImageBase64Payload.single(base64)` for a single
image. `InvoiceRenderPort.renderUrlToBase64Png` is now
`renderUrlToPngSlices`, returning `List<String>`.
`CaptureHeightResolver.resolvePixelRatio` is replaced by
`resolveCapturePixelRatio`. `DsPrintResponsive.captureContainerWidth` is gone
and `captureWidth` has taken over its value (`350`/null, not `500`/`390`) —
there is now one width, the one the invoice is laid out at, because that alone
determines both the pixel ratio and the printed text size. The public `DsPrint`
API is unchanged.

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
