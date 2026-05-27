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
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(Radii.xxl),
          border: Border.all(color: AppColors.bgStroke),
          boxShadow: const [BoxShadow(blurRadius: 24, color: Colors.black54, offset: Offset(0, 8))],
        ),
        padding: padding,
        child: child,
      ),
    );
  }
}
