import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import '../utils/responsive_layout.dart';

Future<T?> showAdaptiveEntrySheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  final isIOS = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  if (!isIOS) {
    return showDialog<T>(
      context: context,
      builder: builder,
    );
  }

  return showCupertinoModalPopup<T>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.48),
    builder: (modalContext) {
      final mediaQuery = MediaQuery.of(modalContext);
      final isTablet = ResponsiveLayout.isTablet(modalContext);
      final maxWidth = isTablet ? 640.0 : mediaQuery.size.width;
      final maxHeight = mediaQuery.size.height * (isTablet ? 0.88 : 0.92);
      final radius = BorderRadius.vertical(
        top: const Radius.circular(24),
        bottom: Radius.circular(isTablet ? 24 : 0),
      );

      return AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom),
        child: Align(
          alignment: isTablet ? Alignment.center : Alignment.bottomCenter,
          child: Material(
            type: MaterialType.transparency,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: maxWidth,
                maxHeight: maxHeight,
              ),
              child: ClipRRect(
                borderRadius: radius,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.bgCard,
                    borderRadius: radius,
                    border:
                        Border.all(color: modalContext.wellness.borderSubtle),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 28,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 10),
                      Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: modalContext.wellness.textTertiary,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      Flexible(child: builder(modalContext)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class IOSActionRow extends StatelessWidget {
  const IOSActionRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onPressed,
    this.color = AppColors.brandPrimary,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onPressed;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onPressed,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.wellness.bgSubtle,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.wellness.borderSubtle),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: context.wellness.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: context.wellness.textSecondary,
                      fontSize: 12,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              CupertinoIcons.chevron_forward,
              color: context.wellness.textTertiary,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}
