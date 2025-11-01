import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_scanner/mobile_scanner.dart';

class UrunSorgulaPage extends StatefulWidget {
  final Map<String, dynamic> apiData;
  const UrunSorgulaPage({super.key, required this.apiData});

  @override
  State<UrunSorgulaPage> createState() => _UrunSorgulaPageState();
}

class _UrunSorgulaPageState extends State<UrunSorgulaPage> {
  final TextEditingController _keyword = TextEditingController();
  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _apiJson;

  List<dynamic> get _sp1 => _apiJson?["data"]?["sp_rpt_urunSorgula_1"] ?? [];
  List<dynamic> get _sp2 => _apiJson?["data"]?["sp_rpt_urunSorgula_2"] ?? [];
  List<dynamic> get _sp3 => _apiJson?["data"]?["sp_rpt_urunSorgula_3"] ?? [];
  List<dynamic> get _sp4 => _apiJson?["data"]?["sp_rpt_urunSorgula_4"] ?? [];

  String _opt(String name) {
    try {
      final row = _sp2.firstWhere(
          (x) => (x["OptionName"] ?? "") == name,
          orElse: () => null);
      return (row?["OptionValue"] ?? "").toString();
    } catch (_) {
      return "";
    }
  }

Future<void> _fetch() async {
  final base = (widget.apiData["localApiUrl"] ?? "").toString().trim();
  final key = (widget.apiData["localApiKey"] ?? "").toString().trim();
  final kw = _keyword.text.trim();

  if (kw.isEmpty) {
    setState(() => _error = "Barkod / ürün kodu giriniz.");
    return;
  }

  setState(() {
    _loading = true;
    _error = null;
    _apiJson = null;
  });

  final uri = Uri.parse("$base/report/urunSorgula?keyword=$kw");
  try {
    final res = await http.get(uri, headers: {"X-API-KEY": key});
    if (!mounted) return;

    if (res.statusCode == 200) {
      final jsonBody = json.decode(res.body);

      if (jsonBody["success"] == true) {
        final data = jsonBody["data"];
        final list1 = data?["sp_rpt_urunSorgula_1"] ?? [];
        final list4 = data?["sp_rpt_urunSorgula_4"] ?? [];

        if (list1.isNotEmpty) {
          setState(() {
            _apiJson = jsonBody;
            _loading = false;
          });
        } else if (list4.isNotEmpty) {
          // ürün detayı yok ama varyantlar var => popup
          setState(() => _loading = false);
          await _showUrunAramaPopupFromSp4(list4);
        } else {
          setState(() {
            _loading = false;
            _error = "Ürün bulunamadı.";
          });
        }
      } else {
        setState(() {
          _loading = false;
          _error = jsonBody["message"] ?? "İşlem başarısız.";
        });
      }
    } else {
      setState(() {
        _loading = false;
        _error = "Sunucu yanıtı: ${res.statusCode}";
      });
    }
  } catch (e) {
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = "Hata: $e";
    });
  }
}

