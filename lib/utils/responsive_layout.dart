import 'package:flutter/widgets.dart';

class ResponsiveLayout {
  static const double tabletShortestSide = 700;
  static const double wideContentWidth = 900;
  static const double maxPageWidth = 1180;
  static const double maxFormWidth = 520;
  static const double maxSetupWidth = 760;

  static bool isTablet(BuildContext context) {
    return MediaQuery.sizeOf(context).shortestSide >= tabletShortestSide;
  }

  static bool isWide(BuildContext context) {
    return MediaQuery.sizeOf(context).width >= wideContentWidth;
  }

  static EdgeInsets pagePadding(BuildContext context) {
    return isTablet(context)
        ? const EdgeInsets.symmetric(horizontal: 32, vertical: 24)
        : const EdgeInsets.all(16);
  }

  static EdgeInsets compactPagePadding(BuildContext context) {
    return isTablet(context)
        ? const EdgeInsets.symmetric(horizontal: 24, vertical: 20)
        : const EdgeInsets.all(16);
  }
}

class ResponsiveConstrainedBox extends StatelessWidget {
  const ResponsiveConstrainedBox({
    super.key,
    required this.child,
    this.maxWidth = ResponsiveLayout.maxPageWidth,
    this.alignment = Alignment.topCenter,
  });

  final Widget child;
  final double maxWidth;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
