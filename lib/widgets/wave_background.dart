import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../theme/app_theme.dart';

/// Color tokens used exclusively by [WaveBackground]. Kept separate from
/// the public [AppColors] palette because they are not intended for general
/// UI consumption — they only make sense in the layered backdrop.
class _WavePalette {
  _WavePalette._();

  static const Color backgroundTopDark = Color(0xFF1A0A0E);
  static const Color backgroundBottomDark = Color(0xFF050203);
  static const Color backgroundTopLight = Color(0xFFFDF6F6);
  static const Color backgroundBottomLight = Color(0xFFF1DEDF);

  static const Color ambientDark = Color(0xFF2A0F15);
  static const Color ambientLight = Color(0xFFFEEDEE);

  static const Color ribbonADarkStart = Color(0xFF8B1E2C);
  static const Color ribbonADarkEnd = Color(0xFF3A0710);
  static const Color ribbonALightStart = Color(0xFFA02A3C);
  static const Color ribbonALightEnd = Color(0xFF6E0F1B);

  static const Color ribbonBDarkStart = Color(0xFFB83B57);
  static const Color ribbonBDarkEnd = Color(0xFF4F0F1A);
  static const Color ribbonBLightStart = Color(0xFFC24F66);
  static const Color ribbonBLightEnd = Color(0xFF8B1E2C);

  static const Color ribbonCDarkStart = Color(0xFF6D1620);
  static const Color ribbonCDarkEnd = Color(0xFF20060A);
  static const Color ribbonCLightStart = Color(0xFF7A1827);
  static const Color ribbonCLightEnd = Color(0xFF4D0A12);
}

/// Decorative background with subtle paper texture and layered waves.
class WaveBackground extends StatefulWidget {
  /// Creates a [WaveBackground].
  const WaveBackground({required this.child, super.key});

  /// Controls whether the wave animation is active.
  ///
  /// Full-screen overlays can set this to `false` to stop the ticker
  /// while the waves are hidden behind opaque content.
  static final ValueNotifier<bool> animationEnabled = ValueNotifier<bool>(true);

  /// The child rendered above the wave layers.
  final Widget child;

  @override
  State<WaveBackground> createState() => _WaveBackgroundState();

  /// Test hook exposing the internal accumulated wave-animation seconds so
  /// tests can verify the animation actually advances after a stop/restart
  /// cycle (e.g. when [animationEnabled] is toggled off and back on).
  @visibleForTesting
  static double debugElapsedSecondsFor(State<WaveBackground> state) =>
      (state as _WaveBackgroundState)._elapsedSeconds.value;
}

class _WaveBackgroundState extends State<WaveBackground>
    with SingleTickerProviderStateMixin {
  static const int _frameIntervalMicros = 33333;

  late final Ticker _ticker;
  final ValueNotifier<double> _elapsedSeconds = ValueNotifier<double>(0);
  int _lastFrameMicros = 0;
  double _baseSeconds = 0;
  bool _isTickerModeEnabled = true;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_handleTick);
    WaveBackground.animationEnabled.addListener(_syncTickerState);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _isTickerModeEnabled = TickerMode.valuesOf(context).enabled;
    _syncTickerState();
  }

  void _syncTickerState() {
    final shouldTick =
        _isTickerModeEnabled && WaveBackground.animationEnabled.value;
    if (shouldTick) {
      if (!_ticker.isActive) {
        // Flutter resets Ticker.elapsed to 0 on restart, so we must also
        // reset our frame-throttle cursor — otherwise the stale (large)
        // value causes _handleTick to short-circuit forever. Fold the
        // previously-accumulated seconds into _baseSeconds so the waves
        // resume from where they paused instead of snapping back.
        _baseSeconds = _elapsedSeconds.value;
        _lastFrameMicros = 0;
        _ticker.start();
      }
    } else if (_ticker.isActive) {
      _ticker.stop();
    }
  }

  void _handleTick(Duration elapsed) {
    final elapsedMicros = elapsed.inMicroseconds;
    if (elapsedMicros - _lastFrameMicros < _frameIntervalMicros) {
      return;
    }

    _lastFrameMicros = elapsedMicros;
    _elapsedSeconds.value =
        _baseSeconds + (elapsedMicros / Duration.microsecondsPerSecond) / 2;
  }

  @override
  void dispose() {
    WaveBackground.animationEnabled.removeListener(_syncTickerState);
    _ticker.dispose();
    _elapsedSeconds.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;
    final backgroundGradientColors = isDark
        ? [_WavePalette.backgroundTopDark, _WavePalette.backgroundBottomDark]
        : [_WavePalette.backgroundTopLight, _WavePalette.backgroundBottomLight];

    return Theme(
      data: theme.copyWith(scaffoldBackgroundColor: Colors.transparent),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: backgroundGradientColors,
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            RepaintBoundary(
              child: CustomPaint(
                painter: _BackdropGradientPainter(
                  colorScheme: colorScheme,
                  animationTime: _elapsedSeconds,
                ),
              ),
            ),
            RepaintBoundary(
              child: CustomPaint(
                isComplex: true,
                willChange: true,
                painter: _WaveBackgroundPainter(
                  colorScheme: colorScheme,
                  animationTime: _elapsedSeconds,
                ),
              ),
            ),
            RepaintBoundary(
              child: CustomPaint(
                painter: _FloatingOrbsPainter(
                  colorScheme: colorScheme,
                  time: _elapsedSeconds,
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: ColoredBox(color: colorScheme.surface.withAlpha(200)),
              ),
            ),
            widget.child,
          ],
        ),
      ),
    );
  }
}