Future<void> _showUrunAramaPopupFromSp4(List<dynamic> list4) async {
  if (list4.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Benzer ürün bulunamadı.")),
    );
    return;
  }

  final secilen = await showDialog<Map<String, dynamic>>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text("Benzer Ürünler"),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: ListView.builder(
          itemCount: list4.length,
          itemBuilder: (ctx, i) {
            final r = Map<String, dynamic>.from(list4[i]);
            final code = (r["ItemCode"] ?? "").toString();
            final desc = (r["AddInfo"] ?? "").toString();
            final extra = (r["ItemDescription"] ?? "").toString();

            return ListTile(
              title: Text("$code - $desc",
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(extra, style: const TextStyle(color: Colors.grey)),
              onTap: () => Navigator.pop(ctx, r),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text("Kapat"),
        ),
      ],
    ),
  );

  if (secilen != null) {
    setState(() {
      _keyword.text = secilen["ProductCode"] ?? "";
    });
    await _fetch();
  }
}

  Future<void> _scanBarcode() async {
    await showDialog(
      context: context,
      builder: (ctx) {
        return Scaffold(
          appBar: AppBar(title: const Text("Barkod Okut")),
          body: MobileScanner(
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              if (barcodes.isNotEmpty) {
                final code = barcodes.first.rawValue ?? "";
                Navigator.pop(ctx);
                setState(() => _keyword.text = code);
                _fetch();
              }
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final imgUrl = _sp1.isNotEmpty ? (_sp1.first["ImageURL"] ?? "") : "";

    return Scaffold(
      appBar: AppBar(title: const Text("Ürün Sorgulama")),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _keyword,
                      decoration: InputDecoration(
                        labelText: "Barkod veya Ürün Kodu",
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.camera_alt),
                          onPressed: _scanBarcode,
                        ),
                      ),
                      onSubmitted: (_) => _fetch(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _loading ? null : _fetch,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(80, 54),
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 22,
                            height: 26,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.search),
                  ),
                ],
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: MaterialBanner(
                  content: Text(_error!),
                  actions: [
                    TextButton(
                      onPressed: () => setState(() => _error = null),
                      child: const Text("Kapat"),
                    )
                  ],
                ),
              ),
            Expanded(
              child: _apiJson == null
                  ? const Center(child: Text("Ürün araması yapın veya barkod okutun"))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (imgUrl.isNotEmpty || _sp2.isNotEmpty)
                            Card(
                              elevation: 2,
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (imgUrl.isNotEmpty)
                                      GestureDetector(
                                        onTap: () {
                                          showDialog(
                                            context: context,
                                            builder: (_) => Dialog(
                                              child: InteractiveViewer(
                                                child: Image.network(imgUrl,
                                                    fit: BoxFit.contain),
                                              ),
                                            ),
                                          );
                                        },
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: Image.network(
                                            imgUrl,
                                            width: 180,
                                            height: 180,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                const Icon(Icons.image),
                                          ),
                                        ),
                                      ),
                                    const SizedBox(width: 16),
                                   Expanded(
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (var i = 0; i < _sp2.length; i++) ...[
        _detailRow(
          _sp2[i]["OptionName"]?.toString() ?? "",
          _sp2[i]["OptionValue"]?.toString() ?? "",
        ),
        if (i < _sp2.length - 1) _divider(),
      ],
    ],
  ),
),
                                  ],
                                ),
                              ),
                            ),
                          const SizedBox(height: 16),
                          if (_sp3.isNotEmpty) ...[
                            const _SectionTitle("Depo / Mağaza Stokları"),
                            const SizedBox(height: 8),
                            ..._groupStocks(_sp3),
                          ],
                          if (_sp4.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            const _SectionTitle("Varyantlar"),
                            const SizedBox(height: 8),
                            Card(
                              elevation: 2,
                              child: ListView.separated(
                                physics: const NeverScrollableScrollPhysics(),
                                shrinkWrap: true,
                                itemCount: _sp4.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(height: 1),
                                itemBuilder: (ctx, i) {
                                  final r = _sp4[i] as Map<String, dynamic>;
                                  return ListTile(
                                    title: Text(r["AddInfo"] ?? ""),
                                    subtitle: Text(r["ItemDescription"] ?? ""),
                                    trailing: Text(r["ItemCode"] ?? ""),
                                  );
                                },
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          Flexible(
            child: Text(
              value.isEmpty ? "-" : value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 14),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() =>
      const Divider(height: 12, thickness: 1, color: Color(0xFFEAEAEA));

  List<Widget> _groupStocks(List<dynamic> rows) {
    final Map<String, List<Map<String, String>>> groups = {};
    for (final raw in rows) {
      final r = Map<String, dynamic>.from(raw as Map);
      final wh =
          "${r["WarehouseCode"] ?? ""} - ${r["WarehouseDescription"] ?? ""}";
      final name = (r["OptionName"] ?? "").toString();
      final val = (r["OptionValue"] ?? "").toString();
      groups.putIfAbsent(wh, () => []);
      if (name.isNotEmpty) {
        groups[wh]!.add({"name": name, "value": val});
      }
    }

    return groups.entries.map((e) {
      return Card(
        elevation: 1,
        child: ExpansionTile(
          title: Text(e.key),
          children: e.value.isEmpty
              ? [const Padding(padding: EdgeInsets.all(12), child: Text("Kayıt yok"))]
              : e.value
                  .map((x) => ListTile(
                        dense: true,
                        title: Text(x["name"]!),
                        trailing: Text(x["value"]!),
                      ))
                  .toList(),
        ),
      );
    }).toList();
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold));
  }
}
