// lib/main.dart
import 'dart:async';
import 'package:flutter/material.dart';

import 'InfoPage.dart';
import 'welcompage.dart';

const kGold = Color(0xFFFFC107);
const kBrown = Color(0xFFD7B899);
const kBrownDark = Color(0xFF8D6E63);
const kRedSoft = Color(0xFFF28B82);

void main() {
  runApp(const BioCollarApp());
}

class BioCollarApp extends StatelessWidget {
  const BioCollarApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BioCollar',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: kBrown,
        colorScheme: ColorScheme.fromSeed(seedColor: kGold, primary: kGold),
      ),
      initialRoute: '/',
      routes: {
        '/': (_) => const SplashPage(),
        '/info': (_) => const InfoPage(),
        '/welcome': (_) => const WelcomePage(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});
  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  int pct = 0;
  Timer? t;

  @override
  void initState() {
    super.initState();
    t = Timer.periodic(const Duration(milliseconds: 30), (_) {
      if (!mounted) return;
      setState(() => pct = (pct + 1).clamp(0, 100));
      if (pct >= 100) {
        t?.cancel();
        Navigator.of(context).pushReplacementNamed('/info');
      }
    });
  }

  @override
  void dispose() {
    t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SizedBox.expand(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [kBrownDark, kBrown],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset('assets/logo.png', width: 180, fit: BoxFit.contain),
                  const SizedBox(height: 32),
                  SizedBox(
                    height: 160,
                    width: 160,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          height: 160,
                          width: 160,
                          child: CircularProgressIndicator(
                            value: pct / 100.0,
                            strokeWidth: 10,
                            color: kGold,
                            backgroundColor: Color.alphaBlend(
                              kRedSoft.withOpacity(.25),
                              kBrown,
                            ),
                          ),
                        ),
                        Text(
                          '$pct%',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
