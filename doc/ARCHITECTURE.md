# ds_print — how it is built

Companion to the [README](../README.md), which covers *using* the package. This
document covers *why it looks the way it does*: the layering, the two print
paths, the capture algorithm, the native bridge, and the constraints that shaped
each.

The package was extracted from ~20 files spread across the Maqsafy host app
(`lib/modules/shared/printer/`, `lib/core/utils/native/printer*/`,
`tax_invoice_screen/`, `core/widgets/screenshot/`, and a 335-line
`MainActivity.kt`). Several sections below contrast the two, because most of the
design decisions here only make sense as answers to a specific problem in the
original.

---

## 1. Layout

```
lib/
├── ds_print.dart                  ← the only public surface (a barrel)
└── src/
    ├── core/                      ← config, DI, errors, value objects
    ├── domain/                    ← entities, ports, repository interfaces, use cases
    ├── data/                      ← datasources, models, repository impls, services
    └── presentation/              ← screens, cubits, widgets, renderers
android/src/main/kotlin/com/dsprint/ds_print/
├── DsPrintPlugin.kt               ← channel registration only
├── channel/                       ← chunk assembly, event sink, request DTO
├── dispatch/                      ← strategy per payload type
├── star/                          ← the only file that touches the Star SDK
└── html/                          ← offscreen HTML → bitmap activity
```

### The dependency rule

```
core  ←  domain  ←  data
          ↑           ↑
          └─── presentation ───┘
```

`domain` imports nothing from `data` or `presentation`. `data` and
`presentation` both depend inwards on `domain`. This is checkable:

```bash
grep -rE "import '\.\./\.\./(data|presentation)" lib/src/domain   # must be empty
```

The one edge that looks like a violation and isn't: `presentation` implements
`domain/ports/invoice_render_port.dart`. The *interface* is in `domain`; only
the WebView-bound implementation lives in `presentation`. That is dependency
inversion working as intended — `domain` never learns what a WebView is.

### Public surface

`ds_print.dart` exports the facade, config, theme, failures, entities and the
two screens. Repositories, use cases, datasources, services and the DI container
are **not** exported. Anything not in that barrel can be changed without a
breaking release.

---

## 2. The two print paths

Both paths converge on the same capture pipeline and the same native bridge;
they differ only in *which WebView* gets captured.

### Path A — preview (`DsPrint.url`)

```
InvoicePreviewScreen
  └─ DsPrintWebSurface ──── loads the invoice, user sees it
        │
      [Print tapped]
        │
  InvoicePreviewCubit.capture(url, renderer: SurfaceInvoiceRenderer(handle))
        └─ CaptureInvoiceUseCase → InvoiceCaptureRepository
              └─ SurfaceInvoiceRenderer → captures the surface already on screen
        │
  → PrinterPickerScreen(payload) → PrintJobCubit → native
```

The renderer is passed *in* at call time rather than injected, so the screen can
say "capture the copy I already have" instead of "go render this URL somewhere".
The capture takes a couple of seconds, during which a `Colors.black26` scrim and
a spinner sit over the still-visible invoice.

> **Regression worth remembering.** The first version of this package routed the
> preview screen through the headless renderer below. Tapping Print therefore
> downloaded and rendered the invoice a *second* time in an overlay, while an
> opaque white cover hid the perfectly good copy underneath — the user saw a
> blank white screen for several seconds. The legacy `TaxInvoiceScreen` had
> always captured its own WebView; `SurfaceInvoiceRenderer` restores that.

### Path B — silent (`DsPrint.printUrlSilently`)

```
DsPrint.printUrlSilently(url)
  └─ CaptureInvoiceUseCase → InvoiceCaptureRepository
        └─ OverlayInvoiceRenderer
              ├─ inserts an OverlayEntry: DsPrintWebSurface + DsPrintCaptureCover
              ├─ autoCaptureOnLoad → capture pipeline
              └─ removes the entry in a `finally` (timeout and error paths too)
  └─ AutoPrintUseCase → cached device, else discover-and-pair → native
```

There is no screen to capture here, so one is created. The WebView **must be
mounted on screen and painted at least once** — a `RepaintBoundary` snapshots a
composited layer, and a subtree that never painted has no layer. That rules out
`Offstage`, `Opacity(0)`, and positioning it off the viewport: all three skip
painting. The only remaining option is to paint it and cover it, which is what
`DsPrintCaptureCover` does — using the host's page background plus the standard
spinner, so the wait reads as a loading state rather than a frozen blank page.

---

## 3. The capture pipeline

`InvoiceCaptureRunner` (in `data/services/`) is the single implementation both
paths share. In the host app this logic existed twice, in
`tax_invoice_screen.dart` and `logic_screenshoot.dart`, and had already drifted.

```
expandDocument()        → strip overflow/height/padding constraints via JS
readScrollHeight()      → initial document height
stabilize()             → poll until 3 consecutive reads differ by <1px
trimToContentBottom()   → find the real content bottom, trim trailing whitespace
resolvePixelRatio()     → sqrt(8_000_000 / (w*h)).clamp(1.5, 10)
boundary.toPngBytes()   → RepaintBoundary → ui.Image → PNG → base64
─────────────────────── finally ───────────────────────
restoreDocument()       → put the DOM back
onCaptureHeight(null)   → collapse the widget back to normal layout
```

