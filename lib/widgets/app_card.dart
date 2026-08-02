import 'package:flutter/material.dart';
import '../theme/tokens.dart';

class AppCard extends StatelessWidget {
  const AppCard({super.key, this.child, this.padding = const EdgeInsets.all(16), this.onTap});
  final Widget? child;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: context.wellness.bgCard,
          borderRadius: BorderRadius.circular(Radii.xxl),
          border: Border.all(color: context.wellness.borderSubtle),
          boxShadow: WellnessShadows.soft,
        ),
        padding: padding,
        child: child,
      ),
    );
  }
}
