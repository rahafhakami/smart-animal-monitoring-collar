// lib/welcompage.dart
import 'package:flutter/material.dart';

const kGold = Color(0xFFFFC107);
const kBrown = Color(0xFFD7B899);
const kBrownDark = Color(0xFF8D6E63);

class OwnerHomeScreen extends StatelessWidget {
  const OwnerHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBrown,
      appBar: AppBar(
          title: const Text('Welcome OwnerHomeScreen'),
          backgroundColor: kGold,
          foregroundColor: Colors.black87),
      body: Center(
        child: Text('Welcome to BioCollar OwnerHomeScreen',
            style: TextStyle(
                fontSize: 24, fontWeight: FontWeight.w800, color: kBrownDark)),
      ),
    );
  }
}