class _BackdropGradientPainter extends CustomPainter {
  _BackdropGradientPainter({
    required this.colorScheme,
    required this.animationTime,
  }) : super(repaint: animationTime);

  final ColorScheme colorScheme;
  final ValueNotifier<double> animationTime;

  Size? _cachedSweepSize;
  Paint? _cachedSweepPaint;
  final Paint _glowPaint = Paint();

  Paint _sweepPaintFor(Size size) {
    final cached = _cachedSweepPaint;
    if (cached != null && _cachedSweepSize == size) {
      return cached;
    }
    final isDark = colorScheme.brightness == Brightness.dark;
    final paint = Paint()
      ..shader = LinearGradient(
        begin: const Alignment(-1, -0.9),
        end: const Alignment(1, 0.9),
        colors: [
          colorScheme.primary.withAlpha(isDark ? 34 : 28),
          colorScheme.tertiary.withAlpha(isDark ? 20 : 14),
          colorScheme.secondary.withAlpha(isDark ? 30 : 24),
        ],
        stops: const [0.05, 0.48, 0.95],
      ).createShader(Offset.zero & size);
    _cachedSweepSize = size;
    _cachedSweepPaint = paint;
    return paint;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final isDark = colorScheme.brightness == Brightness.dark;
    final t = animationTime.value;
    final rect = Offset.zero & size;

    canvas.drawRect(rect, _sweepPaintFor(size));

    _drawMovingGlow(
      canvas: canvas,
      rect: rect,
      t: t,
      frequency: 0.05,
      phase: 0.2,
      baseX: -0.72,
      baseY: -0.76,
      orbitX: 0.14,
      orbitY: 0.1,
      radius: 0.95,
      color: colorScheme.secondary,
      alpha: isDark ? 34 : 28,
    );
    _drawMovingGlow(
      canvas: canvas,
      rect: rect,
      t: t,
      frequency: 0.073,
      phase: 1.1,
      baseX: 0.78,
      baseY: 0.82,
      orbitX: 0.16,
      orbitY: 0.12,
      radius: 1.02,
      color: colorScheme.primary,
      alpha: isDark ? 28 : 22,
    );
    _drawMovingGlow(
      canvas: canvas,
      rect: rect,
      t: t,
      frequency: 0.061,
      phase: 2.4,
      baseX: 0.1,
      baseY: -0.25,
      orbitX: 0.2,
      orbitY: 0.14,
      radius: 0.86,
      color: colorScheme.tertiary,
      alpha: isDark ? 24 : 18,
    );
    _drawMovingGlow(
      canvas: canvas,
      rect: rect,
      t: t,
      frequency: 0.089,
      phase: 3.0,
      baseX: -0.12,
      baseY: 0.72,
      orbitX: 0.12,
      orbitY: 0.1,
      radius: 0.78,
      color: colorScheme.secondary,
      alpha: isDark ? 18 : 14,
    );
  }

