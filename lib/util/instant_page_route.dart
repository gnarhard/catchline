import 'package:flutter/material.dart';

/// A [MaterialPageRoute] with no transition animation. The previous route is
/// offstaged in the same frame as the push, so transparent scaffolds don't
/// overlap during a (default 300 ms) slide.
class InstantPageRoute<T> extends MaterialPageRoute<T> {
  InstantPageRoute({required super.builder});

  @override
  Duration get transitionDuration => Duration.zero;

  @override
  Duration get reverseTransitionDuration => Duration.zero;
}
