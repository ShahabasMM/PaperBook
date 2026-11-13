import 'package:flutter/material.dart';

/// A strict 4pt spacing scale. Every gap in the app comes from here.
abstract final class AppSpace {
  static const xxs = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 20.0;
  static const xl = 24.0;
  static const xxl = 32.0;
  static const xxxl = 40.0;
  static const huge = 56.0;

  /// Horizontal page gutter.
  static const gutter = 20.0;

  /// Maximum content width on tablets and foldables.
  static const maxContentWidth = 760.0;

  /// Standard bottom padding that clears the navigation bar.
  static const bottomSafe = 28.0;
}

/// Consistent corner radii across every surface.
abstract final class AppRadius {
  static const xs = 8.0;
  static const sm = 10.0;
  static const md = 14.0;
  static const lg = 18.0;
  static const xl = 24.0;
  static const sheet = 28.0;
  static const pill = 999.0;

  static const button = BorderRadius.all(Radius.circular(md));
  static const card = BorderRadius.all(Radius.circular(lg));
  static const chip = BorderRadius.all(Radius.circular(pill));
  static const sheetTop = BorderRadius.vertical(top: Radius.circular(sheet));
}

/// Consistent icon sizes.
abstract final class AppIconSize {
  static const xs = 14.0;
  static const sm = 18.0;
  static const md = 20.0;
  static const lg = 24.0;
  static const xl = 28.0;
}

/// Motion tokens — subtle, never bouncy.
abstract final class AppMotion {
  static const fast = Duration(milliseconds: 120);
  static const base = Duration(milliseconds: 220);
  static const slow = Duration(milliseconds: 360);
  static const page = Duration(milliseconds: 280);
  static const curve = Curves.easeOutCubic;
  static const emphasized = Curves.easeOutQuint;
}
