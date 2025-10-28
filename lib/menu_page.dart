import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'login_page.dart';
import 'rapor_parametre_page.dart';
import 'urun_sorgula_page.dart';

class MenuPage extends StatefulWidget {
  final Map<String, dynamic> data; // login'den gelen payload
  const MenuPage({super.key, required this.data});

  @override
  State<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> with WidgetsBindingObserver {
  bool _loadingSummary = false;
  String? _error;
  List<dynamic> _summary = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // lifecycle dinle
    _fetchSummary();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Uygulama durumu değişince Central logout (sessiz)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached || state == AppLifecycleState.inactive) {
      _logoutCentralSilently();
    }
  }

  Future<void> _logoutCentralSilently() async {
    final username = (widget.data["username"] ?? "").toString();
    final centralUrl = (widget.data["centralUrl"] ?? "").toString();
    if (username.isEmpty || centralUrl.isEmpty) return;
    try {
      final uri = Uri.parse("$centralUrl/login/logout?username=$username");
      await http.get(uri).timeout(const Duration(seconds: 3));
    } catch (_) {
      // sessiz geç
    }
  }

  Future<void> _fetchSummary() async {
    final base = (widget.data["localApiUrl"] ?? "").toString().trim();
    final key = (widget.data["localApiKey"] ?? "").toString().trim();

    if (base.isEmpty || key.isEmpty) return;

    setState(() {
      _loadingSummary = true;
      _error = null;
      _summary = [];
    });

    try {
      final uri = Uri.parse("$base/report/summary");
      final res = await http.get(uri, headers: {"X-API-KEY": key});
      if (res.statusCode == 200) {
        final jsonBody = json.decode(res.body);
        if (jsonBody["success"] == true) {
          setState(() => _summary = jsonBody["data"] ?? []);
        } else {
          _error = jsonBody["message"];
        }
      } else {
        _error = "Sunucu hatası: ${res.statusCode}";
      }
    } catch (e) {
      _error = "Hata: $e";
    }

    if (mounted) setState(() => _loadingSummary = false);
  }

  @override
  Widget build(BuildContext context) {
    final modules = (widget.data['modules'] ?? [])
        .where((x) => x['gorurMu'] == true)
        .toList();
    final reports = (widget.data['reports'] ?? [])
        .where((x) => x['gorurMu'] == true)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text("Menü - ${widget.data['firmaAdi']}"),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.settings),
            onSelected: (value) {
              if (value == 'limit') {
                _showLimitDialog(context);
              } else if (value == 'logout') {
                _logout(context);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'limit',
                child: Text('Kayıt Sayısı'),
              ),
              PopupMenuItem(
                value: 'logout',
                child: Text('Çıkış Yap'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSummarySlider(),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              children: [
                if (modules.isNotEmpty) _buildSection("Modüller", modules),
                if (reports.isNotEmpty) _buildSection("Raporlar", reports, isReport: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<dynamic> items, {bool isReport = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
          child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        ...items.map((item) {
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: ListTile(
              title: Text(item[isReport ? 'raporAdi' : 'modulAdi']),
              subtitle: isReport
                  ? Text(item['kategori'] ?? '', style: const TextStyle(color: Colors.grey))
                  : null,
              trailing: const Icon(Icons.arrow_forward_ios, size: 18),
              onTap: () {
                if (isReport) {
                  _openReport(item as Map<String, dynamic>);
                } else {
                  _openModule(item as Map<String, dynamic>);
                }
              },
            ),
          );
        }).toList()
      ],
    );
  }

  void _openModule(Map<String, dynamic> modul) {
    final code = modul['modulKodu'];
    if (code == "URUN_SORGULA") {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => UrunSorgulaPage(apiData: widget.data)),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("${modul['modulAdi']} modülü henüz aktif değil.")),
      );
    }
  }

  void _openReport(Map<String, dynamic> rapor) {
    final username = (widget.data["username"] ?? "").toString();
    final centralUrl = (widget.data["centralUrl"] ?? "").toString();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RaporParametrePage(
          rapor: rapor,
          centralUrl: centralUrl,
          username: username,
        ),
      ),
    );
  }

  /// Çıkış Yap (Central + local temizliği)
  Future<void> _logout(BuildContext context) async {
    final username = (widget.data["username"] ?? "").toString();
    final centralUrl = (widget.data["centralUrl"] ?? "").toString();

    try {
      if (username.isNotEmpty && centralUrl.isNotEmpty) {
        final uri = Uri.parse("$centralUrl/login/logout?username=$username");
        await http.get(uri).timeout(const Duration(seconds: 5));
      }
    } catch (_) {
      // sessiz geç
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  /// Kayıt Sayısı Dialogu
  Future<void> _showLimitDialog(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt('recordLimit') ?? 50;
    int newLimit = current;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text("Kayıt Sayısı"),
            content: DropdownButton<int>(
              value: newLimit,
              isExpanded: true,
              items: [10, 20, 50, 100]
                  .map((e) => DropdownMenuItem(value: e, child: Text("$e")))
                  .toList(),
              onChanged: (val) => setState(() => newLimit = val ?? current),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("İptal"),
              ),
              TextButton(
                onPressed: () async {
                  await prefs.setInt('recordLimit', newLimit);
                  if (!mounted) return;
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Kayıt sayısı $newLimit olarak ayarlandı.")),
                  );
                },
                child: const Text("Kaydet"),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummarySlider() {
    if (_loadingSummary) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: LinearProgressIndicator(),
      );
    }

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Text(_error!, style: const TextStyle(color: Colors.red)),
      );
    }

    if (_summary.isEmpty) return const SizedBox(height: 0);

    return Container(
      height: 110,
      color: Colors.grey.shade100,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _summary.length,
        itemBuilder: (context, index) {
          final item = _summary[index];
          return Container(
            width: 180,
            margin: const EdgeInsets.only(right: 10),
            child: Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(item["OptionName"] ?? "",
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Text(item["OptionValue"] ?? "",
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold, color: Colors.indigo)),
                    if ((item["OptionSubtitle"] ?? "").toString().isNotEmpty)
                      Text(item["OptionSubtitle"],
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
