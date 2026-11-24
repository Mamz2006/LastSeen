import 'package:flutter/material.dart';
import 'package:lastseen/screens/s01_onboarding.dart';

void main() {
  runApp(const LastSeenApp());
}

class LastSeenApp extends StatelessWidget {
  const LastSeenApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'LastSeen',
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFF5F7FC),
        fontFamily: 'Inter',
      ),
      home: const S01Onboarding(),
    );
  }
}
