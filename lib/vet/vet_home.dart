// lib/welcompage.dart
import 'package:flutter/material.dart';

const kGold = Color(0xFFFFC107);
const kBrown = Color(0xFFD7B899);
const kBrownDark = Color(0xFF8D6E63);

class VetHomeScreen extends StatelessWidget {
  const VetHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBrown,
      appBar: AppBar(
          title: const Text('Welcome'),
          backgroundColor: kGold,
          foregroundColor: Colors.black87),
      body: Center(
        child: Text('Welcome to BioCollar',
            style: TextStyle(
                fontSize: 24, fontWeight: FontWeight.w800, color: kBrownDark)),
      ),
    );
  }
}
