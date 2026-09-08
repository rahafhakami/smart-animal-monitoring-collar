// lib/resetpasswordscreen.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:audioplayers/audioplayers.dart';
import 'successscreen.dart';
import 'failedscreen.dart';
import 'config.dart';

const kGold = Color(0xFFFFC107);
const kBrown = Color(0xFFD7B899);
const kBrownDark = Color(0xFF8D6E63);
const kRedSoft = Color(0xFFF28B82);

class ResetPasswordScreen extends StatefulWidget {
  final String email;
  const ResetPasswordScreen({super.key, required this.email});
  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final pass = TextEditingController();
  final confirm = TextEditingController();
  final player = AudioPlayer();
  bool obscure1 = true, obscure2 = true, isLoading = false;

  Future<void> _ensureFirebase() async {
    if (Firebase.apps.isEmpty) {
      await FirebaseConfig.initializeFirebase();
    }
  }

  DatabaseReference _db() => FirebaseDatabase.instanceFor(
          app: Firebase.app(), databaseURL: FirebaseConfig.dbUrl)
      .ref();

  bool _strong(String x) =>
      x.length >= 8 &&
      RegExp(r'[A-Z]').hasMatch(x) &&
      RegExp(r'[0-9]').hasMatch(x);

  Future<bool> _updatePassword(String email, String newPassword) async {
    try {
      await _ensureFirebase();
      final db = _db();
      final lower = email.trim().toLowerCase();
      for (final node in ['admins', 'veterinarians', 'petOwners']) {
        final snap = await db.child(node).get();
        if (snap.exists) {
          for (final c in snap.children) {
            final e =
                (c.child('email').value ?? '').toString().trim().toLowerCase();
            if (e == lower) {
              await db
                  .child(node)
                  .child(c.key!)
                  .update({'password': newPassword});
              return true;
            }
          }
        }
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _submit() async {
    final p = pass.text.trim();
    final pc = confirm.text.trim();
    if (!_strong(p) || p != pc) {
      await player.play(AssetSource('sounds/error.mp3'));
      if (!mounted) return;
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const FailedScreen()));
      return;
    }
    setState(() => isLoading = true);
    final ok = await _updatePassword(widget.email, p);
    if (!mounted) return;
    setState(() => isLoading = false);
    if (ok) {
      await player.play(AssetSource('sounds/success.mp3'));
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const SuccessScreen()));
    } else {
      await player.play(AssetSource('sounds/error.mp3'));
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const FailedScreen()));
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
                      Image.asset('assets/logo.png',
                          width: 100, height: 100, fit: BoxFit.contain),
                      const SizedBox(height: 14),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Set New Password',
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Colors.black87),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Create a strong password different from the previous one, then confirm it to finish the reset.',
                          style: TextStyle(
                              fontSize: 13, color: Colors.black54, height: 1.3),
                        ),
                      ),
                      const SizedBox(height: 18),
                      _input(
                        controller: pass,
                        hint:
                            'New password (min 8 chars, 1 uppercase, 1 number)',
                        icon: Icons.lock_outline,
                        obscure: obscure1,
                        onToggle: () => setState(() => obscure1 = !obscure1),
                      ),
                      const SizedBox(height: 12),
                      _input(
                        controller: confirm,
                        hint: 'Confirm new password',
                        icon: Icons.lock_reset,
                        obscure: obscure2,
                        onToggle: () => setState(() => obscure2 = !obscure2),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kRedSoft,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: isLoading ? null : _submit,
                          child: isLoading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : const Text('Set Password',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700)),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          'Back to Login',
                          style: TextStyle(
                              color: Colors.black54,
                              decoration: TextDecoration.underline),
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
        gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
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
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
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
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: kGold, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      ),
    );
  }
}
