import 'package:flutter/material.dart';
import 'login_page.dart';

void main() {
  runApp(const RepVXApp());
}

class RepVXApp extends StatelessWidget {
  const RepVXApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RepVX',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
      ),
      home: const LoginPage(),
    );
  }
}
