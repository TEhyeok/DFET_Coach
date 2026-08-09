import 'package:flutter/material.dart';

import '../theme/d_fet_typography.dart';
import '../theme/tokens.dart';
import 'd_fet_axis_glyph.dart';
import 'd_fet_axis_icon.dart';

class DfetSignalItem {
  const DfetSignalItem({
    required this.axis,
    required this.label,
    required this.value,
    this.active = true,
    this.semanticLabel,
  });

  final DfetAxis axis;
  final String label;
  final String value;
  final bool active;
  final String? semanticLabel;
}

class DfetSignalRail extends StatelessWidget {
  const DfetSignalRail({
    super.key,
    required this.items,
    this.nodeSize,
  });

  final List<DfetSignalItem> items;
  final double? nodeSize;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final resolvedNodeSize = nodeSize ??
            (constraints.maxWidth < 300
                ? 46.0
                : constraints.maxWidth < 380
                    ? 52.0
                    : 58.0);
        final cellWidth = constraints.maxWidth / items.length;

        return Stack(
          children: [
            Positioned(
              top: resolvedNodeSize / 2 - 1,
              left: cellWidth / 2,
              right: cellWidth / 2,
              child: Container(
                height: 2,
                color: context.wellness.border,
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final item in items)
                  Expanded(
                    child: _SignalNode(
                      item: item,
                      size: resolvedNodeSize,
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _SignalNode extends StatelessWidget {
  const _SignalNode({required this.item, required this.size});

  final DfetSignalItem item;
  final double size;

  @override
  Widget build(BuildContext context) {
    final axisColor = DfetAxisPalette.color(context, item.axis);
    final foreground = item.active ? axisColor : context.wellness.textTertiary;

    return Semantics(
      container: true,
      label: item.semanticLabel ?? '${item.label} 축, ${item.value}',
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: item.active
                  ? context.wellness.bgCard
                  : context.wellness.bgSubtle,
              border: Border.all(
                color: foreground,
                width: item.active ? 2 : 1.5,
              ),
            ),
            child: DfetAxisAssetIcon(
              axis: item.axis,
              size: size * 0.58,
              active: item.active,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            item.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.wellness.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            item.value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: DfetTypography.dataStyle(
              color: foreground,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              height: 1.15,
            ),
          ),
        ],
      ),
    );
  }
}
