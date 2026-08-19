import 'package:flutter/material.dart';

import '../theme/spacing.dart';

/// Breakpoints and helpers for phones / tablets.
abstract final class Responsive {
  static const double phoneMax = 600;
  static const double tabletMax = 1024;

  static bool isPhone(BuildContext context) =>
      MediaQuery.sizeOf(context).width < phoneMax;

  static bool isTablet(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return w >= phoneMax && w < tabletMax;
  }

  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= tabletMax;

  static double horizontalPadding(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= tabletMax) return width * 0.18;
    if (width >= phoneMax) return AppSpacing.xxl;
    return AppSpacing.containerPadding;
  }

  static double contentMaxWidth(BuildContext context) {
    if (isDesktop(context)) return 720;
    if (isTablet(context)) return 600;
    return double.infinity;
  }

  static double scale(BuildContext context, double phone, {double? tablet}) {
    if (isTablet(context) || isDesktop(context)) return tablet ?? phone * 1.15;
    return phone;
  }
}

class ResponsivePadding extends StatelessWidget {
  const ResponsivePadding({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: Responsive.contentMaxWidth(context)),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: Responsive.horizontalPadding(context)),
          child: child,
        ),
      ),
    );
  }
}