Three details that are load-bearing:

**Why poll for stability at all.** `scrollHeight` is correct only once the
browser has laid out everything — late images, web fonts and expanding rows all
change it. Reading it once produces invoices cut off mid-table. Three
consecutive stable reads (1.5s of quiet) avoids the false positive where the
height pauses between two expansions. Capped at 40 polls / 20 seconds.

**Why the pixel ratio is computed, not fixed.** `toImage` allocates
`width × height × ratio²` pixels. A long invoice at a fixed ratio of 3 can
exhaust memory; a short one at ratio 1 prints fuzzy. `sqrt(8M / area)` targets a
constant ~8-megapixel budget, clamped to a legible floor of 1.5.

**Why `restoreDocument` is in a `finally`.** The original restored the DOM on
the success path and inside one `catch`, so any other error left the page
permanently expanded — the user returned to a preview that scrolled forever.

### Testability

The runner talks to two interfaces, not to Flutter:

```dart
abstract class DsWebController  { Future<void> runJavaScript(String); ... }
abstract class DsImageBoundary  { Future<Uint8List?> toPngBytes(double); }
```

`WebViewDsWebController` and `RepaintBoundaryImage` are the real
implementations; the tests substitute fakes. This is why the height/stabilise/
trim algorithm has unit tests at all — none of it needs a `WebViewPlatform`.

---

## 4. The native bridge

### Channels

| Channel | Type | Direction |
| --- | --- | --- |
| `com.printer.discover/event` | Event | native → Dart, discovered devices |
| `com.printer.html/sendToNative` | Method | Dart → native, payload chunks |
| `com.printer.html/listenFromNative` | Event | native → Dart, `success`/`failed` |

Channel names are duplicated between `ds_print_injection.dart` and
`DsPrintPlugin.kt`. A mismatch is a silent runtime no-op, not a build error —
keep them in sync.

### The chunking protocol

`MethodChannel` payloads are size-limited in practice, so a base64 invoice
(hundreds of KB) is split into 1000-character chunks, each tagged with its
position:

| Chunks | Statuses sent |
| --- | --- |
| 1 | `one-index` |
| 2 | `start`, `completed` |
| 5 | `start`, `progress`, `progress`, `progress`, `completed` |

The Kotlin side accumulates in `PrintRequestAssembler` and only dispatches on
`completed`/`one-index`. The hyphen in `one-index` is matched literally in
Kotlin — `ChunkStatus.wireName` exists so that string is written exactly once on
the Dart side.

### Two ordering bugs fixed in the port

**The result listener was subscribed after sending.** A fast printer could reply
before Dart was listening, and the print would hang until timeout. The result
future is now awaited *before* the first chunk goes out.

**A subscription leaked per print.** The legacy controller called `.listen()`
per print and never cancelled, so after N prints, N handlers fired for every
subsequent result. Now one lazily-created broadcast stream is reused.

Also: native reported `"success"` when the *job was accepted*, not when it
finished. Success is now reported after the SDK's print call returns.

### Kotlin structure

`DsPrintPlugin` registers channels and delegates — nothing else. Dispatch is a
strategy per payload type (`HtmlPrintStrategy`, `ImagePrintStrategy`), and
`StarPrinterGateway` is the only file that imports the Star SDK. Swapping to a
different printer vendor means writing one new gateway.

`HtmlConverterActivity` renders HTML to a bitmap offscreen for the
`printHtml` path; it is declared in the package's own manifest, which Gradle
merges into the host APK.

---

## 5. SOLID, concretely

Each row names the actual defect in the original code that the principle
addresses — not the principle in the abstract.

| | Where | What it fixed |
| --- | --- | --- |
| **S**RP | `InvoiceCaptureRunner`, `PayloadChunker`, `ChunkStatusResolver`, `CaptureHeightResolver`, `PrintJobQueue` | A 261-line `PrinterCubit` mixing discovery, caching, chunking, dispatch and UI state |
| **O**CP | `sealed class PrintPayload` + exhaustive `switch` | `if (type == "html") ... else ...` silently fell through to HTML for unknown types; a new payload type is now a compile error until handled |
| **L**SP | `DsWebController`, `DsImageBoundary`, `InvoiceRenderPort` | Fakes substitute for platform types in tests; `SurfaceInvoiceRenderer` and `OverlayInvoiceRenderer` are interchangeable at the call site |
| **I**SP | Four repositories (capture, discovery, print, selection) | One god-interface would force every consumer to depend on all of it |
| **D**IP | Platform types (`MethodChannel`, `WebViewController`, `SharedPreferences`) confined to `data/datasources` | `domain` and use cases are pure Dart, unit-testable without a binding |

### Static state removed

Two pieces of static mutable state in the original caused real races:

