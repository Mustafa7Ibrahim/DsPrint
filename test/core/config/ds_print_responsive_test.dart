import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ds_print/src/core/config/ds_print_responsive.dart';
import 'package:ds_print/src/data/services/capture_height_resolver.dart';

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
    testWidgets('null on phone — the capture is as wide as the screen',
        (tester) async {
      final context = await pumpWithSize(tester, const Size(400, 800));
      expect(DsPrintResponsive.captureWidth(context), isNull);
    });

    testWidgets('350 on tablet', (tester) async {
      final context = await pumpWithSize(tester, const Size(800, 1200));
      expect(DsPrintResponsive.captureWidth(context), 350.0);
    });

    testWidgets(
        'a tablet capture magnifies the page by roughly 1.8x on paper',
        (tester) async {
      // Regression guard on printed text size. The printer rescales to a fixed
      // dot count, so magnification is paperDots / laid-out content width —
      // widening the capture silently shrinks the print.
      final context = await pumpWithSize(tester, const Size(800, 1200));
      final contentWidth = DsPrintResponsive.captureWidth(context)! -
          DsPrintResponsive.capturePadding.horizontal;

      expect(
        CaptureHeightResolver.defaultPaperDots / contentWidth,
        closeTo(1.83, 0.01),
      );
    });
  });

}