  void _drawMovingGlow({
    required Canvas canvas,
    required Rect rect,
    required double t,
    required double frequency,
    required double phase,
    required double baseX,
    required double baseY,
    required double orbitX,
    required double orbitY,
    required double radius,
    required Color color,
    required int alpha,
  }) {
    final angle = (t * math.pi * 2 * frequency) + phase;
    final center = Alignment(
      baseX + (math.cos(angle) * orbitX),
      baseY + (math.sin(angle) * orbitY),
    );
    _glowPaint.shader = RadialGradient(
      center: center,
      radius: radius,
      colors: [color.withAlpha(alpha), color.withAlpha(0)],
    ).createShader(rect);
    canvas.drawRect(rect, _glowPaint);
  }

  @override
  bool shouldRepaint(covariant _BackdropGradientPainter oldDelegate) {
    return oldDelegate.colorScheme != colorScheme ||
        oldDelegate.animationTime != animationTime;
  }
}

class _WaveBackgroundPainter extends CustomPainter {
  static const double _baseAngularVelocity = 0.52;
  static const int _maxSamples = 60;

  static const List<_RibbonConfig> _ribbons = [
    _RibbonConfig(0.04, 24, 84, 1.20, 0.70, 0.72, 11, 0),
    _RibbonConfig(0.11, 20, 60, 1.48, 5.10, 0.65, 8, 1),
    _RibbonConfig(0.17, 26, 72, 1.32, 3.40, 0.88, 10, 2),
    _RibbonConfig(0.24, 18, 56, 1.55, 1.20, 0.78, 7, 0),
    _RibbonConfig(0.30, 30, 78, 1.42, 1.85, 1.00, 9, 1),
    _RibbonConfig(0.37, 22, 64, 1.18, 4.00, 1.10, 8, 2),
    _RibbonConfig(0.44, 28, 70, 1.28, 2.30, 0.82, 9, 0),
    _RibbonConfig(0.50, 20, 58, 1.52, 5.50, 1.25, 7, 1),
    _RibbonConfig(0.57, 26, 74, 1.10, 0.40, 0.70, 10, 2),
    _RibbonConfig(0.63, 22, 66, 1.38, 3.80, 1.18, 8, 0),
    _RibbonConfig(0.70, 18, 54, 1.60, 2.00, 0.92, 7, 1),
    _RibbonConfig(0.76, 28, 76, 1.22, 4.70, 1.05, 9, 2),
    _RibbonConfig(0.83, 24, 68, 1.35, 1.50, 0.85, 9, 0),
    _RibbonConfig(0.90, 20, 62, 1.45, 5.80, 1.32, 8, 1),
    _RibbonConfig(0.96, 28, 64, 1.10, 2.65, 1.42, 8, 2),
  ];

  _WaveBackgroundPainter({
    required this.colorScheme,
    required this.animationTime,
  }) : super(repaint: animationTime);

  final ColorScheme colorScheme;
  final ValueNotifier<double> animationTime;

  Size? _cachedAmbientSize;
  Brightness? _cachedAmbientBrightness;
  Paint? _cachedAmbientPaint;

  Brightness? _cachedPaletteBrightness;
  List<_RibbonPalette> _cachedPalettes = const [];

  final Paint _glowPaint = Paint();
  final Paint _fillPaint = Paint();
  final Path _ribbonPath = Path();
  final Float64List _yBuf = Float64List(_maxSamples + 1);

