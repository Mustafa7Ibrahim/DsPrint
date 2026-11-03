# ds_print example

A small host app that exercises every ds_print entry point against a live
invoice:

```
https://test4.maqsafy.com/seller/orders/2661/invoice-new-html
```

## Run

Printing needs a real Android device (Android 8.0+) with a Star printer
reachable over USB, LAN or Bluetooth.

```bash
cd example
flutter run
```

## What's on the screen

| Control | Shows |
| --- | --- |
| **Active printer** card | `DsPrint.selectedPrinter()` / `DsPrint.savedPrinters()` |
| **Offer Bluetooth / Offer LAN** switches | `DsPrintConfig(showBluetooth:, showLan:)` — which options the Add Printer sheet offers |
| **Add Printer** button | `DsPrintAddPrinterButton`, placed in the host's own screen |
| **Manage printers** | `DsPrint.selectDevice()` — the printers screen |
| **Preview & print** | `DsPrint.url()` — the invoice preview; Print goes to the active printer |
| **Print silently** | `DsPrint.printUrlSilently()` — no UI; fails with `NoPrinterSelectedFailure` until a printer is added |
| **English / العربية** | ds_print follows the app's locale, including right-to-left layout |

## Trying Bluetooth and LAN

- **Bluetooth:** pair the printer in Android's Bluetooth settings first, then
  Add Printer → Bluetooth → Next. Allow "Nearby devices" when asked.
- **LAN:** the phone and printer must be on the same network. If the scan
  doesn't find it, type the printer's IP address in the sheet.
