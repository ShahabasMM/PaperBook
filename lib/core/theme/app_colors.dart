import 'package:flutter/material.dart';

/// PaperBook brand palette.
///
/// The accent (`lime`) is intentionally restricted to primary actions,
/// active states and meaningful highlights.
abstract final class AppColors {
  // Brand spec — light.
  static const background = Color(0xFFF7F8F5);
  static const ink = Color(0xFF171717);
  static const inkSecondary = Color(0xFF777777);
  static const lime = Color(0xFFDFFF00);
  static const border = Color(0xFFE8EAE5);

  // Derived light surfaces.
  static const surface = Color(0xFFFFFFFF);
  static const surfaceMuted = Color(0xFFF0F2EC);
  static const inkTertiary = Color(0xFFA3A5A0);
  static const danger = Color(0xFFB42318);
  static const dangerSoft = Color(0xFFFDECEA);

  // Brand spec — dark.
  static const darkBackground = Color(0xFF101010);
  static const darkSurface = Color(0xFF1A1A1A);
  static const darkSurfaceMuted = Color(0xFF222222);
  static const darkBorder = Color(0xFF2A2A2A);
  static const darkInk = Color(0xFFF4F5F0);
  static const darkInkSecondary = Color(0xFF9A9C97);
  static const darkInkTertiary = Color(0xFF6A6C68);
  static const darkDanger = Color(0xFFFF8A80);
  static const darkDangerSoft = Color(0xFF2A1715);

  // Fixed dark palette for the home activity heatmap.
  static const heatBackground = Color(0xFF101010);
  static const heatBorder = Color(0xFF262B24);
  static const heatEmpty = Color(0xFF23281E);
  static const heatLevel1 = Color(0xFF3D5A2A);
  static const heatLevel2 = Color(0xFF5F8A2F);
  static const heatLevel3 = Color(0xFF8FBE36);
  static const heatLevel4 = lime;

  // Fixed on accent.
  static const onAccent = Color(0xFF171717);

  static Color of(BuildContext context) => ink;
}
