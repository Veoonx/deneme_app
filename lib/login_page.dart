import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'menu_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

/// Merkezi API sabiti (Central)
const String kCentralBase = "http://78.135.64.145:12046/api";

class _LoginPageState extends State<LoginPage> {
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();
  bool isLoading = false;
  bool rememberMe = false;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUser = prefs.getString('username');
    final savedPass = prefs.getString('password');
    final savedRemember = prefs.getBool('rememberMe') ?? false;

    if (savedRemember && savedUser != null && savedPass != null) {
      usernameController.text = savedUser;
      passwordController.text = savedPass;
      rememberMe = true;
      setState(() {});
    }
  }

  Future<void> _login() async {
    final username = usernameController.text.trim();
    final password = passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Kullanıcı adı / şifre boş olamaz.")),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final uri = Uri.parse(
          "$kCentralBase/login/auth?username=$username&password=$password");
      final res = await http.get(uri);
      final body = jsonDecode(res.body);

      if (res.statusCode == 200 && body["success"] == true) {
        // "Beni Hatırla" kayıt işlemi
        final prefs = await SharedPreferences.getInstance();
        if (rememberMe) {
          await prefs.setString('username', username);
          await prefs.setString('password', password);
          await prefs.setBool('rememberMe', true);
        } else {
          await prefs.remove('username');
          await prefs.remove('password');
          await prefs.setBool('rememberMe', false);
        }

        final Map<String, dynamic> payload = {
          "username": username,
          "centralUrl": kCentralBase,
          "firmaKodu": body["firmaKodu"],
          "firmaAdi": body["firmaAdi"],
          "localApiUrl": body["localApiUrl"],
          "localApiKey": body["localApiKey"],
          "modules": body["modules"] ?? [],
          "reports": body["reports"] ?? [],
        };

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => MenuPage(data: payload)),
        );
      } else {
        final msg = (body["message"] ?? "Giriş başarısız").toString();
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Bağlantı hatası: $e")));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 🟢 Logo bölümü
              Image.asset(
                'assets/logo_repVX.png', // 1. görsel (daire olmayan logo)
                width: 160,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 40),

              // 🟢 Giriş alanları
              TextField(
                controller: usernameController,
                decoration: const InputDecoration(
                  labelText: "Kullanıcı Adı",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: "Şifre",
                  border: OutlineInputBorder(),
                ),
              ),

              // 🟢 Beni hatırla
              CheckboxListTile(
                title: const Text("Beni hatırla"),
                value: rememberMe,
                controlAffinity: ListTileControlAffinity.leading,
                onChanged: (val) {
                  setState(() => rememberMe = val ?? false);
                },
              ),
              const SizedBox(height: 12),

              // 🟢 Giriş butonu
              isLoading
                  ? const CircularProgressIndicator()
                  : FilledButton(
                      onPressed: _login,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                      ),
                      child: const Text("Giriş Yap"),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
