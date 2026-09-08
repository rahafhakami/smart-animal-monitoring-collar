// lib/Registerpage.dart
import 'package:biocollarsystem/config.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:audioplayers/audioplayers.dart';
import 'successscreen.dart';
import 'failedscreen.dart';

const kGold = Color(0xFFFFC107);
const kBrown = Color(0xFFD7B899);
const kBrownDark = Color(0xFF8D6E63);
const kRedSoft = Color(0xFFF44336);

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final player = AudioPlayer();
  final nameCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final addressCtrl = TextEditingController();
  final email = TextEditingController();
  final pass = TextEditingController();
  final confirm = TextEditingController();

  bool obscure1 = true, obscure2 = true, agree = false;
  bool isLoading = false;
  String errorMessage = "";

  Future<void> _ensureFirebase() async {
    if (Firebase.apps.isEmpty) {
      await FirebaseConfig.initializeFirebase();
    }
  }

  DatabaseReference _db() =>
      FirebaseDatabase.instanceFor(app: Firebase.app(), databaseURL: FirebaseConfig.dbUrl).ref();

  bool isValidEmail(String x) =>
      RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(x);

  bool isStrongPassword(String x) =>
      x.length >= 8 && RegExp(r'[A-Z]').hasMatch(x) && RegExp(r'[0-9]').hasMatch(x);

  bool isValidPhone(String x) =>
      RegExp(r'^[0-9+\-\s]{7,}$').hasMatch(x);

  Future<void> _sound(bool ok) async {
    await player.play(AssetSource(ok ? 'sounds/success.mp3' : 'sounds/error.mp3'));
  }

  Future<bool> _emailExists(String e) async {
    await _ensureFirebase();
    final db = _db();
    for (final node in ['admins', 'veterinarians', 'petOwners']) {
      final snap = await db.child(node).get();
      if (snap.exists) {
        for (final c in snap.children) {
          final v = c.child('email').value?.toString() ?? '';
          if (v.toLowerCase() == e.toLowerCase()) return true;
        }
      }
    }
    return false;
  }

  Future<void> _register() async {
    setState(() {
      isLoading = true;
      errorMessage = "";
    });

    final n = nameCtrl.text.trim();
    final ph = phoneCtrl.text.trim();
    final ad = addressCtrl.text.trim();
    final e = email.text.trim();
    final p = pass.text;
    final pc = confirm.text;

    if (n.isEmpty || ph.isEmpty || ad.isEmpty || !isValidPhone(ph) || !isValidEmail(e) || !isStrongPassword(p) || p != pc || !agree) {
      await _sound(false);
      setState(() {
        errorMessage = "Please fill all fields correctly and accept terms.";
        isLoading = false;
      });
      Navigator.push(context, MaterialPageRoute(builder: (_) => const FailedScreen()));
      return;
    }

    if (await _emailExists(e)) {
      await _sound(false);
      setState(() {
        errorMessage = "Email already exists.";
        isLoading = false;
      });
      Navigator.push(context, MaterialPageRoute(builder: (_) => const FailedScreen()));
      return;
    }

    await _ensureFirebase();
    final db = _db();

    final newOwner = {
      "name": n,
      "phone": ph,
      "address": ad,
      "email": e,
      "password": p,
      "role": "pet_owner",
      "status": "active",
      "createdAt": DateTime.now().toIso8601String()
    };

    try {
      await db.child("petOwners").push().set(newOwner);
      await _sound(true);
      if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const SuccessScreen()));
      }
    } catch (_) {
      await _sound(false);
      setState(() {
        errorMessage = "Registration failed. Try again.";
        isLoading = false;
      });
      Navigator.push(context, MaterialPageRoute(builder: (_) => const FailedScreen()));
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
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "Sign Up",
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: Colors.amber,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _input(controller: nameCtrl, hint: "Full name", icon: Icons.person_outline),
                      const SizedBox(height: 12),
                      _input(controller: phoneCtrl, hint: "Phone number", icon: Icons.phone_outlined, type: TextInputType.phone),
                      const SizedBox(height: 12),
                      _input(controller: addressCtrl, hint: "Address", icon: Icons.home_outlined),
                      const SizedBox(height: 12),
                      _input(controller: email, hint: "Email address", icon: Icons.email_outlined, type: TextInputType.emailAddress),
                      const SizedBox(height: 12),
                      _input(
                        controller: pass,
                        hint: "Password (min 8 chars, 1 uppercase, 1 number)",
                        icon: Icons.lock_outline,
                        obscure: obscure1,
                        onToggle: () => setState(() => obscure1 = !obscure1),
                      ),
                      const SizedBox(height: 12),
                      _input(
                        controller: confirm,
                        hint: "Confirm password",
                        icon: Icons.lock_reset,
                        obscure: obscure2,
                        onToggle: () => setState(() => obscure2 = !obscure2),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Checkbox(
                            value: agree,
                            activeColor: kRedSoft,
                            onChanged: (v) => setState(() => agree = v ?? false),
                          ),
                          const Expanded(
                            child: Text(
                              "I read the terms and conditions.",
                              style: TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kRedSoft,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: isLoading ? null : _register,
                          child: isLoading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  "Sign Up",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ),
                      if (errorMessage.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          errorMessage,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red, fontSize: 13),
                        ),
                      ],
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
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size),
      ),
    );
  }

  Widget _input({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    VoidCallback? onToggle,
    TextInputType? type,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: type,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: kBrownDark),
        suffixIcon: onToggle != null
            ? IconButton(
                onPressed: onToggle,
                icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
              )
            : null,
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
    );
  }
}

class _SocialIcon extends StatelessWidget {
  final IconData icon;
  const _SocialIcon({required this.icon});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Icon(icon, size: 26, color: kBrownDark),
    );
  }
}
