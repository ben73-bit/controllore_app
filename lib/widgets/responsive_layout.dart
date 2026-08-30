import 'package:flutter/material.dart';

/// Costanti e helper per il layout adattivo / responsive.
class ResponsiveLayout {
  static const double kMobileBreakpoint = 600;
  static const double kDesktopBreakpoint = 900;
  static const double kMaxContentWidth = 1200;
  static const double kMaxFormWidth = 560;

  /// Restituisce `true` se lo schermo è considerato desktop (≥ 900px).
  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= kDesktopBreakpoint;

  /// Restituisce `true` se lo schermo è considerato mobile (< 600px).
  static bool isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < kMobileBreakpoint;

  /// Avvolge [child] in un `Center` con `ConstrainedBox` a [maxWidth].
  static Widget constrainedWidth(
    Widget child, {
    double maxWidth = kMaxContentWidth,
  }) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }

  /// Costruisce un widget differente in base alla larghezza corrente.
  static Widget builder({
    required BuildContext context,
    required Widget Function(BuildContext context) mobile,
    Widget Function(BuildContext context)? tablet,
    required Widget Function(BuildContext context) desktop,
  }) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= kDesktopBreakpoint) return desktop(context);
    if (width >= kMobileBreakpoint && tablet != null) return tablet(context);
    return mobile(context);
  }
}
