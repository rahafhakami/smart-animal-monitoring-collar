// lib/admin/admin_providers.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import '../config.dart';

const kGold = Color(0xFFFFC107);
const kBrown = Color(0xFFD7B899);
const kBrownDark = Color(0xFF8D6E63);
const kRedSoft = Color(0xFFF28B82);

class AdminProvidersPage extends StatefulWidget {
  final bool showPending;
  const AdminProvidersPage({super.key, this.showPending = false});

  @override
  State<AdminProvidersPage> createState() => _AdminProvidersPageState();
}

class _AdminProvidersPageState extends State<AdminProvidersPage> {
  bool _loading = true;
  final _search = TextEditingController();
  String _statusFilter = 'all';

  List<_Vet> _all = [];
  List<_Vet> _filtered = [];

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
    if (widget.showPending) _statusFilter = 'pending';
    _search.addListener(_applyFilter);
    _load();
  }

  @override
  void dispose() {
    _search.removeListener(_applyFilter);
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    await _ensure();
    final snap = await _db().child('veterinarians').get();

    final list = <_Vet>[];
    if (snap.exists) {
      for (final c in snap.children) {
        final addr = c.child('address');
        list.add(
          _Vet(
            id: c.key ?? '',
            name: c.child('name').value?.toString() ?? '',
            email: c.child('email').value?.toString() ?? '',
            phone: c.child('phone').value?.toString() ?? '',
            clinic: c.child('clinic').value?.toString() ?? '',
            licenseNo: c.child('licenseNo').value?.toString() ?? '',
            status: c.child('status').value?.toString() ?? 'pending',
            createdAt: c.child('createdAt').value?.toString() ?? '',
            city: addr.child('city').value?.toString() ?? '',
            district: addr.child('district').value?.toString() ?? '',
            street: addr.child('street').value?.toString() ?? '',
            landmark: addr.child('landmark').value?.toString() ?? '',
          ),
        );
      }
    }

    if (!mounted) return;
    setState(() {
      _all = list;
      _filtered = List<_Vet>.from(list);
      _loading = false;
    });

    if (mounted) _applyFilter();
  }

  void _applyFilter() {
    if (!mounted) return;
    final q = _search.text.trim().toLowerCase();
    setState(() {
      _filtered = _all.where((v) {
        final statusOk = _statusFilter == 'all'
            ? true
            : v.status.toLowerCase() == _statusFilter;
        final terms = [
          v.name,
          v.email,
          v.phone,
          v.clinic,
          v.licenseNo,
          v.city,
          v.district,
          v.street,
          v.landmark,
        ].map((e) => e.toLowerCase()).toList();
        final textOk = q.isEmpty || terms.any((t) => t.contains(q));
        return statusOk && textOk;
      }).toList();
    });
  }

  bool _isEmail(String s) =>
      RegExp(r'^[\w\.\-]+@([\w\-]+\.)+[\w\-]{2,}$').hasMatch(s.trim());
  bool _isPhone(String s) => RegExp(r'^\+?\d{10,15}$').hasMatch(s.trim());
  bool _isLicense(String s) =>
      RegExp(r'^[A-Za-z0-9\-_]{3,}$').hasMatch(s.trim());

  Future<bool> _emailOrLicenseExists(String email, String license,
      {String? exceptId}) async {
    for (final v in _all) {
      if (exceptId != null && v.id == exceptId) continue;
      if (v.email.toLowerCase() == email.toLowerCase()) return true;
      if (v.licenseNo.toLowerCase() == license.toLowerCase()) return true;
    }
    return false;
  }

  Future<void> _addOrEdit({_Vet? vet}) async {
    final name = TextEditingController(text: vet?.name ?? '');
    final email = TextEditingController(text: vet?.email ?? '');
    final phone = TextEditingController(text: vet?.phone ?? '');
    final clinicName = TextEditingController(text: vet?.clinic ?? '');
    final license = TextEditingController(text: vet?.licenseNo ?? '');

    final city = TextEditingController(text: vet?.city ?? '');
    final district = TextEditingController(text: vet?.district ?? '');
    final street = TextEditingController(text: vet?.street ?? '');
    final landmark = TextEditingController(text: vet?.landmark ?? '');

    String status = vet?.status ?? 'pending';
    final key = GlobalKey<FormState>();

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final kb = MediaQuery.of(ctx).viewInsets.bottom;
        final h = MediaQuery.of(ctx).size.height;

        // <<< مهم: نستخدم StatefulBuilder لتحديث حالة الشيب داخل الـsheet >>>
        return StatefulBuilder(
          builder: (ctx, modalSetState) {
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
                              Row(children: [
                                Text(
                                  vet == null
                                      ? 'Add Provider'
                                      : 'Edit Provider',
                                  style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800),
                                ),
                                const Spacer(),
                                IconButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  icon: const Icon(Icons.close),
                                ),
                              ]),
                              const SizedBox(height: 8),
                              _field(
                                controller: name,
                                hint: 'Full name',
                                icon: Icons.person_outline,
                                validator: (v) =>
                                    v == null || v.trim().length < 3
                                        ? 'Enter valid name'
                                        : null,
                              ),
                              _field(
                                controller: email,
                                hint: 'Email',
                                icon: Icons.email_outlined,
                                keyboard: TextInputType.emailAddress,
                                validator: (v) => v == null || !_isEmail(v)
                                    ? 'Enter valid email'
                                    : null,
                              ),
                              _field(
                                controller: phone,
                                hint: 'Phone (+9665...)',
                                icon: Icons.phone_outlined,
                                keyboard: TextInputType.phone,
                                validator: (v) => v == null || !_isPhone(v)
                                    ? 'Enter valid phone'
                                    : null,
                              ),
                              _field(
                                controller: clinicName,
                                hint: 'Clinic name',
                                icon: Icons.local_hospital_outlined,
                                validator: (v) => v == null || v.trim().isEmpty
                                    ? 'Enter clinic name'
                                    : null,
                              ),
                              _field(
                                controller: license,
                                hint: 'License No',
                                icon: Icons.badge_outlined,
                                validator: (v) => v == null || !_isLicense(v)
                                    ? 'Enter valid license'
                                    : null,
                              ),
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text('Clinic Address',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700)),
                              ),
                              const SizedBox(height: 8),
                              _field(
                                controller: city,
                                hint: 'City',
                                icon: Icons.location_city_outlined,
                                validator: (v) => v == null || v.trim().isEmpty
                                    ? 'Enter city'
                                    : null,
                              ),
                              _field(
                                controller: district,
                                hint: 'District / Area',
                                icon: Icons.map_outlined,
                                validator: (v) => v == null || v.trim().isEmpty
                                    ? 'Enter district/area'
                                    : null,
                              ),
                              _field(
                                controller: street,
                                hint: 'Street',
                                icon: Icons.route_outlined,
                                validator: (v) => v == null || v.trim().isEmpty
                                    ? 'Enter street'
                                    : null,
                              ),
                              _field(
                                controller: landmark,
                                hint: 'Nearby landmark (optional)',
                                icon: Icons.landscape_outlined,
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
                                    label: const Text('Pending'),
                                    selected: status == 'pending',
                                    selectedColor: kGold.withOpacity(.25),
                                    onSelected: (_) =>
                                        modalSetState(() => status = 'pending'),
                                  ),
                                  ChoiceChip(
                                    label: const Text('Approved'),
                                    selected: status == 'approved',
                                    selectedColor: kGold.withOpacity(.25),
                                    onSelected: (_) => modalSetState(
                                        () => status = 'approved'),
                                  ),
                                  ChoiceChip(
                                    label: const Text('Rejected'),
                                    selected: status == 'rejected',
                                    selectedColor: kGold.withOpacity(.25),
                                    onSelected: (_) => modalSetState(
                                        () => status = 'rejected'),
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
                                    if (await _emailOrLicenseExists(
                                      email.text.trim(),
                                      license.text.trim(),
                                      exceptId: vet?.id,
                                    )) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                              'Email or License already exists'),
                                        ),
                                      );
                                      return;
                                    }
                                    final data = {
                                      'name': name.text.trim(),
                                      'email': email.text.trim(),
                                      'phone': phone.text.trim(),
                                      'clinic': clinicName.text.trim(),
                                      'licenseNo': license.text.trim(),
                                      'role': 'veterinarian',
                                      'status': status,
                                      'createdAt': vet?.createdAt ??
                                          DateTime.now().toIso8601String(),
                                      'address': {
                                        'city': city.text.trim(),
                                        'district': district.text.trim(),
                                        'street': street.text.trim(),
                                        'landmark': landmark.text.trim(),
                                      },
                                    };
                                    await _ensure();
                                    if (vet == null) {
                                      await _db()
                                          .child('veterinarians')
                                          .push()
                                          .set(data);
                                    } else {
                                      await _db()
                                          .child('veterinarians')
                                          .child(vet.id)
                                          .update(data);
                                    }
                                    if (ctx.mounted) Navigator.pop(ctx, true);
                                  },
                                  child: Text(
                                    vet == null
                                        ? 'Add Provider'
                                        : 'Save Changes',
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
      },
    );

    if (saved == true && mounted) await _load();
  }

  Future<void> _delete(_Vet v) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete Provider'),
        content: Text('Delete ${v.name}?'),
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
      await _ensure();
      await _db().child('veterinarians').child(v.id).remove();
      if (mounted) await _load();
    }
  }

  Future<void> _setStatus(_Vet v, String status) async {
    await _ensure();
    await _db().child('veterinarians').child(v.id).update({'status': status});
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBrown,
      appBar: AppBar(
        backgroundColor: kGold,
        foregroundColor: Colors.black87,
        title: const Text('Providers'),
        actions: [
          IconButton(
              onPressed: () => _addOrEdit(), icon: const Icon(Icons.add)),
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
                    hintText: 'Search name, email, clinic, license',
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
                    _filterChip('pending', 'Pending'),
                    const SizedBox(width: 8),
                    _filterChip('approved', 'Approved'),
                    const SizedBox(width: 8),
                    _filterChip('rejected', 'Rejected'),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                    ? const Center(child: Text('No providers found'))
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (_, i) => _card(_filtered[i]),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addOrEdit(),
        backgroundColor: kRedSoft,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_alt_1),
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
        _applyFilter();
      },
    );
  }

  Widget _card(_Vet v) {
    Color badgeColor;
    switch (v.status.toLowerCase()) {
      case 'approved':
        badgeColor = Colors.green;
        break;
      case 'rejected':
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
          ),
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
                  child: const Icon(
                    Icons.medical_information_outlined,
                    color: kBrownDark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(v.name,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text('${v.clinic} • ${v.licenseNo}',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.black54)),
                      Text(v.email,
                          style: const TextStyle(
                              fontSize: 12, color: Colors.black54)),
                      Text(v.phone,
                          style: const TextStyle(
                              fontSize: 12, color: Colors.black54)),
                      if (v.city.isNotEmpty || v.street.isNotEmpty)
                        Text(
                          '${v.street}, ${v.district}, ${v.city}${v.landmark.isNotEmpty ? " • near ${v.landmark}" : ""}',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.black54),
                        ),
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
                    v.status,
                    style: TextStyle(
                        color: badgeColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Approve'),
                    onPressed: v.status == 'approved'
                        ? null
                        : () => _setStatus(v, 'approved'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.block),
                    label: const Text('Reject'),
                    onPressed: v.status == 'rejected'
                        ? null
                        : () => _setStatus(v, 'rejected'),
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
                    onPressed: () => _addOrEdit(vet: v),
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
                    onPressed: () => _delete(v),
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

class _Vet {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String clinic;
  final String licenseNo;
  final String status;
  final String createdAt;
  final String city;
  final String district;
  final String street;
  final String landmark;

  _Vet({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.clinic,
    required this.licenseNo,
    required this.status,
    required this.createdAt,
    required this.city,
    required this.district,
    required this.street,
    required this.landmark,
  });

  factory _Vet.fromSnap(DataSnapshot s) {
    final a = s.child('address');
    return _Vet(
      id: s.key ?? '',
      name: s.child('name').value?.toString() ?? '',
      email: s.child('email').value?.toString() ?? '',
      phone: s.child('phone').value?.toString() ?? '',
      clinic: s.child('clinic').value?.toString() ?? '',
      licenseNo: s.child('licenseNo').value?.toString() ?? '',
      status: s.child('status').value?.toString() ?? 'pending',
      createdAt: s.child('createdAt').value?.toString() ?? '',
      city: a.child('city').value?.toString() ?? '',
      district: a.child('district').value?.toString() ?? '',
      street: a.child('street').value?.toString() ?? '',
      landmark: a.child('landmark').value?.toString() ?? '',
    );
  }
}
