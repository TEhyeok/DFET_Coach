import 'package:flutter/material.dart';

class TrainerWidgetLabel extends StatelessWidget {
  const TrainerWidgetLabel({
    super.key,
    required this.label,
    required this.child,
    this.alignment = Alignment.topLeft,
  });

  final String label;
  final Widget child;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned.fill(
          child: IgnorePointer(
            child: Align(
              alignment: alignment,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.78),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.34),
                      width: 0.7,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 5,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 180),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 4),
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

extension TrainerWidgetLabelExtension on Widget {
  Widget trainerLabel(
    String label, {
    Alignment alignment = Alignment.topLeft,
  }) {
    return TrainerWidgetLabel(
      label: label,
      alignment: alignment,
      child: this,
    );
  }
}
