import 'package:flutter/material.dart';
import '../../../theme/tokens.dart';

class ProBloodTable extends StatelessWidget {
  const ProBloodTable({super.key, required this.rows});

  final List<Map<String, dynamic>> rows;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingTextStyle: TextStyle(
            color: context.wellness.textPrimary, fontWeight: FontWeight.w700),
        dataTextStyle:
            TextStyle(color: context.wellness.textSecondary, fontSize: 12),
        columns: const [
          DataColumn(label: Text('항목')),
          DataColumn(label: Text('원본값')),
          DataColumn(label: Text('원본단위')),
          DataColumn(label: Text('정규화값')),
          DataColumn(label: Text('표준단위')),
        ],
        rows: rows
            .map((row) => DataRow(cells: [
                  DataCell(Text(row['code']?.toString() ?? '')),
                  DataCell(Text(row['sourceValue']?.toString() ?? '')),
                  DataCell(Text(row['sourceUnit']?.toString() ?? '')),
                  DataCell(Text(row['value']?.toString() ?? '')),
                  DataCell(Text(row['unit']?.toString() ?? '')),
                ]))
            .toList(growable: false),
      ),
    );
  }
}
