import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class DashboardPage extends StatefulWidget {
  final Map<String, dynamic> apiData;
  const DashboardPage({super.key, required this.apiData});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool _loading = false;
  String? _error;
  List<dynamic> _data = [];

  Future<void> _fetchSummary() async {
    final base = (widget.apiData["localApiUrl"] ?? "").toString().trim();
    final key = (widget.apiData["localApiKey"] ?? "").toString().trim();

    setState(() {
      _loading = true;
      _error = null;
      _data = [];
    });

    try {
      final uri = Uri.parse("$base/report/summary");
      final res = await http.get(uri, headers: {"X-API-KEY": key});

      if (res.statusCode == 200) {
        final jsonBody = json.decode(res.body);
        if (jsonBody["success"] == true) {
          setState(() {
            _data = jsonBody["data"] ?? [];
            _loading = false;
          });
        } else {
          setState(() {
            _error = jsonBody["message"] ?? "Veri alınamadı.";
            _loading = false;
          });
        }
      } else {
        setState(() {
          _error = "Sunucu hatası: ${res.statusCode}";
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = "Hata: $e";
        _loading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchSummary();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Özet Rapor")),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!))
                : _data.isEmpty
                    ? const Center(child: Text("Veri bulunamadı"))
                    : Padding(
                        padding: const EdgeInsets.all(16),
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _data.length,
                          itemBuilder: (context, index) {
                            final r = _data[index] as Map<String, dynamic>;
                            final name = r["OptionName"] ?? "";
                            final value = r["OptionValue"] ?? "";
                            final subtitle = r["OptionSubtitle"] ?? "";

                            return Container(
                              width: 180,
                              margin: const EdgeInsets.only(right: 12),
                              child: Card(
                                elevation: 4,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        value,
                                        style: const TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.indigo,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      if (subtitle.toString().isNotEmpty) ...[
                                        const SizedBox(height: 6),
                                        Text(
                                          subtitle,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
      ),
    );
  }
}
