import 'package:flutter/material.dart';

class RaporSonucPage extends StatelessWidget {
  final String title;
  final List<String> columns;
  final List<Map<String, dynamic>> rows;

  const RaporSonucPage({
    super.key,
    required this.title,
    required this.columns,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: const Center(child: Text("Kayıt bulunamadı.")),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Padding(
        padding: const EdgeInsets.all(8),
        child: Scrollbar(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SingleChildScrollView(
              child: DataTable(
                headingRowColor: WidgetStateColor.resolveWith(
                    (states) => Colors.grey[200]!),
                border: TableBorder.all(color: Colors.black12),
                columns: columns
                    .map((c) => DataColumn(
                          label: Text(
                            c,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ))
                    .toList(),
                rows: rows.map((r) {
                  return DataRow(
                    cells: columns.map((c) {
                      final v = r[c];
                      return DataCell(Text(v?.toString() ?? ""));
                    }).toList(),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
