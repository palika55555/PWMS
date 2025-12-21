import 'package:flutter/material.dart';

import 'screens/home_screen.dart';

void main() {
  runApp(const ProBlockApp());
}

class ProBlockApp extends StatelessWidget {
  const ProBlockApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ProBlock',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2E5BFF)),
      ),
      home: const HomeScreen(),
    );
  }
}
