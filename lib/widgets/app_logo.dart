import 'package:flutter/material.dart';

/// Maroon fish-on-hook brand mark.
///
/// Backed by the same artwork as the app icon and favicon, so usage anywhere
/// in the UI stays visually consistent with the launcher icon.
///
/// The default ([AppLogo]) uses the square master ([assets/branding/logo.png])
/// which renders nicely as a bounded 1:1 mark. Use [AppLogo.cropped] when you
/// want the artwork to fit the natural ~3:1 portrait aspect (e.g. as a tall
/// header or splash mark).
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 32, this.semanticLabel = 'Catchline'})
    : _asset = 'assets/branding/logo.png';

  const AppLogo.cropped({
    super.key,
    this.size = 64,
    this.semanticLabel = 'Catchline',
  }) : _asset = 'assets/branding/logo_cropped.png';

  final double size;
  final String semanticLabel;
  final String _asset;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      _asset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      semanticLabel: semanticLabel,
    );
  }
}
