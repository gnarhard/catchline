import 'package:catchline/features/home/home_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('appContentHorizontalInset', () {
    test('returns zero when the screen is narrower than the max content', () {
      expect(appContentHorizontalInset(320), 0);
      expect(appContentHorizontalInset(800), 0);
      expect(appContentHorizontalInset(kMaxContentWidth - 1), 0);
    });

    test('returns zero when the screen exactly matches the max content', () {
      expect(appContentHorizontalInset(kMaxContentWidth), 0);
    });

    test('returns half the overflow when the screen is wider', () {
      expect(appContentHorizontalInset(kMaxContentWidth + 200), 100);
      expect(appContentHorizontalInset(2000), (2000 - kMaxContentWidth) / 2);
    });
  });

  group('buildBottomNavigationShadow', () {
    test('uses a darker shadow in dark mode than light mode', () {
      final dark = buildBottomNavigationShadow(Brightness.dark);
      final light = buildBottomNavigationShadow(Brightness.light);
      expect(dark.color.a, greaterThan(light.color.a));
    });

    test('rises slightly above the bar with a soft blur', () {
      final shadow = buildBottomNavigationShadow(Brightness.dark);
      expect(shadow.offset, const Offset(0, -2));
      expect(shadow.blurRadius, 16);
    });
  });

  group('nav-bar layout constants', () {
    test('content height stays compact', () {
      expect(kNavBarHeight, lessThanOrEqualTo(52));
    });

    test('label padding has no horizontal component', () {
      expect(kNavBarLabelPadding.left, 0);
      expect(kNavBarLabelPadding.right, 0);
    });

    test('compact width threshold is below the max content width', () {
      expect(kNavBarCompactWidth, lessThan(kMaxContentWidth));
    });
  });
}
