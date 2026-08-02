import 'package:flutter/material.dart';
import '../../models/clinical_reports.dart';
import '../../theme/tokens.dart';

class GenusAbundanceBar extends StatelessWidget {
  const GenusAbundanceBar({super.key, required this.items});

  final List<TaxonAbundance> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const Text('Genus 데이터가 없습니다');
    final max = items.map((item) => item.value).reduce((a, b) => a > b ? a : b);
    return Column(
      children: items
          .map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                            child: Text(item.name,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: context.wellness.textPrimary,
                                    fontStyle: FontStyle.italic))),
                        const SizedBox(width: 8),
                        Text('${item.value.toStringAsFixed(1)}%',
                            style: TextStyle(
                                color: context.wellness.textSecondary)),
                      ],
                    ),
                    const SizedBox(height: 5),
                    LinearProgressIndicator(
                      value: max == 0 ? 0 : item.value / max,
                      minHeight: 8,
                      borderRadius: WellnessRadius.chip,
                      color: context.wellness.primary,
                      backgroundColor: context.wellness.bgSubtle,
                    ),
                  ],
                ),
              ))
          .toList(growable: false),
    );
  }
}
