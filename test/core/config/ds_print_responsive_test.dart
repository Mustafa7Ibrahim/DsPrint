import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ds_print/src/core/config/ds_print_responsive.dart';

void main() {
  Future<BuildContext> pumpWithSize(WidgetTester tester, Size size) async {
    late BuildContext capturedContext;
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(size: size),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Builder(
            builder: (context) {
              capturedContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    return capturedContext;
  }

  group('DsPrintResponsive.isTablet', () {
    testWidgets('shortestSide 549 is not tablet', (tester) async {
      final context = await pumpWithSize(tester, const Size(549, 900));
      expect(DsPrintResponsive.isTablet(context), isFalse);
    });

    testWidgets(
        'shortestSide 550 is tablet - exact boundary, mirrors Figma.dart:24',
        (tester) async {
      final context = await pumpWithSize(tester, const Size(550, 900));
      expect(DsPrintResponsive.isTablet(context), isTrue);
    });
  });

  group('DsPrintResponsive.captureWidth', () {
    testWidgets('390 on phone', (tester) async {
      final context = await pumpWithSize(tester, const Size(400, 800));
      expect(DsPrintResponsive.captureWidth(context), 390.0);
    });

    testWidgets('500 on tablet', (tester) async {
      final context = await pumpWithSize(tester, const Size(800, 1200));
      expect(DsPrintResponsive.captureWidth(context), 500.0);
    });
  });

  group('DsPrintResponsive.captureContainerWidth', () {
    testWidgets('null on phone', (tester) async {
      final context = await pumpWithSize(tester, const Size(400, 800));
      expect(DsPrintResponsive.captureContainerWidth(context), isNull);
    });

    testWidgets('350 on tablet', (tester) async {
      final context = await pumpWithSize(tester, const Size(800, 1200));
      expect(DsPrintResponsive.captureContainerWidth(context), 350.0);
    });
  });
}
