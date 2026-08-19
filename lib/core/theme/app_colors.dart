import 'package:flutter/material.dart';

/// Guardian AI color tokens extracted from Stitch DESIGN.md.
abstract final class AppColors {
  // Surfaces
  static const Color surface = Color(0xFF0B1326);
  static const Color surfaceDim = Color(0xFF0B1326);
  static const Color surfaceBright = Color(0xFF31394D);
  static const Color surfaceContainerLowest = Color(0xFF060E20);
  static const Color surfaceContainerLow = Color(0xFF131B2E);
  static const Color surfaceContainer = Color(0xFF171F33);
  static const Color surfaceContainerHigh = Color(0xFF222A3D);
  static const Color surfaceContainerHighest = Color(0xFF2D3449);
  static const Color surfaceVariant = Color(0xFF2D3449);
  static const Color background = Color(0xFF0B1326);
  static const Color onBackground = Color(0xFFDAE2FD);
  static const Color onSurface = Color(0xFFDAE2FD);
  static const Color onSurfaceVariant = Color(0xFFE3BDC5);
  static const Color inverseSurface = Color(0xFFDAE2FD);
  static const Color inverseOnSurface = Color(0xFF283044);

  // Brand
  static const Color primary = Color(0xFFFFB1C5);
  static const Color primaryPulse = Color(0xFFFF2E88);
  static const Color onPrimary = Color(0xFF650030);
  static const Color primaryContainer = Color(0xFFFF4A90);
  static const Color onPrimaryContainer = Color(0xFF590029);
  static const Color inversePrimary = Color(0xFFBA005D);
  static const Color surfaceTint = Color(0xFFFFB1C5);
  static const Color primaryFixed = Color(0xFFFFD9E1);
  static const Color primaryFixedDim = Color(0xFFFFB1C5);
  static const Color onPrimaryFixed = Color(0xFF3F001B);
  static const Color onPrimaryFixedVariant = Color(0xFF8E0046);

  static const Color secondary = Color(0xFFFFB0CD);
  static const Color onSecondary = Color(0xFF640039);
  static const Color secondaryContainer = Color(0xFFAA0266);
  static const Color onSecondaryContainer = Color(0xFFFFBAD3);
  static const Color secondaryFixed = Color(0xFFFFD9E4);
  static const Color secondaryFixedDim = Color(0xFFFFB0CD);
  static const Color onSecondaryFixed = Color(0xFF3E0022);
  static const Color onSecondaryFixedVariant = Color(0xFF8C0053);

  static const Color tertiary = Color(0xFFDDB7FF);
  static const Color onTertiary = Color(0xFF490080);
  static const Color tertiaryContainer = Color(0xFFB76DFF);
  static const Color onTertiaryContainer = Color(0xFF400071);
  static const Color tertiaryFixed = Color(0xFFF0DBFF);
  static const Color tertiaryFixedDim = Color(0xFFDDB7FF);
  static const Color onTertiaryFixed = Color(0xFF2C0051);
  static const Color onTertiaryFixedVariant = Color(0xFF6900B3);
  static const Color auraGlow = Color(0xFFA855F7);

  // System
  static const Color error = Color(0xFFFFB4AB);
  static const Color onError = Color(0xFF690005);
  static const Color errorContainer = Color(0xFF93000A);
  static const Color onErrorContainer = Color(0xFFFFDAD6);
  static const Color outline = Color(0xFFAA8890);
  static const Color outlineVariant = Color(0xFF5B3F46);

  // Semantic accents
  static const Color success = Color(0xFF4ADE80);
  static const Color successContainer = Color(0xFF14532D);
  static const Color onSuccessContainer = Color(0xFF86EFAC);
  static const Color warning = Color(0xFFFBBF24);
  static const Color info = Color(0xFF60A5FA);
  static const Color police = Color(0xFF3B82F6);
  static const Color hospital = Color(0xFFEF4444);
  static const Color glassWhite = Color(0x1AFFFFFF);
  static const Color glassBorder = Color(0x1AFFFFFF);
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
  static const Color online = Color(0xFF22C55E);

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFFFF2E88), Color(0xFFA855F7)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient pulseGradient = LinearGradient(
    colors: [Color(0xFFFF4A90), Color(0xFFFF2E88)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient meshGradient = LinearGradient(
    colors: [
      Color(0x26FF2E88),
      Color(0x000B1326),
      Color(0x26A855F7),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