  Paint _ambientPaintFor(Size size, bool isDark) {
    final cached = _cachedAmbientPaint;
    final brightness = isDark ? Brightness.dark : Brightness.light;
    if (cached != null &&
        _cachedAmbientSize == size &&
        _cachedAmbientBrightness == brightness) {
      return cached;
    }
    final ambientColors = isDark
        ? [_WavePalette.ambientDark, AppColors.darkSurface]
        : [_WavePalette.ambientLight, AppColors.lightSurface];
    final paint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0, -0.25),
        radius: 1.2,
        colors: ambientColors,
      ).createShader(Offset.zero & size);
    _cachedAmbientSize = size;
    _cachedAmbientBrightness = brightness;
    _cachedAmbientPaint = paint;
    return paint;
  }

  List<_RibbonPalette> _palettesFor(bool isDark) {
    final brightness = isDark ? Brightness.dark : Brightness.light;
    if (_cachedPaletteBrightness == brightness && _cachedPalettes.isNotEmpty) {
      return _cachedPalettes;
    }
    final start0 = isDark
        ? _WavePalette.ribbonADarkStart
        : _WavePalette.ribbonALightStart;
    final end0 = isDark
        ? _WavePalette.ribbonADarkEnd
        : _WavePalette.ribbonALightEnd;
    final start1 = isDark
        ? _WavePalette.ribbonBDarkStart
        : _WavePalette.ribbonBLightStart;
    final end1 = isDark
        ? _WavePalette.ribbonBDarkEnd
        : _WavePalette.ribbonBLightEnd;
    final start2 = isDark
        ? _WavePalette.ribbonCDarkStart
        : _WavePalette.ribbonCLightStart;
    final end2 = isDark
        ? _WavePalette.ribbonCDarkEnd
        : _WavePalette.ribbonCLightEnd;
    final palettes = <_RibbonPalette>[
      _RibbonPalette.from(start0, end0),
      _RibbonPalette.from(start1, end1),
      _RibbonPalette.from(start2, end2),
    ];
    _cachedPaletteBrightness = brightness;
    _cachedPalettes = palettes;
    return palettes;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final isDark = colorScheme.brightness == Brightness.dark;
    canvas.drawRect(Offset.zero & size, _ambientPaintFor(size, isDark));

    final t = animationTime.value;
    final palettes = _palettesFor(isDark);
    final clampedWidth = size.width.clamp(320.0, 1440.0);
    final samples = (clampedWidth / 24).round().clamp(24, _maxSamples);

    for (final config in _ribbons) {
      _drawRibbon(
        canvas,
        size,
        samples,
        t,
        config,
        palettes[config.colorIndex],
      );
    }
  }

  void _drawRibbon(
    Canvas canvas,
    Size size,
    int samples,
    double t,
    _RibbonConfig c,
    _RibbonPalette palette,
  ) {
    final centerY = size.height * c.centerYFactor;
    final animatedPhase =
        c.phase + (t * _baseAngularVelocity * c.motionMultiplier);

    _buildRibbonPath(
      size: size,
      samples: samples,
      centerY: centerY,
      amplitude: c.amplitude,
      thickness: c.thickness,
      frequency: c.frequency,
      phase: animatedPhase,
    );

    final shaderBounds = Rect.fromLTWH(
      0,
      centerY - c.thickness,
      size.width,
      c.thickness * 2.3,
    );
    const edgeFadeStops = <double>[0, 0.1, 0.9, 1];

    _glowPaint
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: <Color>[
          palette.glowClear,
          palette.glow,
          palette.glow,
          palette.glowClear,
        ],
        stops: edgeFadeStops,
      ).createShader(shaderBounds)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, c.glowSigma);
    canvas.drawPath(_ribbonPath, _glowPaint);

    _fillPaint
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: <Color>[
          palette.startClear,
          palette.start,
          palette.end,
          palette.endClear,
        ],
        stops: edgeFadeStops,
      ).createShader(shaderBounds)
      ..maskFilter = null;
    canvas.drawPath(_ribbonPath, _fillPaint);
  }

  void _buildRibbonPath({
    required Size size,
    required int samples,
    required double centerY,
    required double amplitude,
    required double thickness,
    required double frequency,
    required double phase,
  }) {
    final halfThickness = thickness / 2;
    final width = size.width;
    final inv = 1.0 / samples;
    final twoPiFreq = math.pi * 2 * frequency;
    final twoPiDriftFreq = math.pi * 2 * frequency * 0.5;
    final driftPhase = phase * 0.6;
    final driftAmplitude = amplitude * 0.32;

    for (var i = 0; i <= samples; i++) {
      final tFrac = i * inv;
      final y =
          centerY +
          (math.sin((tFrac * twoPiFreq) + phase) * amplitude) +
          (math.sin((tFrac * twoPiDriftFreq) + driftPhase) * driftAmplitude);
      _yBuf[i] = y;
    }

    final path = _ribbonPath..reset();
    path.moveTo(0, _yBuf[0] - halfThickness);
    for (var i = 1; i <= samples; i++) {
      path.lineTo(width * i * inv, _yBuf[i] - halfThickness);
    }
    for (var i = samples; i >= 0; i--) {
      path.lineTo(width * i * inv, _yBuf[i] + halfThickness);
    }
    path.close();
  }

  @override
  bool shouldRepaint(covariant _WaveBackgroundPainter oldDelegate) {
    return oldDelegate.colorScheme != colorScheme ||
        oldDelegate.animationTime != animationTime;
  }
}