- `PrinterCubit.printerSelectedIdentifier` (static) — two screens could
  disagree about the selected printer. Now the selection lives in
  `PrinterDiscoverySuccess(devices, selected)`, i.e. on the state, and is
  persisted through `SelectedPrinterRepository`.
- A static chained-`Future` send lock — a rejected job wedged the chain
  permanently. `PrintJobQueue` is per-instance and always advances its tail in a
  `finally`.

---

## 6. Dependency injection

```dart
final GetIt dsPrintSl = GetIt.asNewInstance();
```

A **private container**, not the host's `sl`. The host registers ~1200 lines of
its own; sharing an instance risks type collisions and forces the host to
initialise the package.

```dart
T dsPrintResolve<T extends Object>() {
  dsPrintInjection();   // idempotent
  return dsPrintSl<T>();
}
```

Every entry point resolves through `dsPrintResolve`. **This includes the
screens** — a host router builds `InvoicePreviewScreen` directly without ever
calling a `DsPrint.*` method, and resolving straight from `dsPrintSl` in that
case threw *"InvoicePreviewCubit is not registered inside GetIt"* on device.

The registration guard is container state, not a bool:

```dart
if (dsPrintSl.isRegistered<AutoPrintUseCase>()) return;
```

A bool can desync from the container (`dsPrintSl.reset()` empties it but leaves
the flag `true`, silently skipping re-registration). `AutoPrintUseCase` is
registered near the end of the sequence, so its presence means "fully
registered".

---

## 7. Zero-configuration, mechanically

The constraint was: the host adds a pubspec entry and calls the API — nothing
else. Four things normally require setup; here is how each is avoided.

**Theme.** `DsPrintTheme.of(context)` derives everything from ambient
`ThemeData`. It reads `theme.primaryColor` rather than `colorScheme.primary`,
because a host that builds `ThemeData` without an explicit `colorScheme` gets
the Material 3 baseline (purple) — unrelated to its brand.

It also does **not** inherit `appBarTheme`. The host's global one is
`backgroundColor: Colors.white`, which no real screen renders — every screen
passes its own `BaseAppBar` with a primary background and a white title.
Inheriting it produced a white app bar with a white "Print" label on it.
`DsPrintAppBar` reproduces `BaseAppBar`'s appearance from resolved theme values,
and pins `surfaceTintColor` to transparent so M3's scroll-under tint cannot
drift the brand colour.

**Strings.** `DsPrintStrings` is a plain class with Arabic/English getters, keyed
off `Localizations.maybeLocaleOf(context)`. No `easy_localization` dependency, no
JSON, no keys for the host to add. `forFailure()` is an exhaustive `switch` over
`DsPrintFailure`, so a new failure type won't compile until it has copy.

**Context.** `RootContextResolver` tries, in order: an explicit `context:`
argument → `DsPrintConfig.current?.navigatorKey` → walking
`WidgetsBinding.instance.rootElement` for the first `Navigator`. The third makes
`DsPrint.url("link")` work from anywhere.

**Storage.** `SelectedPrinterDataSourceImpl` writes `SharedPreferences` under
`printer-deviceId` and `printer-device-interface-type` — byte-identical to the
legacy `CacheKeys`, so printers paired before the migration still work.

---

## 8. Constraints and gotchas

**Android WebView + `RepaintBoundary`.** Under Hybrid Composition the WebView is
a native `SurfaceView` and cannot paint into an offscreen layer — it captures
black. `DsPrintWebSurface` therefore mounts the `RepaintBoundary` *only* while a
capture is in flight (`_captureHeight != null`); the rest of the time the
platform view renders directly.

**`Localizations` in `initState`.** Reading `Localizations` (for the
`Accept-Language` header) inside `initState` throws
`dependOnInheritedWidgetOfExactType<_LocalizationsScope>() was called before
initState() completed`. The page load happens in `didChangeDependencies`
instead, guarded by `_hasRequestedUrl` so a locale or theme change can't reload
the page mid-capture.

**`go_router` and shell routes.** `DsPrint.url` pushes a plain
`MaterialPageRoute` on the root navigator rather than using `go_router`. Pushing
a shell-nested path from a route outside the shell crashes with
`Failed assertion: '!keyReservation.contains(key)'` (duplicate `Page` key). An
imperative root push sidesteps the whole problem.

**A spinner defeats `pumpAndSettle`.** `CircularProgressIndicator` schedules
frames forever, so any widget test that ends on a loading state times out rather
than settling. Use `pump(Duration)` in a loop for those.

---

## 9. Where the host touches the package

| Host file | Use |
| --- | --- |
| `pubspec.yaml` | `ds_print: path: packages/ds_print` |
| `lib/core/router_v2/routes/shared/shared_routes.dart` | Four routes: `tax-invoice`, `printer/add`, `printer/html`, `printer/base64` |
| `lib/modules/shared/cart/cubit/order/order_create_cubit.dart` | `DsPrint.printUrlSilently` after an order is created |
| `lib/modules/shared/test_screen/TestScreen.dart` | Manual smoke test |

`android/app/src/main/kotlin/.../MainActivity.kt` went from 335 lines to five —
all of the printing, discovery and Star SDK code moved into the plugin.
