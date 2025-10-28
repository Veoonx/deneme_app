import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'rapor_detay_page.dart';

class RaporParametrePage extends StatefulWidget {
  final Map<String, dynamic> rapor;
  final String centralUrl;
  final String username;

  const RaporParametrePage({
    super.key,
    required this.rapor,
    required this.centralUrl,
    required this.username,
  });

  @override
  State<RaporParametrePage> createState() => _RaporParametrePageState();
}

class _RaporParametrePageState extends State<RaporParametrePage> {
  bool loading = true;
  String? error;

  late final String storedProc;

  final List<Map<String, String>> _paramDefs = [];
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, dynamic> _values = {};

  @override
  void initState() {
    super.initState();
    storedProc = (widget.rapor["storedProc"] ?? "").toString();
    _loadParams();
  }

  Future<void> _loadParams() async {
    if (storedProc.isEmpty) {
      setState(() {
        loading = false;
        error = "StoredProc bulunamadı.";
      });
      return;
    }

    try {
      final uri = Uri.parse(
          "${widget.centralUrl}/report/parameters?storedProc=${Uri.encodeComponent(storedProc)}");

      final res = await http.get(uri);
      final b = jsonDecode(res.body);

      if (res.statusCode == 200 && b["success"] == true) {
        final List<dynamic> plist = b["parameters"] ?? [];

        if (plist.isEmpty) {
          final dynamic fallback = widget.rapor["parametreler"];
          if (fallback is List) {
            for (final p in fallback) {
              final name = "@${p.toString().trim()}";
              final lower = p.toString().toLowerCase();
              final type = (lower.contains("date")) ? "date" : "text";
              _paramDefs.add({"name": name, "type": type});
            }
          }
        } else {
          for (final x in plist) {
            _paramDefs.add({
              "name": (x["name"] ?? "").toString(),
              "type": (x["type"] ?? "text").toString(),
            });
          }
        }

        for (final p in _paramDefs) {
          _controllers[p["name"]!] = TextEditingController();
          _values[p["name"]!] = null;
        }

        setState(() {
          loading = false;
          error = null;
        });
      } else {
        setState(() {
          loading = false;
          error = (b["message"] ?? "Parametreleri getirme hatası").toString();
        });
      }
    } catch (e) {
      setState(() {
        loading = false;
        error = e.toString();
      });
    }
  }

  Future<void> _pickDate(String name) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      final s =
          "${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      _controllers[name]?.text = s;
      _values[name] = s;
      setState(() {});
    }
  }

  void _continue() {
    for (final e in _controllers.entries) {
      final k = e.key;
      final v = e.value.text.trim();
      _values[k] = v.isEmpty ? null : v;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RaporDetayPage(
          title: (widget.rapor["raporAdi"] ?? storedProc).toString(),
          centralUrl: widget.centralUrl,
          username: widget.username,
          storedProc: storedProc,
          parameters: _values,
        ),
      ),
    );
  }

  Widget _buildField(Map<String, String> p) {
    final name = p["name"]!;
    final type = (p["type"] ?? "text").toLowerCase();

    final isDate = type.contains("date");
    final isNumeric =
        type.contains("int") || type.contains("decimal") || type.contains("float");

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextField(
        controller: _controllers[name],
        readOnly: isDate,
        keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
        onTap: isDate ? () => _pickDate(name) : null,
        decoration: InputDecoration(
          labelText: _niceLabel(name),
          suffixIcon: isDate ? const Icon(Icons.calendar_today) : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  String _niceLabel(String dbName) {
    final raw = dbName.replaceAll("@", "");
    final lower = raw.toLowerCase();
    if (lower.contains("start") && lower.contains("date")) return "Başlangıç Tarihi";
    if (lower.contains("end") && lower.contains("date")) return "Bitiş Tarihi";
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:
          AppBar(title: Text((widget.rapor['raporAdi'] ?? 'Parametreler').toString())),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(
                  child: Text("Parametre okuma hatası: $error",
                      style: const TextStyle(color: Colors.red)))
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ..._paramDefs.map(_buildField),
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          onPressed: _continue,
                          icon: const Icon(Icons.play_arrow),
                          label: const Text("Çalıştır"),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}
