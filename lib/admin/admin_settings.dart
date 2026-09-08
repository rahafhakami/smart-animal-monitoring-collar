// lib/admin/admin_settings.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import '../LoginPage.dart';

const kGold = Color(0xFFFFC107);
const kBrown = Color(0xFFD7B899);
const kBrownDark = Color(0xFF8D6E63);
const kRedSoft = Color(0xFFF28B82);

/// ---------------------------------------------------------------------------
/// How to enable instant Dark/Light switch:
/// 1) Wrap your MaterialApp with ThemeControllerHost at the very top (main.dart):
///
///   void main() async {
///     WidgetsFlutterBinding.ensureInitialized();
///     final prefs = await SharedPreferences.getInstance();
///     final initial = (prefs.getString('themeMode') ?? 'light') == 'dark'
///         ? ThemeMode.dark : ThemeMode.light;
///     runApp(ThemeControllerHost(
///       initialMode: initial,
///       childBuilder: (modeNotifier) => ValueListenableBuilder<ThemeMode>(
///         valueListenable: modeNotifier,
///         builder: (_, mode, __) => MaterialApp(
///           themeMode: mode,
///           theme: ThemeData.light(useMaterial3: true),
///           darkTheme: ThemeData.dark(useMaterial3: true),
///           home: const LoginPage(), // your root
///         ),
///       ),
///     ));
///   }
///
/// 2) This Settings page will call ThemeControllerHost.of(context)?.setThemeMode(...)
///    to switch instantly, and still persists the choice in SharedPreferences.
/// ---------------------------------------------------------------------------

class AdminSettingsPage extends StatefulWidget {
  const AdminSettingsPage({super.key});
  @override
  State<AdminSettingsPage> createState() => _AdminSettingsPageState();
}

class _AdminSettingsPageState extends State<AdminSettingsPage> {
  bool _loading = true;

  // Preferences
  bool _darkMode = false;
  String _lang = 'en';

  // Admin basic info
  String _adminId = '';
  String _name = '';
  String _email = '';
  String _username = '';

  Future<void> _ensure() async {
    if (Firebase.apps.isEmpty) await FirebaseConfig.initializeFirebase();
  }

