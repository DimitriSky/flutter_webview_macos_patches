import 'package:flutter/material.dart';
import 'lab/lab_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const KeyLabApp());
}

class KeyLabApp extends StatelessWidget {
  const KeyLabApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'WebView Key Lab',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff087e8b)),
        scaffoldBackgroundColor: const Color(0xfff6f7f8),
      ),
      home: const LabScreen(),
    );
  }
}
