// lib/InfoPage.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// شاشات المنازل حسب الأدوار
import 'admin/admin_home.dart';
import 'vet/vet_home.dart';
import 'owner/owner_home.dart';

const kGold = Color(0xFFFFC107);
const kBrown = Color(0xFFD7B899);
const kBrownDark = Color(0xFF8D6E63);
const kRedSoft = Color(0xFFF28B82);

class InfoPage extends StatefulWidget {
  const InfoPage({super.key});
  @override
  State<InfoPage> createState() => _InfoPageState();
}

class _InfoPageState extends State<InfoPage> {
  final _pc = PageController();
  int _i = 0;
  bool _checking = true; // لفترة الفحص السريع

  final _slides = const [
    (
      "Real-time Health Monitoring",
      "Track heart rate, temperature, and activity for your pet in real time.",
      "https://images.unsplash.com/photo-1548199973-03cce0bbc87b?auto=format&fit=crop&w=1200&q=60"
    ),
    (
      "Smart Location Alerts",
      "Get GPS and safe-zone notifications anywhere, anytime.",
      "https://images.unsplash.com/photo-1507149833265-60c372daea22?auto=format&fit=crop&w=1200&q=60"
    ),
    (
      "Vet Teleconsultation",
      "Share records with veterinarians and get guidance instantly.",
      "https://images.unsplash.com/photo-1582719478250-c89cae4dc85b?auto=format&fit=crop&w=1200&q=60"
    ),
  ];

  @override
  void initState() {
    super.initState();
    _checkSavedLogin();
  }

  Future<void> _checkSavedLogin() async {
    final p = await SharedPreferences.getInstance();
    final role = p.getString('userRole'); // محفوظة من تسجيل الدخول
    if (role != null && role.isNotEmpty) {
      // تأجيل النڤيجيت لِما بعد أول فريم
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _redirectToHome(role);
      });
    } else {
      if (mounted) setState(() => _checking = false);
    }
  }

  void _redirectToHome(String role) {
    Widget? home;
    switch (role) {
      case 'admin':
        home = const AdminHomeScreen();
        break;
      case 'veterinarian':
        home = const VetHomeScreen();
        break;
      case 'pet_owner':
        home = const OwnerHomeScreen();
        break;
    }
    if (home != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => home!),
      );
    } else {
      // دور غير معروف -> عرض السلايدر عادي
      setState(() => _checking = false);
    }
  }

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  void _next() {
    if (_i < _slides.length - 1) {
      _pc.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } else {
      // بعد آخر سلايد، روّح لصفحة الترحيب/تسجيل الدخول
      Navigator.of(context).pushReplacementNamed('/welcome');
    }
  }

  @override
  Widget build(BuildContext context) {
    // شاشة انتظار قصيرة أثناء فحص الذاكرة
    if (_checking) {
      return const Scaffold(
        backgroundColor: kBrown,
        body: Center(
          child: CircularProgressIndicator(color: kGold),
        ),
      );
    }

    return Scaffold(
      backgroundColor: kBrown,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),
            Expanded(
              child: PageView.builder(
                controller: _pc,
                itemCount: _slides.length,
                onPageChanged: (v) => setState(() => _i = v),
                itemBuilder: (_, idx) {
                  final s = _slides[idx];
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [kBrownDark, kBrown],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                        children: [
                          const SizedBox(height: 20),
                          Expanded(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Image.network(
                                  s.$3,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16),
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  s.$1,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: kBrownDark,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  s.$2,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    height: 1.5,
                                    color: Color(0xFF5D4037),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: List.generate(_slides.length, (k) {
                                    final active = k == _i;
                                    return AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 200),
                                      margin: const EdgeInsets.symmetric(
                                          horizontal: 4),
                                      height: 8,
                                      width: active ? 24 : 8,
                                      decoration: BoxDecoration(
                                        color: active
                                            ? kGold
                                            : kRedSoft.withOpacity(.35),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    );
                                  }),
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  height: 52,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: kGold,
                                      foregroundColor: Colors.black87,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    onPressed: _next,
                                    child: Text(_i == _slides.length - 1
                                        ? "Get Started"
                                        : "Next"),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}
