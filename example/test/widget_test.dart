import 'package:ds_print_example/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('shows every entry point and no active printer yet',
      (tester) async {
    await tester.pumpWidget(const ExampleApp());
    await tester.pumpAndSettle();

    expect(find.text('None — add one below'), findsOneWidget);
    // The package's button, in Arabic by default.
    expect(find.text('اضافة طابعة'), findsOneWidget);
    expect(find.text('Preview & print  ·  DsPrint.url'), findsOneWidget);
    await tester.scrollUntilVisible(find.text(invoiceUrl), 200);
    expect(find.text(invoiceUrl), findsOneWidget);
  });

  testWidgets('the language toggle switches the package to English',
      (tester) async {
    await tester.pumpWidget(const ExampleApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();

    expect(find.text('Add Printer'), findsOneWidget);
  });

  testWidgets('a saved printer shows as the active one', (tester) async {
    SharedPreferences.setMockInitialValues({
      'printer-deviceId': '192.168.1.50',
      'printer-device-interface-type': 'Lan',
    });

    await tester.pumpWidget(const ExampleApp());
    await tester.pumpAndSettle();

    expect(find.text('LAN · 192.168.1.50'), findsOneWidget);
    expect(find.text('1 saved'), findsOneWidget);
  });
}
