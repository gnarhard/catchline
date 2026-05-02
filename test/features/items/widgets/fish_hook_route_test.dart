import 'package:catchline/features/items/widgets/fish_hook_route.dart';
import 'package:flutter/animation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('buildCatchTween', () {
    late AnimationController controller;
    late Animation<double> animation;

    setUp(() {
      controller = AnimationController(
        vsync: const TestVSync(),
        duration: const Duration(milliseconds: 400),
      );
      animation = buildCatchTween().animate(controller);
    });

    tearDown(() {
      controller.dispose();
    });

    test('starts at zero offset', () {
      controller.value = 0;
      expect(animation.value, closeTo(0, 0.001));
    });

    test('ends at zero offset (the page returns to its rest position)', () {
      controller.value = 1;
      expect(animation.value, closeTo(0, 0.001));
    });

    test('first phase (yank-down) ends at the positive peak around t=0.15', () {
      // Phase 1 spans 0 → 28 with weight 15 of 100.
      controller.value = 0.15;
      expect(animation.value, closeTo(28, 0.5));
    });

    test('second phase (yank-up) ends at the negative peak around t=0.55', () {
      // Phase 2 spans 28 → -18 with weight 40, ending at t = 0.55.
      controller.value = 0.55;
      expect(animation.value, closeTo(-18, 0.5));
    });

    test('the page is briefly pushed *down* during the first phase', () {
      // Anywhere in 0 < t < 0.15 the offset must be positive (down).
      controller.value = 0.075;
      expect(animation.value, greaterThan(0));
    });

    test('the page is pulled *up* during the second phase', () {
      // Anywhere in 0.30 < t < 0.55 the offset crosses zero on its way up.
      controller.value = 0.50;
      expect(animation.value, lessThan(0));
    });

    test(
      'the offset peaks (down) are bounded — sanity check on amplitudes',
      () {
        // Sweep the whole curve and confirm bounds.
        double maxDown = 0;
        double maxUp = 0;
        for (var i = 0; i <= 100; i++) {
          controller.value = i / 100;
          final v = animation.value;
          if (v > maxDown) maxDown = v;
          if (v < maxUp) maxUp = v;
        }
        // Down peak is the explicit endpoint of phase 1.
        expect(maxDown, closeTo(28, 0.5));
        // Up peak is at least the explicit phase-2 endpoint; allow extra room
        // because Curves.easeOutBack overshoots slightly past -18.
        expect(maxUp, lessThanOrEqualTo(-18));
        expect(maxUp, greaterThan(-30));
      },
    );
  });
}