class _RibbonConfig {
  const _RibbonConfig(
    this.centerYFactor,
    this.amplitude,
    this.thickness,
    this.frequency,
    this.phase,
    this.motionMultiplier,
    this.glowSigma,
    this.colorIndex,
  );

  final double centerYFactor;
  final double amplitude;
  final double thickness;
  final double frequency;
  final double phase;
  final double motionMultiplier;
  final double glowSigma;
  final int colorIndex;
}

class _RibbonPalette {
  const _RibbonPalette({
    required this.start,
    required this.end,
    required this.startClear,
    required this.endClear,
    required this.glow,
    required this.glowClear,
  });

  factory _RibbonPalette.from(Color start, Color end) {
    final glowAlpha = end.computeLuminance() < 0.18 ? 30 : 72;
    return _RibbonPalette(
      start: start,
      end: end,
      startClear: start.withAlpha(0),
      endClear: end.withAlpha(0),
      glow: end.withAlpha(glowAlpha),
      glowClear: end.withAlpha(0),
    );
  }

  final Color start;
  final Color end;
  final Color startClear;
  final Color endClear;
  final Color glow;
  final Color glowClear;
}

class _FloatingOrbsPainter extends CustomPainter {
  _FloatingOrbsPainter({required this.colorScheme, required this.time})
    : super(repaint: time);

  final ColorScheme colorScheme;
  final ValueNotifier<double> time;

  static const _orbs = [
    _Orb(
      freqX: 0.018,
      freqY: 0.014,
      phaseX: 0.0,
      phaseY: 1.2,
      baseX: 0.25,
      baseY: 0.18,
      radiusX: 0.30,
      radiusY: 0.22,
      size: 0.20,
      coreAlpha: 70,
      glowAlpha: 65,
    ),
    _Orb(
      freqX: 0.021,
      freqY: 0.015,
      phaseX: 2.1,
      phaseY: 0.7,
      baseX: 0.75,
      baseY: 0.35,
      radiusX: 0.25,
      radiusY: 0.28,
      size: 0.16,
      coreAlpha: 70,
      glowAlpha: 55,
    ),
    _Orb(
      freqX: 0.014,
      freqY: 0.022,
      phaseX: 4.0,
      phaseY: 2.5,
      baseX: 0.50,
      baseY: 0.72,
      radiusX: 0.35,
      radiusY: 0.18,
      size: 0.24,
      coreAlpha: 70,
      glowAlpha: 50,
    ),
  ];

  final Paint _orbPaint = Paint();

  @override
  void paint(Canvas canvas, Size size) {
    final t = time.value;
    final color = colorScheme.onSurface;
    final width = size.width;
    final height = size.height;
    final shortestSide = size.shortestSide;

    for (final orb in _orbs) {
      final cx =
          width *
          (orb.baseX +
              math.sin(t * math.pi * 2 * orb.freqX + orb.phaseX) * orb.radiusX);
      final cy =
          height *
          (orb.baseY +
              math.sin(t * math.pi * 2 * orb.freqY + orb.phaseY) * orb.radiusY);
      final r = shortestSide * orb.size;
      final outerR = r * 3;
      final center = Offset(cx, cy);

      _orbPaint.shader = RadialGradient(
        colors: [
          color.withAlpha(orb.coreAlpha),
          color.withAlpha(orb.coreAlpha ~/ 2),
          color.withAlpha(orb.glowAlpha ~/ 3),
          color.withAlpha(0),
        ],
        stops: const [0.0, 0.12, 0.45, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: outerR));
      canvas.drawCircle(center, outerR, _orbPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _FloatingOrbsPainter old) =>
      old.colorScheme != colorScheme || old.time != time;
}

class _Orb {
  const _Orb({
    required this.freqX,
    required this.freqY,
    required this.phaseX,
    required this.phaseY,
    required this.baseX,
    required this.baseY,
    required this.radiusX,
    required this.radiusY,
    required this.size,
    required this.coreAlpha,
    required this.glowAlpha,
  });

  final double freqX, freqY, phaseX, phaseY;
  final double baseX, baseY, radiusX, radiusY;
  final double size;
  final int coreAlpha, glowAlpha;
}
