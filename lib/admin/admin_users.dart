// lib/admin/admin_users.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import '../config.dart';

const kGold = Color(0xFFFFC107);
const kBrown = Color(0xFFD7B899);
const kBrownDark = Color(0xFF8D6E63);
const kRedSoft = Color(0xFFF28B82);

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key});
  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  bool _loading = true;

  final _search = TextEditingController();
  String _statusFilter = 'all';

  List<_Owner> _all = [];
  List<_Owner> _view = [];

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
    _search.addListener(_applyFilters);
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    await _ensure();
    final snap = await _db().child('petOwners').get();

    final list = <_Owner>[];
    if (snap.exists) {
      for (final c in snap.children) {
        list.add(_Owner.fromSnap(c));
      }
    }

    setState(() {
      _all = list;
      _applyFilters();
      _loading = false;
    });
  }

  void _applyFilters() {
    final q = _search.text.trim().toLowerCase();
    _view = _all.where((o) {
      final statusOk = _statusFilter == 'all'
          ? true
          : o.status.toLowerCase() == _statusFilter;
      final textOk = q.isEmpty ||
          o.name.toLowerCase().contains(q) ||
          o.email.toLowerCase().contains(q) ||
          o.phone.toLowerCase().contains(q) ||
          o.address.toLowerCase().contains(q);
      return statusOk && textOk;
    }).toList();
    setState(() {});
  }

  // ========= Validation helpers =========
  bool _isEmail(String s) =>
      RegExp(r'^[\w\.\-]+@([\w\-]+\.)+[\w\-]{2,}$').hasMatch(s);
  bool _isPhone(String s) => RegExp(r'^\+?\d{8,15}$').hasMatch(s);

  /// Checks for duplicate email among owners (local list) and vets (DB).
  /// - Tries a fast indexed query first (emailLower or email).
  /// - If rules don't have `.indexOn`, falls back to a full scan to avoid crash.
  Future<bool> _emailExistsAnywhere(String email,
      {String? exceptOwnerId}) async {
    final e = email.trim().toLowerCase();

    // Check owners already loaded in memory
    for (final o in _all) {
      if (exceptOwnerId != null && o.id == exceptOwnerId) continue;
      if (o.email.toLowerCase() == e) return true;
    }

    // Try a case-insensitive indexed query first (preferred if you store emailLower)
    try {
      final byLower = await _db()
          .child('veterinarians')
          .orderByChild('emailLower')
          .equalTo(e)
          .get();
      if (byLower.exists) return true;
    } on FirebaseException {
      // ignore here; we'll try the plain email or fallback scan
    }

    // Try plain email (may require .indexOn "email" in rules)
    try {
      final byEmail = await _db()
          .child('veterinarians')
          .orderByChild('email')
          .equalTo(email)
          .get();
      if (byEmail.exists) return true;
    } on FirebaseException {
      // Index not defined → fallback to full scan (safe, works without indexes)
      final vSnap = await _db().child('veterinarians').get();
      if (vSnap.exists) {
        for (final c in vSnap.children) {
          final ve = ((c.child('emailLower').value ??
                  c.child('email').value ??
                  '') as Object)
              .toString()
              .toLowerCase();
          if (ve == e) return true;
        }
      }
    }

    return false;
  }

  // ========= Add / Edit =========
  Future<void> _addOrEdit({_Owner? owner}) async {
    final name = TextEditingController(text: owner?.name ?? '');
    final email = TextEditingController(text: owner?.email ?? '');
    final phone = TextEditingController(text: owner?.phone ?? '');
    final address = TextEditingController(text: owner?.address ?? '');
    String status = owner?.status.isNotEmpty == true ? owner!.status : 'active';

    final key = GlobalKey<FormState>();

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final kb = MediaQuery.of(ctx).viewInsets.bottom;
        final h = MediaQuery.of(ctx).size.height;
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(12, 12, 12, kb + 12),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: h * .92),
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: key,
                    child: SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Text(
                                owner == null ? 'Add User' : 'Edit User',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                icon: const Icon(Icons.close),
                              )
                            ],
                          ),
                          const SizedBox(height: 8),
                          _field(
                            controller: name,
                            hint: 'Full name',
                            icon: Icons.person_outline,
                            validator: (v) => v!.trim().length < 3
                                ? 'Enter a valid name'
                                : null,
                          ),
                          _field(
                            controller: email,
                            hint: 'Email',
                            icon: Icons.email_outlined,
                            keyboard: TextInputType.emailAddress,
                            validator: (v) => !_isEmail(v!.trim())
                                ? 'Enter a valid email'
                                : null,
                          ),
                          _field(
                            controller: phone,
                            hint: 'Phone (+9665...)',
                            icon: Icons.phone_outlined,
                            keyboard: TextInputType.phone,
                            validator: (v) => !_isPhone(v!.trim())
                                ? 'Enter a valid phone'
                                : null,
                          ),
                          _field(
                            controller: address,
                            hint: 'Address',
                            icon: Icons.location_on_outlined,
                            validator: (v) =>
                                v!.trim().isEmpty ? 'Enter address' : null,
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text('Status',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ChoiceChip(
                                label: const Text('Active'),
                                selected: status == 'active',
                                selectedColor: kGold.withOpacity(.25),
                                onSelected: (_) =>
                                    setState(() => status = 'active'),
                              ),
                              ChoiceChip(
                                label: const Text('Inactive'),
                                selected: status == 'inactive',
                                selectedColor: kGold.withOpacity(.25),
                                onSelected: (_) =>
                                    setState(() => status = 'inactive'),
                              ),
                              ChoiceChip(
                                label: const Text('Blocked'),
                                selected: status == 'blocked',
                                selectedColor: kGold.withOpacity(.25),
                                onSelected: (_) =>
                                    setState(() => status = 'blocked'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: kRedSoft,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              onPressed: () async {
                                if (!key.currentState!.validate()) return;

                                // Unique email check (owners + vets)
                                final dupe = await _emailExistsAnywhere(
                                  email.text.trim(),
                                  exceptOwnerId: owner?.id,
                                );
                                if (dupe) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Email already exists in system',
                                        ),
                                      ),
                                    );
                                  }
                                  return;
                                }

                                final data = {
                                  'name': name.text.trim(),
                                  'email': email.text.trim(),
                                  'emailLower': email.text.trim().toLowerCase(),
                                  'phone': phone.text.trim(),
                                  'address': address.text.trim(),
                                  'role': 'pet_owner',
                                  'status': status,
                                  'createdAt': owner?.createdAt ??
                                      DateTime.now().toIso8601String(),
                                };

                                if (owner == null) {
                                  await _db()
                                      .child('petOwners')
                                      .push()
                                      .set(data);
                                } else {
                                  await _db()
                                      .child('petOwners')
                                      .child(owner.id)
                                      .update(data);
                                }
                                if (ctx.mounted) Navigator.pop(ctx, true);
                              },
                              child: Text(
                                owner == null ? 'Add User' : 'Save Changes',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    if (saved == true) await _load();
  }

  Future<void> _delete(_Owner o) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete User'),
        content: Text('Delete ${o.name}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) {
      await _db().child('petOwners').child(o.id).remove();
      await _load();
    }
  }

  Future<void> _setStatus(_Owner o, String status) async {
    await _db().child('petOwners').child(o.id).update({'status': status});
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBrown,
      appBar: AppBar(
        backgroundColor: kGold,
        foregroundColor: Colors.black87,
        title: const Text('Users'),
        actions: [
          IconButton(
              onPressed: () => _addOrEdit(),
              icon: const Icon(Icons.person_add_alt_1)),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
            ),
            child: Column(
              children: [
                TextField(
                  controller: _search,
                  decoration: InputDecoration(
                    hintText: 'Search name, email, phone, address',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: const Color(0xFFF7F7F7),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _filterChip('all', 'All'),
                    const SizedBox(width: 8),
                    _filterChip('active', 'Active'),
                    const SizedBox(width: 8),
                    _filterChip('inactive', 'Inactive'),
                    const SizedBox(width: 8),
                    _filterChip('blocked', 'Blocked'),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _view.isEmpty
                    ? const Center(child: Text('No users found'))
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _view.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (_, i) => _card(_view[i]),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addOrEdit(),
        backgroundColor: kRedSoft,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
    );
  }

  Widget _filterChip(String key, String label) {
    final sel = _statusFilter == key;
    return ChoiceChip(
      label: Text(label),
      selected: sel,
      selectedColor: kGold.withOpacity(.25),
      onSelected: (_) {
        setState(() => _statusFilter = key);
        _applyFilters();
      },
    );
  }

  Widget _card(_Owner o) {
    Color badgeColor;
    switch (o.status.toLowerCase()) {
      case 'active':
        badgeColor = Colors.green;
        break;
      case 'blocked':
        badgeColor = Colors.red;
        break;
      default:
        badgeColor = Colors.orange;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.06),
            blurRadius: 12,
            offset: const Offset(0, 6),
          )
        ],
        border: Border.all(color: Colors.black12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: kBrownDark.withOpacity(.15),
                  child: const Icon(Icons.person_outline, color: kBrownDark),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(o.name,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text(o.email,
                          style: const TextStyle(
                              fontSize: 12, color: Colors.black54)),
                      Text(o.phone,
                          style: const TextStyle(
                              fontSize: 12, color: Colors.black54)),
                      Text(o.address,
                          style: const TextStyle(
                              fontSize: 12, color: Colors.black54)),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeColor.withOpacity(.1),
                    borderRadius: BorderRadius.circular(50),
                    border: Border.all(color: badgeColor.withOpacity(.4)),
                  ),
                  child: Text(
                    o.status,
                    style: TextStyle(
                      color: badgeColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.lock_open_outlined),
                    label: const Text('Activate'),
                    onPressed: o.status == 'active'
                        ? null
                        : () => _setStatus(o, 'active'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.block),
                    label: const Text('Block'),
                    onPressed: o.status == 'blocked'
                        ? null
                        : () => _setStatus(o, 'blocked'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kGold,
                      foregroundColor: Colors.black87,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => _addOrEdit(owner: o),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Delete'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kRedSoft,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => _delete(o),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboard = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboard,
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

class _Owner {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String address;
  final String status;
  final String createdAt;

  _Owner({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.address,
    required this.status,
    required this.createdAt,
  });

  factory _Owner.fromSnap(DataSnapshot s) => _Owner(
        id: s.key ?? '',
        name: s.child('name').value?.toString() ?? '',
        email: s.child('email').value?.toString() ?? '',
        phone: s.child('phone').value?.toString() ?? '',
        address: s.child('address').value?.toString() ?? '',
        status: s.child('status').value?.toString() ?? 'active',
        createdAt: s.child('createdAt').value?.toString() ?? '',
      );
}
