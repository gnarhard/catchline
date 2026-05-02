import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A page route that animates its child sliding up from the bottom while a
/// fish hook on a fishing line "drags" it into place. Saving triggers a
/// catch-a-fish bounce (down → up → settle) before the route pops.
class FishHookPageRoute<T> extends PageRoute<T> {
  FishHookPageRoute({required this.builder});

  final WidgetBuilder builder;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool get opaque => false;

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 650);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 480);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return _FishHookHost(entryAnimation: animation, childBuilder: builder);
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return child;
  }
}

/// The bounce played on save: a quick yank down, an overshoot up, then a
/// soft settle. Public for unit tests.
@visibleForTesting
TweenSequence<double> buildCatchTween() {
  return TweenSequence<double>(<TweenSequenceItem<double>>[
    TweenSequenceItem<double>(
      tween: Tween<double>(
        begin: 0,
        end: 28,
      ).chain(CurveTween(curve: Curves.easeIn)),
      weight: 15,
    ),
    TweenSequenceItem<double>(
      tween: Tween<double>(
        begin: 28,
        end: -18,
      ).chain(CurveTween(curve: Curves.easeOut)),
      weight: 40,
    ),
    TweenSequenceItem<double>(
      tween: Tween<double>(
        begin: -18,
        end: 0,
      ).chain(CurveTween(curve: Curves.easeOutBack)),
      weight: 45,
    ),
  ]);
}

const Duration _kCatchDuration = Duration(milliseconds: 400);

/// Inherited scope exposing a "play the catch bounce" callback to descendants.
class FishHook extends InheritedWidget {
  const FishHook({super.key, required this.onCatch, required super.child});

  final Future<void> Function() onCatch;

  static FishHook? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<FishHook>();

  @override
  bool updateShouldNotify(covariant FishHook oldWidget) =>
      oldWidget.onCatch != onCatch;
}

class _FishHookHost extends StatefulWidget {
  const _FishHookHost({
    required this.entryAnimation,
    required this.childBuilder,
  });

  final Animation<double> entryAnimation;
  final WidgetBuilder childBuilder;

  @override
  State<_FishHookHost> createState() => _FishHookHostState();
}

class _FishHookHostState extends State<_FishHookHost>
    with SingleTickerProviderStateMixin {
  late final AnimationController _catchController;
  late final Animation<double> _catchOffset;

  @override
  void initState() {
    super.initState();
    _catchController = AnimationController(
      vsync: this,
      duration: _kCatchDuration,
    );
    _catchOffset = buildCatchTween().animate(_catchController);
  }

  @override
  void dispose() {
    _catchController.dispose();
    super.dispose();
  }

  Future<void> _playCatch() async {
    if (!mounted) return;
    _catchController.value = 0;
    await _catchController.forward();
  }

  @override
  Widget build(BuildContext context) {
    return FishHook(
      onCatch: _playCatch,
      child: AnimatedBuilder(
        animation: Listenable.merge([widget.entryAnimation, _catchController]),
        child: Builder(builder: widget.childBuilder),
        builder: (context, child) {
          return _FishHookVisual(
            entryProgress: widget.entryAnimation.value,
            catchOffset: _catchOffset.value,
            child: child!,
          );
        },
      ),
    );
  }
}

class _FishHookVisual extends StatelessWidget {
  const _FishHookVisual({
    required this.entryProgress,
    required this.catchOffset,
    required this.child,
  });

  /// 0 = screen offscreen below; 1 = screen at rest.
  final double entryProgress;

  /// Vertical offset added by the catch bounce. Positive = down, negative = up.
  final double catchOffset;

  final Widget child;

  // Layout constants — tuned so a small portion of the fishing line is
  // always visible at rest, with enough hook above the screen to read as
  // "hooked into the top".
  static const double _topGap = 56;
  static const double _hookHeight = 76;
  static const double _hookOverlap = 28;
  // Top of the hook image relative to the page, at rest.
  static const double _hookTopAtRest = _topGap - _hookHeight + _hookOverlap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final viewport = MediaQuery.sizeOf(context);

    final entry = Curves.easeOutCubic.transform(entryProgress.clamp(0.0, 1.0));
    final entryOffsetY = (1 - entry) * viewport.height;
    final totalOffsetY = entryOffsetY + catchOffset;

    // Hook eye position in viewport coordinates (the line attaches here).
    final hookEyeYInViewport = _hookTopAtRest + totalOffsetY;
    final lineHeight = math.max(
      0.0,
      math.min(viewport.height, hookEyeYInViewport),
    );

    final lineColor = colorScheme.onSurface.withAlpha(180);
    // WaveBackground overrides scaffoldBackgroundColor to transparent at the
    // app root, so we use the color-scheme surface here for an opaque card.
    final backdropColor = colorScheme.surface;

    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [
        // Opaque page backdrop — hides the underlying list during the slide
        // and gives the rising card a solid look.
        Positioned.fill(child: ColoredBox(color: backdropColor)),
        // Fishing line dangling from the top of the viewport.
        if (lineHeight > 0)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: lineHeight,
            child: IgnorePointer(
              child: Center(child: Container(width: 1.5, color: lineColor)),
            ),
          ),
        // Page (with top padding so the hook has room) + hook image.
        // Both translate together so the hook stays "stuck" in the top edge.
        Transform.translate(
          offset: Offset(0, totalOffsetY),
          child: Stack(
            fit: StackFit.expand,
            clipBehavior: Clip.none,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: _topGap),
                child: child,
              ),
              // Subtle "hole" the hook is caught in, drawn just under the
              // screen edge so the hook curve appears to pierce it.
              Positioned(
                top: _topGap - 4,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: Center(
                    child: Container(
                      width: 22,
                      height: 7,
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(160),
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.onSurface.withAlpha(40),
                            blurRadius: 1,
                            spreadRadius: 0.5,
                            offset: const Offset(0, 0.5),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: _hookTopAtRest,
                left: 0,
                right: 0,
                height: _hookHeight,
                child: IgnorePointer(
                  child: Center(
                    child: Image.asset(
                      'assets/images/fish_hook.png',
                      height: _hookHeight,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
