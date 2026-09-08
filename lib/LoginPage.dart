// lib/LoginPage.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'admin/admin_home.dart';
import 'vet/vet_home.dart';
import 'owner/owner_home.dart';
import 'Registerpage.dart';
import 'forget.dart';
import 'config.dart';

const kGold = Color(0xFFFFC107);
const kBrown = Color(0xFFD7B899);
const kBrownDark = Color(0xFF8D6E63);
const kRedSoft = Color(0xFFF44336);

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool isLoading = false;
  bool obscure = true;
  String errorMessage = "";

  @override
  void initState() {
    super.initState();
    _checkSavedLogin();
  }

  Future<void> _ensureFirebase() async {
    if (Firebase.apps.isEmpty) {
      await FirebaseConfig.initializeFirebase();
    }
  }

  Future<void> _checkSavedLogin() async {
    final p = await SharedPreferences.getInstance();
    final role = p.getString("userRole");
    if (role != null) _redirectToHome(role);
  }

  Future<void> _saveLogin(String uid, String email, String role) async {
    final p = await SharedPreferences.getInstance();
    await p.setString("userId", uid);
    await p.setString("userEmail", email);
    await p.setString("userRole", role);
  }

  void _redirectToHome(String role) {
    Widget home;
    switch (role) {
      case "admin":
        home = const AdminHomeScreen();
        break;
      case "veterinarian":
        home = const VetHomeScreen();
        break;
      case "pet_owner":
        home = const OwnerHomeScreen();
        break;
      default:
        setState(() => errorMessage = "Invalid user role");
        return;
    }
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => home));
  }

  Future<void> _login() async {
    setState(() {
      isLoading = true;
      errorMessage = "";
    });

    await _ensureFirebase();
    final db = FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: FirebaseConfig.dbUrl,
    ).ref();

    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    Future<bool> checkNode(String node, String roleValue) async {
      final snap = await db.child(node).get();
      if (snap.exists) {
        for (final c in snap.children) {
          final e = c.child("email").value?.toString() ?? "";
          final p = c.child("password").value?.toString() ?? "";
          if (e.toLowerCase() == email.toLowerCase() && p == password) {
            await _saveLogin(c.key!, email, roleValue);
            _redirectToHome(roleValue);
            return true;
          }
        }
      }
      return false;
    }

    final ok = await checkNode("admins", "admin") ||
        await checkNode("veterinarians", "veterinarian") ||
        await checkNode("petOwners", "pet_owner");

    if (!ok) {
      setState(() {
        errorMessage = "Login failed. Please check your credentials.";
        isLoading = false;
      });
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
            top: -size.width * .3,
            left: -size.width * .2,
            child: _blob(size.width * .9, const [Color(0xFFFFE082), kGold]),
          ),
          Positioned(
            bottom: -size.width * .35,
            right: -size.width * .25,
            child: _blob(size.width * 1.0, const [kRedSoft, Color(0xFFFFCDD2)]),
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
                          "Login",
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: Colors.amber,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _input(
                        controller: emailController,
                        hint: "Email address",
                        icon: Icons.email_outlined,
                      ),
                      const SizedBox(height: 12),
                      _input(
                        controller: passwordController,
                        hint: "Password",
                        icon: Icons.lock_outline,
                        obscure: obscure,
                        onToggle: () => setState(() => obscure = !obscure),
                      ),
                      const SizedBox(height: 18),
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
                          onPressed: isLoading ? null : _login,
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
                                  "Login",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: const [
                          Expanded(child: Divider()),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              "or sign in with",
                              style: TextStyle(color: Colors.black54),
                            ),
                          ),
                          Expanded(child: Divider()),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          _SocialIcon(icon: Icons.apple),
                          SizedBox(width: 18),
                          _SocialIcon(icon: Icons.facebook),
                          SizedBox(width: 18),
                          _SocialIcon(icon: Icons.g_mobiledata),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const RegisterScreen(),
                              ),
                            ),
                            child: const Text("Create account"),
                          ),
                          TextButton(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ForgotPasswordScreen(),
                              ),
                            ),
                            child: const Text("Forgot password?"),
                          ),
                        ],
                      ),
                      if (errorMessage.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          errorMessage,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 13,
                          ),
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
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: kGold, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
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
