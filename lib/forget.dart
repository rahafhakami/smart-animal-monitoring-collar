// lib/forget.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'config.dart';
import 'PINemail.dart';

const kGold = Color(0xFFFFC107);
const kBrown = Color(0xFFD7B899);
const kBrownDark = Color(0xFF8D6E63);
const kRedSoft = Color(0xFFF28B82);

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _email = TextEditingController();
  final _channel = const MethodChannel('email_channel');
  bool _sending = false;

  Future<void> _ensureFirebase() async {
    if (Firebase.apps.isEmpty) {
      await FirebaseConfig.initializeFirebase();
    }
  }

  DatabaseReference _db() =>
      FirebaseDatabase.instanceFor(app: Firebase.app(), databaseURL: FirebaseConfig.dbUrl).ref();

  String _code() => (100000 + Random().nextInt(900000)).toString();

  Future<bool> _emailExists(String email) async {
    await _ensureFirebase();
    final db = _db();
    for (final node in ['admins', 'veterinarians', 'petOwners']) {
      final snap = await db.child(node).get();
      if (snap.exists) {
        for (final c in snap.children) {
          final v = c.child('email').value?.toString() ?? '';
          if (v.trim().toLowerCase() == email.trim().toLowerCase()) return true;
        }
      }
    }
    return false;
  }

  Future<void> _sendEmail(String email, String code) async {
    await _channel.invokeMethod('sendEmail', {
      'email': email,
      'subject': 'Password Reset Code',
      'message': 'Your verification code is: <b>$code</b>',
    });
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    if (email.isEmpty || !RegExp(r'^[\w\-\.]+@([\w\-]+\.)+[\w\-]{2,}$').hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid email')));
      return;
    }
    setState(() => _sending = true);
    final exists = await _emailExists(email);
    if (!exists) {
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Email is not registered')));
      return;
    }
    final code = _code();
    try {
      await _sendEmail(email, code);
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => VerifyEmailScreen(email: email, code: code)),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: kBrown,
      body: Stack(
        children: [
          Positioned(
            top: -size.width * .35,
            left: -size.width * .25,
            child: _blob(size.width * 1.1, const [Color(0xFFFFE082), kGold]),
          ),
          Positioned(
            bottom: -size.width * .4,
            right: -size.width * .3,
            child: _blob(size.width * 1.2, const [kRedSoft, Color(0xFFFFCDD2)]),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
          Align(
            alignment: Alignment.center,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(22, 26, 22, 24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: kBrownDark.withOpacity(.15),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      )
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset('assets/logo.png', width: 120, height: 120, fit: BoxFit.contain),
                      const SizedBox(height: 12),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Forgot Password',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.black87),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Enter your email below. We will send a code to verify your identity.',
                          style: TextStyle(fontSize: 13, color: Colors.black54, height: 1.3),
                        ),
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          hintText: 'Email Address',
                          prefixIcon: Icon(Icons.email_outlined, color: kBrownDark),
                          filled: true,
                          fillColor: const Color(0xFFF7F7F7),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
                          ),
                          focusedBorder: const OutlineInputBorder(
                            borderSide: BorderSide(color: kGold, width: 2),
                          ),
                          contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kRedSoft,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: _sending ? null : _submit,
                          child: _sending
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Text('Send Email', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _blob(double size, List<Color> colors) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(size),
      ),
    );
  }
}