  DatabaseReference _db() => FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: FirebaseConfig.dbUrl,
      ).ref();

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    await _ensure();
    final p = await SharedPreferences.getInstance();

    _darkMode = (p.getString('themeMode') ?? 'light') == 'dark';
    _lang = p.getString('lang') ?? 'en';

    // Read current admin (from local userId if available, otherwise first admin)
    String? uid = p.getString('userId');
    final admins = await _db().child('admins').get();
    if (admins.exists) {
      if (uid != null && admins.child(uid).exists) {
        final s = admins.child(uid);
        _adminId = uid;
        _username = s.child('username').value?.toString() ?? '';
        _name = s.child('username').value?.toString() ?? '';
        _email = s.child('email').value?.toString() ?? '';
      } else {
        final s = admins.children.first;
        _adminId = s.key ?? '';
        _username = s.child('username').value?.toString() ?? '';
        _name = s.child('username').value?.toString() ?? '';
        _email = s.child('email').value?.toString() ?? '';
      }
    }

    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final tiles = <Widget>[
      _section('Account'),
      _tile(
        icon: Icons.account_circle_outlined,
        title: 'View Profile',
        onTap: _viewProfile,
      ),
      _tile(
        icon: Icons.edit_outlined,
        title: 'Edit Profile',
        onTap: _editProfile,
      ),
      _tile(
        icon: _darkMode ? Icons.dark_mode : Icons.light_mode,
        title: 'Theme Mode',
        subtitle: _darkMode ? 'Dark' : 'Light',
        trailing: Switch(
          value: _darkMode,
          activeColor: kGold,
          onChanged: (v) => _toggleTheme(v),
        ),
        onTap: () => _toggleTheme(!_darkMode),
      ),
      _tile(
        icon: Icons.lock_reset_outlined,
        title: 'Change Password',
        onTap: _changePassword,
      ),
      _tile(
        icon: Icons.language,
        title: 'Switch language to Arabic',
        subtitle: _lang == 'ar' ? 'Arabic is active' : 'Currently English',
        onTap: _switchToArabic,
      ),
      _section('Session'),
      _tile(
        icon: Icons.logout,
        title: 'Log Out',
        color: kRedSoft,
        onTap: _logout,
      ),
      _section('Danger Zone'),
      _tile(
        icon: Icons.delete_forever_outlined,
        title: 'Delete Account Permanently',
        color: Colors.red,
        onTap: _deleteAccount,
      ),
      const SizedBox(height: 16),
    ];

    return Scaffold(
      backgroundColor: kBrown,
      appBar: AppBar(
        backgroundColor: kGold,
        foregroundColor: Colors.black87,
        title: const Text('Settings'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
              children: tiles,
            ),
    );
  }

  // ====================== Actions ======================

  Future<void> _toggleTheme(bool v) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('themeMode', v ? 'dark' : 'light');
    setState(() => _darkMode = v);

    // Apply immediately using ThemeControllerHost (if mounted above).
    ThemeControllerHost.of(context)?.setThemeMode(
      v ? ThemeMode.dark : ThemeMode.light,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(v ? 'Dark mode enabled.' : 'Light mode enabled.'),
      ),
    );
  }

  Future<void> _switchToArabic() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('lang', 'ar');
    setState(() => _lang = 'ar');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Arabic selected. Restart the app to apply.'),
      ),
    );
  }

  Future<void> _logout() async {
    final p = await SharedPreferences.getInstance();
    await p.clear();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (_) => false,
    );
  }

  Future<void> _deleteAccount() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete account permanently?'),
        content: const Text(
            'This action cannot be undone. Type DELETE to confirm and press OK.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(c, true), child: const Text('OK')),
        ],
      ),
    );
    if (ok != true) return;

    final ctrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Confirm deletion'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: 'Type: DELETE'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () =>
                Navigator.pop(c, ctrl.text.trim().toUpperCase() == 'DELETE'),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && _adminId.isNotEmpty) {
      await _db().child('admins').child(_adminId).remove();
      await _logout();
    }
  }

  Future<void> _viewProfile() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final kb = MediaQuery.of(ctx).viewInsets.bottom;
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(12, 12, 12, kb + 12),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(children: [
                      const Text('Profile',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w800)),
                      const Spacer(),
                      IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close)),
                    ]),
                    const SizedBox(height: 10),
                    _kv('ID', _adminId.isEmpty ? '-' : _adminId),
                    _kv('Name', _name.isEmpty ? '-' : _name),
                    _kv('Username', _username.isEmpty ? '-' : _username),
                    _kv('Email', _email.isEmpty ? '-' : _email),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _editProfile() async {
    final name = TextEditingController(text: _name);
    final username = TextEditingController(text: _username);
    final email = TextEditingController(text: _email);
    final form = GlobalKey<FormState>();

    bool isEmail(String s) =>
        RegExp(r'^[\w\.\-]+@([\w\-]+\.)+[\w\-]{2,}$').hasMatch(s);

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final kb = MediaQuery.of(ctx).viewInsets.bottom;
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(12, 12, 12, kb + 12),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: form,
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(children: [
                          const Text('Edit Profile',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w800)),
                          const Spacer(),
                          IconButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            icon: const Icon(Icons.close),
                          ),
                        ]),
                        const SizedBox(height: 8),
                        _input(
                          controller: name,
                          hint: 'Name',
                          icon: Icons.person_outline,
                          validator: (v) =>
                              v!.trim().length < 2 ? 'Invalid name' : null,
                        ),
                        _input(
                          controller: username,
                          hint: 'Username',
                          icon: Icons.badge_outlined,
                          validator: (v) =>
                              v!.trim().length < 3 ? 'Invalid username' : null,
                        ),
                        _input(
                          controller: email,
                          hint: 'Email',
                          icon: Icons.email_outlined,
                          keyboard: TextInputType.emailAddress,
                          validator: (v) =>
                              !isEmail(v!.trim()) ? 'Invalid email' : null,
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kGold,
                              foregroundColor: Colors.black87,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                            ),
                            onPressed: () async {
                              if (!form.currentState!.validate()) return;
                              if (_adminId.isEmpty) {
                                if (ctx.mounted) Navigator.pop(ctx, false);
                                return;
                              }
                              await _db()
                                  .child('admins')
                                  .child(_adminId)
                                  .update({
                                'username': username.text.trim(),
                                'email': email.text.trim(),
                              });
                              _username = username.text.trim();
                              _name = name.text.trim().isEmpty
                                  ? username.text.trim()
                                  : name.text.trim();
                              _email = email.text.trim();
                              if (ctx.mounted) Navigator.pop(ctx, true);
                            },
                            child: const Text('Save'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    if (saved == true && mounted) setState(() {});
  }

  Future<void> _changePassword() async {
    final oldP = TextEditingController();
    final newP = TextEditingController();
    final confirm = TextEditingController();
    final form = GlobalKey<FormState>();

    bool strong(String s) =>
        RegExp(r'^(?=.*[A-Z])(?=.*[a-z])(?=.*\d).{8,}$').hasMatch(s);

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final kb = MediaQuery.of(ctx).viewInsets.bottom;
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(12, 12, 12, kb + 12),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: form,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(children: [
                          const Text('Change Password',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w800)),
                          const Spacer(),
                          IconButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              icon: const Icon(Icons.close)),
                        ]),
                        const SizedBox(height: 8),
                        _input(
                          controller: oldP,
                          hint: 'Current password',
                          icon: Icons.lock_outline,
                          obscure: true,
                          validator: (v) => v!.trim().isEmpty
                              ? 'Enter current password'
                              : null,
                        ),
                        _input(
                          controller: newP,
                          hint: 'New password',
                          icon: Icons.lock_reset_outlined,
                          obscure: true,
                          validator: (v) => !strong(v!.trim())
                              ? 'At least 8 chars with upper, lower and number'
                              : null,
                        ),
                        _input(
                          controller: confirm,
                          hint: 'Confirm password',
                          icon: Icons.verified_user_outlined,
                          obscure: true,
                          validator: (v) => v!.trim() != newP.text.trim()
                              ? 'Passwords do not match'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kRedSoft,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                            ),
                            onPressed: () async {
                              if (!form.currentState!.validate()) return;

                              final s = await _db()
                                  .child('admins')
                                  .child(_adminId)
                                  .get();
                              final current =
                                  s.child('password').value?.toString() ?? '';
                              if (current.isNotEmpty &&
                                  current != oldP.text.trim()) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'Current password is incorrect')),
                                );
                                return;
                              }
                              await _db()
                                  .child('admins')
                                  .child(_adminId)
                                  .update({'password': newP.text.trim()});
                              if (ctx.mounted) Navigator.pop(ctx, true);
                            },
                            child: const Text('Change'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    if (ok == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password changed successfully')),
      );
    }
  }

  // ====================== UI helpers ======================

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(8, 14, 8, 6),
        child: Text(title,
            style: const TextStyle(
                color: Colors.black54, fontWeight: FontWeight.w700)),
      );

  Widget _tile({
    required IconData icon,
    required String title,
    String? subtitle,
    Color? color,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: kBrownDark.withOpacity(.12),
          child: Icon(icon, color: color ?? kBrownDark),
        ),
        title: Text(title,
            style: TextStyle(
                fontWeight: FontWeight.w700, color: color ?? Colors.black87)),
        subtitle: subtitle == null ? null : Text(subtitle),
        trailing: trailing ?? const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Text('$k: ', style: const TextStyle(fontWeight: FontWeight.w700)),
          Expanded(
              child: Text(v,
                  textAlign: TextAlign.end,
                  style: const TextStyle(color: Colors.black54))),
        ],
      ),
    );
  }

  Widget _input({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboard = TextInputType.text,
    String? Function(String?)? validator,
    bool obscure = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboard,
        obscureText: obscure,
        validator: validator,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon, color: kBrownDark),
          filled: true,
          fillColor: const Color(0xFFF7F7F7),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
          ),
          focusedBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: kGold, width: 2),
          ),
          errorBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: kRedSoft, width: 2),
          ),
          focusedErrorBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: kRedSoft, width: 2),
          ),
          contentPadding:
              const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        ),
      ),
    );
  }
}

/// Simple theme host to switch ThemeMode instantly across the app.
/// Place it above MaterialApp (see usage in the header).
class ThemeControllerHost extends StatefulWidget {
  final ThemeMode initialMode;
  final Widget Function(ValueNotifier<ThemeMode> mode) childBuilder;

  const ThemeControllerHost({
    super.key,
    required this.initialMode,
    required this.childBuilder,
  });

  static _ThemeControllerHostState? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_ThemeScope>()?.state;

  @override
  State<ThemeControllerHost> createState() => _ThemeControllerHostState();
}

class _ThemeControllerHostState extends State<ThemeControllerHost> {
  late final ValueNotifier<ThemeMode> _mode = ValueNotifier(widget.initialMode);

  void setThemeMode(ThemeMode mode) => _mode.value = mode;

  @override
  Widget build(BuildContext context) {
    return _ThemeScope(
      state: this,
      child: widget.childBuilder(_mode),
    );
  }
}

class _ThemeScope extends InheritedWidget {
  final _ThemeControllerHostState state;
  const _ThemeScope({required this.state, required super.child});

  @override
  bool updateShouldNotify(covariant _ThemeScope oldWidget) => false;
}
