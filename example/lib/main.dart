import 'package:ds_print/ds_print.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// A live invoice from the Maqsafy test environment.
const invoiceUrl =
    'https://test4.maqsafy.com/seller/orders/2661/invoice-new-html';

void main() => runApp(const ExampleApp());

class ExampleApp extends StatefulWidget {
  const ExampleApp({super.key});

  @override
  State<ExampleApp> createState() => _ExampleAppState();
}

class _ExampleAppState extends State<ExampleApp> {
  // ds_print follows the app's locale — Arabic (RTL) or English.
  Locale _locale = const Locale('ar');

  @override
  Widget build(BuildContext context) {
    const brand = Color(0xFF00897B);
    return MaterialApp(
      title: 'ds_print example',
      debugShowCheckedModeBanner: false,
      locale: _locale,
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // ds_print takes its colours from `primaryColor` — nothing else to set.
      theme: ThemeData(
        primaryColor: brand,
        colorScheme: ColorScheme.fromSeed(seedColor: brand),
      ),
      home: ExampleHome(
        isArabic: _locale.languageCode == 'ar',
        onToggleLanguage: () => setState(() {
          _locale = Locale(_locale.languageCode == 'ar' ? 'en' : 'ar');
        }),
      ),
    );
  }
}

class ExampleHome extends StatefulWidget {
  final bool isArabic;
  final VoidCallback onToggleLanguage;

  const ExampleHome({
    super.key,
    required this.isArabic,
    required this.onToggleLanguage,
  });

  @override
  State<ExampleHome> createState() => _ExampleHomeState();
}

class _ExampleHomeState extends State<ExampleHome> {
  PrinterDevice? _activePrinter;
  int _savedCount = 0;
  bool _showBluetooth = true;
  bool _showLan = true;
  bool _printing = false;

  @override
  void initState() {
    super.initState();
    _applyConfig();
    _refresh();
  }

  /// The app-wide switches for which connection types Add Printer offers.
  /// A `showBluetooth:` / `showLan:` passed to a single button or screen
  /// would override these for that one place.
  void _applyConfig() {
    DsPrint.configure(
      DsPrintConfig(showBluetooth: _showBluetooth, showLan: _showLan),
    );
  }

  Future<void> _refresh() async {
    final active = await DsPrint.selectedPrinter();
    final saved = await DsPrint.savedPrinters();
    if (!mounted) return;
    setState(() {
      _activePrinter = active.getOrElse(() => null);
      _savedCount = saved.fold((_) => 0, (printers) => printers.length);
    });
  }

  Future<void> _openPrinters() async {
    await DsPrint.selectDevice(context: context);
    await _refresh();
  }

  Future<void> _previewAndPrint() async {
    await DsPrint.url(invoiceUrl, context: context, title: 'Order #2661');
    // The preview's Print button may have added a printer on the way.
    await _refresh();
  }

  Future<void> _printSilently() async {
    setState(() => _printing = true);
    final result = await DsPrint.printUrlSilently(invoiceUrl);
    if (!mounted) return;
    setState(() => _printing = false);
    _show(result.fold(
      (failure) => switch (failure) {
        NoPrinterSelectedFailure() =>
          'No printer selected — add one first, then try again.',
        UnsupportedPlatformFailure() => 'Printing works on Android only.',
        _ => failure.debugMessage,
      },
      (_) => 'Sent to ${_describe(_activePrinter)}.',
    ));
  }

  void _show(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _describe(PrinterDevice? printer) => printer == null
      ? 'none'
      : '${switch (printer.interfaceType) {
          PrinterInterfaceType.usb => 'USB',
          PrinterInterfaceType.lan => 'LAN',
          PrinterInterfaceType.bluetooth => 'Bluetooth',
        }} · ${printer.id}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('ds_print example'),
        actions: [
          TextButton(
            onPressed: widget.onToggleLanguage,
            child: Text(widget.isArabic ? 'English' : 'العربية'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Card(
              child: ListTile(
                leading: Icon(Icons.print, color: theme.primaryColor),
                title: const Text('Active printer'),
                subtitle: Text(
                  _activePrinter == null
                      ? 'None — add one below'
                      : _describe(_activePrinter),
                  textDirection: TextDirection.ltr,
                ),
                trailing: Text('$_savedCount saved'),
              ),
            ),
            const _SectionTitle('Printers'),
            SwitchListTile(
              title: const Text('Offer Bluetooth'),
              subtitle: const Text('DsPrintConfig.showBluetooth'),
              value: _showBluetooth,
              onChanged: (value) {
                setState(() => _showBluetooth = value);
                _applyConfig();
              },
            ),
            SwitchListTile(
              title: const Text('Offer LAN'),
              subtitle: const Text('DsPrintConfig.showLan'),
              value: _showLan,
              onChanged: (value) {
                setState(() => _showLan = value);
                _applyConfig();
              },
            ),
            const SizedBox(height: 8),
            // The package's Add Printer button, dropped into the host's own
            // screen — no printers screen involved.
            SizedBox(
              width: double.infinity,
              child: DsPrintAddPrinterButton(
                onPrinterAdded: (printer) {
                  _show('Added ${_describe(printer)} — now the active printer.');
                  _refresh();
                },
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _openPrinters,
              icon: const Icon(Icons.list),
              label: const Text('Manage printers  ·  DsPrint.selectDevice'),
            ),
            const _SectionTitle('Printing'),
            FilledButton.icon(
              onPressed: _previewAndPrint,
              icon: const Icon(Icons.receipt_long),
              label: const Text('Preview & print  ·  DsPrint.url'),
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: _printing ? null : _printSilently,
              icon: _printing
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.bolt),
              label: const Text('Print silently  ·  DsPrint.printUrlSilently'),
            ),
            const SizedBox(height: 24),
            Text('Invoice', style: theme.textTheme.labelLarge),
            const SizedBox(height: 4),
            const SelectableText(
              invoiceUrl,
              textDirection: TextDirection.ltr,
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 28, bottom: 8),
      child: Text(text, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}
