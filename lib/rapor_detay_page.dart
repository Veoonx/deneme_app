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
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(child: Text("Hata: $error"))
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: visibleColumns
                        .map((c) => DataColumn(label: Text(c)))
                        .toList(),
                    rows: rows
                        .map((r) => DataRow(
                              cells: visibleColumns
                                  .map((c) => DataCell(Text(r[c]?.toString() ?? "")))
                                  .toList(),
                            ))
                        .toList(),
                  ),
                ),
    );
  }
}
