import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class RaporDetayPage extends StatefulWidget {
  final String title;
  final String centralUrl;
  final String username;
  final String storedProc;
  final Map<String, dynamic> parameters;

  const RaporDetayPage({
    super.key,
    required this.title,
    required this.centralUrl,
    required this.username,
    required this.storedProc,
    required this.parameters,
  });

  @override
  State<RaporDetayPage> createState() => _RaporDetayPageState();
}

class _RaporDetayPageState extends State<RaporDetayPage> {
  bool loading = true;
  String? error;
  List<String> columns = [];
  List<Map<String, dynamic>> rows = [];
  List<String> visibleColumns = [];

  int _currentPage = 1;
  final int _rowsPerPage = 15; // 🔹 her sayfada gösterilecek kayıt

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final limit = prefs.getInt('recordLimit') ?? 50;

      final uri = Uri.parse("${widget.centralUrl}/report/run");
      final body = jsonEncode({
        "Username": widget.username,
        "StoredProc": widget.storedProc,
        "Parameters": widget.parameters,
      });

      final res = await http.post(
        uri,
        headers: {"Content-Type": "application/json"},
        body: body,
      );

      final b = jsonDecode(res.body);
      if (b["success"] == true) {
        final List<String> cols = List<String>.from(b["columns"] ?? []);
        final List<dynamic> data = b["data"] ?? [];
        setState(() {
          columns = cols;
          visibleColumns = List.from(cols);
          rows = List<Map<String, dynamic>>.from(data);
          if (rows.length > limit) {
            rows = rows.take(limit).toList();
          }
          loading = false;
        });
      } else {
        setState(() {
          error = b["message"];
          loading = false;
        });
      }
    } catch (e) {
      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  void _showFilterSheet() async {
    await showModalBottomSheet(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setStateSheet) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Text("Görünecek Sütunlar",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                Expanded(
                  child: ListView(
                    children: columns.map((col) {
                      final visible = visibleColumns.contains(col);
                      return CheckboxListTile(
                        title: Text(col),
                        value: visible,
                        onChanged: (val) {
                          setStateSheet(() {
                            if (val == true) {
                              visibleColumns.add(col);
                            } else {
                              visibleColumns.remove(col);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Uygula"),
                ),
              ],
            ),
          );
        });
      },
    );
    setState(() {}); // refresh
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (error != null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: Center(child: Text("Hata: $error")),
      );
    }

    if (rows.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: const Center(child: Text("Kayıt bulunamadı.")),
      );
    }

    final totalPages =
        (rows.length / _rowsPerPage).ceil().clamp(1, double.infinity).toInt();
    final start = (_currentPage - 1) * _rowsPerPage;
    final end = (_currentPage * _rowsPerPage).clamp(0, rows.length);
    final visibleRows = rows.sublist(start, end);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_alt),
            tooltip: "Sütunları Filtrele",
            onPressed: _showFilterSheet,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            Expanded(
              child: Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Scrollbar(
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minWidth: MediaQuery.of(context).size.width,
                      ),
                      child: Scrollbar(
                        thumbVisibility: true,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.vertical,
                          child: DataTable(
                            headingRowColor: WidgetStateColor.resolveWith(
                                (states) => Colors.grey[200]!),
                            border: TableBorder.all(color: Colors.black12),
                            columns: visibleColumns
                                .map((c) => DataColumn(
                                      label: Text(
                                        c,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ))
                                .toList(),
                            rows: visibleRows.map((r) {
                              return DataRow(
                                color: WidgetStateProperty.resolveWith((states) {
                                  if (states.contains(WidgetState.hovered)) {
                                    return Colors.blue.withOpacity(0.05);
                                  }
                                  return Colors.white;
                                }),
                                cells: visibleColumns.map((c) {
                                  final v = r[c];
                                  return DataCell(Text(
                                    v?.toString() ?? "",
                                    style: const TextStyle(fontSize: 12.5),
                                  ));
                                }).toList(),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            _buildPagination(totalPages),
          ],
        ),
      ),
    );
  }

  Widget _buildPagination(int totalPages) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed:
              _currentPage > 1 ? () => setState(() => _currentPage--) : null,
        ),
        Text(
          "Sayfa $_currentPage / $totalPages",
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: _currentPage < totalPages
              ? () => setState(() => _currentPage++)
              : null,
        ),
      ],
    );
  }
}
