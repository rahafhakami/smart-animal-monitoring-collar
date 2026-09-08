// lib/admin/admin_notifications.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;

import '../config.dart';

const kGold = Color(0xFFFFC107);
const kBrown = Color(0xFFD7B899);
const kBrownDark = Color(0xFF8D6E63);
const kRedSoft = Color(0xFFF28B82);

class AdminNotificationsPage extends StatefulWidget {
  const AdminNotificationsPage({super.key});
  @override
  State<AdminNotificationsPage> createState() => _AdminNotificationsPageState();
}

class _AdminNotificationsPageState extends State<AdminNotificationsPage> {
  bool _loading = true;

  // Search & filters
  final _search = TextEditingController();
  String _statusFilter = 'all'; // all | unread | read
  String _typeFilter = 'all'; // all | alert | info | system

  // Data
  final List<_AdminNoti> _all = [];
  final List<_AdminNoti> _view = [];

  // Selection
  final Set<String> _sel = {};

  // Name lookups
  final Map<String, String> _userName = {};

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
    setState(() => _loading = true);

    _all.clear();
    _view.clear();
    _sel.clear();
    _userName.clear();

    // Load users for name resolution (owners + vets)
    final owners = await _db().child('petOwners').get();
    if (owners.exists) {
      for (final c in owners.children) {
        _userName[c.key ?? ''] = c.child('name').value?.toString() ?? '';
      }
    }
    final vets = await _db().child('veterinarians').get();
    if (vets.exists) {
      for (final c in vets.children) {
        _userName[c.key ?? ''] = c.child('name').value?.toString() ?? '';
      }
    }

    final snap = await _db().child('notifications').get();
    if (snap.exists) {
      for (final n in snap.children) {
        _all.add(_AdminNoti.fromSnap(n, _userName));
      }
      // Sort desc by time
      _all.sort((a, b) =>
          (b.when ?? DateTime(1970)).compareTo(a.when ?? DateTime(1970)));
    }

    _applyFilters();
    if (mounted) setState(() => _loading = false);
  }

  void _applyFilters() {
    final q = _search.text.trim().toLowerCase();
    _view
      ..clear()
      ..addAll(_all.where((x) {
        final stOk = _statusFilter == 'all'
            ? true
            : (_statusFilter == 'unread'
                ? x.status == 'unread'
                : x.status == 'read');
        final tpOk =
            _typeFilter == 'all' ? true : x.type.toLowerCase() == _typeFilter;
        final textOk = q.isEmpty ||
            x.title.toLowerCase().contains(q) ||
            x.body.toLowerCase().contains(q) ||
            x.userName.toLowerCase().contains(q) ||
            x.userId.toLowerCase().contains(q) ||
            x.type.toLowerCase().contains(q);
        return stOk && tpOk && textOk;
      }));
    if (mounted) setState(() {});
  }

  // ===== Mutations =====
  Future<void> _markSelected(String to) async {
    if (_sel.isEmpty) return;
    final batch = <Future>[];
    for (final id in _sel) {
      batch.add(_db().child('notifications').child(id).update({'status': to}));
      final i = _all.indexWhere((e) => e.id == id);
      if (i != -1) _all[i] = _all[i].copyWith(status: to);
    }
    await Future.wait(batch);
    _applyFilters();
    _sel.clear();
  }

  Future<void> _deleteSelected() async {
    if (_sel.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete selected?'),
        content: Text('You are about to delete ${_sel.length} notifications.'),
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
    if (ok != true) return;
    final batch = <Future>[];
    for (final id in _sel) {
      batch.add(_db().child('notifications').child(id).remove());
    }
    await Future.wait(batch);
    await _load();
  }

  Future<void> _toggleOne(_AdminNoti n) async {
    final to = n.status == 'unread' ? 'read' : 'unread';
    await _db().child('notifications').child(n.id).update({'status': to});
    final i = _all.indexWhere((e) => e.id == n.id);
    if (i != -1) _all[i] = _all[i].copyWith(status: to);
    _applyFilters();
  }

  Future<void> _deleteOne(_AdminNoti n) async {
    await _db().child('notifications').child(n.id).remove();
    _all.removeWhere((e) => e.id == n.id);
    _applyFilters();
  }

  // ===== Compose / Broadcast =====
  Future<void> _compose() async {
    final title = TextEditingController();
    final body = TextEditingController();
    String type = 'alert';
    String target = 'all'; // all | owners | vets | user
    final userId = TextEditingController();

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final kb = MediaQuery.of(ctx).viewInsets.bottom;
        final h = MediaQuery.of(ctx).size.height;

        // <<< StatefulBuilder to have local setState for the sheet >>>
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
                      child: SingleChildScrollView(
                        physics: const ClampingScrollPhysics(),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(children: [
                              const Text('Create Notification',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800)),
                              const Spacer(),
                              IconButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  icon: const Icon(Icons.close)),
                            ]),
                            const SizedBox(height: 8),
                            _input(
                                controller: title,
                                hint: 'Title',
                                icon: Icons.title),
                            _input(
                                controller: body,
                                hint: 'Message',
                                icon: Icons.message,
                                maxLines: 3),
                            const SizedBox(height: 6),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text('Type',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: Colors.grey[800])),
                            ),
                            const SizedBox(height: 6),
                            Wrap(spacing: 8, children: [
                              _chip(type == 'alert', 'Alert', () {
                                type = 'alert';
                              }, modalSetState),
                              _chip(type == 'info', 'Info', () {
                                type = 'info';
                              }, modalSetState),
                              _chip(type == 'system', 'System', () {
                                type = 'system';
                              }, modalSetState),
                            ]),
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text('Target',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: Colors.grey[800])),
                            ),
                            const SizedBox(height: 6),
                            Wrap(spacing: 8, children: [
                              _chip(target == 'all', 'All Users', () {
                                target = 'all';
                              }, modalSetState),
                              _chip(target == 'owners', 'All Owners', () {
                                target = 'owners';
                              }, modalSetState),
                              _chip(target == 'vets', 'All Vets', () {
                                target = 'vets';
                              }, modalSetState),
                              _chip(target == 'user', 'Specific User', () {
                                target = 'user';
                              }, modalSetState),
                            ]),
                            const SizedBox(height: 6),
                            if (target == 'user')
                              _input(
                                  controller: userId,
                                  hint: 'User ID',
                                  icon: Icons.person_search_outlined),
                            const SizedBox(height: 14),
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
                                  if (title.text.trim().isEmpty ||
                                      body.text.trim().isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              'Title and Message are required')),
                                    );
                                    return;
                                  }

                                  // Build recipients
                                  final ids = <String>[];
                                  if (target == 'user') {
                                    if (userId.text.trim().isEmpty) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                            content:
                                                Text('Please enter a user ID')),
                                      );
                                      return;
                                    }
                                    ids.add(userId.text.trim());
                                  } else if (target == 'owners' ||
                                      target == 'all') {
                                    final o =
                                        await _db().child('petOwners').get();
                                    if (o.exists) {
                                      ids.addAll(o.children
                                          .map((e) => e.key ?? '')
                                          .where((e) => e.isNotEmpty));
                                    }
                                    if (target == 'all') {
                                      final v = await _db()
                                          .child('veterinarians')
                                          .get();
                                      if (v.exists) {
                                        ids.addAll(v.children
                                            .map((e) => e.key ?? '')
                                            .where((e) => e.isNotEmpty));
                                      }
                                    }
                                  } else if (target == 'vets') {
                                    final v = await _db()
                                        .child('veterinarians')
                                        .get();
                                    if (v.exists) {
                                      ids.addAll(v.children
                                          .map((e) => e.key ?? '')
                                          .where((e) => e.isNotEmpty));
                                    }
                                  }

                                  // Write notifications
                                  final now = DateTime.now().toIso8601String();
                                  final tasks = <Future>[];
                                  for (final id in ids) {
                                    tasks.add(_db()
                                        .child('notifications')
                                        .push()
                                        .set({
                                      'title': title.text.trim(),
                                      'body': body.text.trim(),
                                      'type': type,
                                      'status': 'unread',
                                      'timestamp': now,
                                      'userId': id,
                                    }));
                                  }
                                  await Future.wait(tasks);
                                  if (ctx.mounted) Navigator.pop(ctx, true);
                                },
                                child: const Text('Send'),
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
      },
    );

    if (ok == true) await _load();
  }

  // ===== UI =====
  @override
  Widget build(BuildContext context) {
    final inSelection = _sel.isNotEmpty;

    return Scaffold(
      backgroundColor: kBrown,
      appBar: AppBar(
        backgroundColor: kGold,
        foregroundColor: Colors.black87,
        title: Text(inSelection ? '${_sel.length} selected' : 'Notifications'),
        actions: [
          if (!inSelection) ...[
            IconButton(
              tooltip: 'Compose',
              onPressed: _compose,
              icon: const Icon(Icons.add_alert_outlined),
            ),
            IconButton(
              tooltip: 'Refresh',
              onPressed: _load,
              icon: const Icon(Icons.refresh),
            ),
          ] else ...[
            IconButton(
              tooltip: 'Mark as Read',
              onPressed: () => _markSelected('read'),
              icon: const Icon(Icons.mark_email_read_outlined),
            ),
            IconButton(
              tooltip: 'Mark as Unread',
              onPressed: () => _markSelected('unread'),
              icon: const Icon(Icons.mark_email_unread_outlined),
            ),
            IconButton(
              tooltip: 'Delete',
              onPressed: _deleteSelected,
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          // Filters header
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
                    hintText: 'Search title, message, user, type',
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
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _filterChip('all', 'All'),
                      const SizedBox(width: 8),
                      _filterChip('unread', 'Unread'),
                      const SizedBox(width: 8),
                      _filterChip('read', 'Read'),
                      const SizedBox(width: 14),
                      _typeChip('all', 'Any'),
                      const SizedBox(width: 8),
                      _typeChip('alert', 'Alert'),
                      const SizedBox(width: 8),
                      _typeChip('info', 'Info'),
                      const SizedBox(width: 8),
                      _typeChip('system', 'System'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // List
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _view.isEmpty
                    ? const Center(child: Text('No notifications found'))
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _view.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (_, i) => _tile(_view[i]),
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _compose,
        backgroundColor: kRedSoft,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_alert),
        label: const Text('New'),
      ),
    );
  }

  Widget _filterChip(String k, String label) {
    final sel = _statusFilter == k;
    return ChoiceChip(
      label: Text(label),
      selected: sel,
      selectedColor: kGold.withOpacity(.25),
      onSelected: (_) {
        setState(() => _statusFilter = k);
        _applyFilters();
      },
    );
  }

  Widget _typeChip(String k, String label) {
    final sel = _typeFilter == k;
    return ChoiceChip(
      label: Text('Type: $label'),
      selected: sel,
      selectedColor: kGold.withOpacity(.25),
      onSelected: (_) {
        setState(() => _typeFilter = k);
        _applyFilters();
      },
    );
  }

  Widget _tile(_AdminNoti n) {
    final selected = _sel.contains(n.id);
    final isUnread = n.status == 'unread';
    final c = switch (n.type) {
      'alert' => Colors.orange,
      'system' => Colors.blueGrey,
      'info' => Colors.blue,
      _ => Colors.grey,
    };

    return GestureDetector(
      onLongPress: () {
        setState(() {
          if (selected) {
            _sel.remove(n.id);
          } else {
            _sel.add(n.id);
          }
        });
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? kGold : Colors.black12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.06),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ListTile(
          leading: selected
              ? CircleAvatar(
                  backgroundColor: kGold,
                  child: const Icon(Icons.check, color: Colors.black87),
                )
              : CircleAvatar(
                  backgroundColor: c.withOpacity(.12),
                  child: Icon(
                    n.type == 'alert'
                        ? Icons.notifications_active_outlined
                        : n.type == 'system'
                            ? Icons.settings_outlined
                            : Icons.info_outline,
                    color: c,
                  ),
                ),
          title: Row(
            children: [
              Flexible(
                child: Text(
                  n.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: isUnread ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              if (isUnread)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.orange.withOpacity(.4)),
                  ),
                  child: const Text('Unread',
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.orange,
                          fontWeight: FontWeight.w700)),
                ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(n.body, maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Text(
                '${n.userName.isEmpty ? n.userId : n.userName} • ${n.type.toUpperCase()} • ${n.whenLabel}',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
          trailing: PopupMenuButton<String>(
            onSelected: (v) async {
              switch (v) {
                case 'open':
                  _openDetails(n);
                  break;
                case 'toggle':
                  await _toggleOne(n);
                  break;
                case 'copyid':
                  await Clipboard.setData(ClipboardData(text: n.id));
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('ID copied to clipboard')));
                  }
                  break;
                case 'delete':
                  await _deleteOne(n);
                  break;
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                  value: 'open',
                  child: ListTile(
                      leading: Icon(Icons.visibility), title: Text('Open'))),
              PopupMenuItem(
                  value: 'toggle',
                  child: ListTile(
                    leading: Icon(isUnread
                        ? Icons.mark_email_read
                        : Icons.mark_email_unread),
                    title: Text(isUnread ? 'Mark as read' : 'Mark as unread'),
                  )),
              const PopupMenuItem(
                  value: 'copyid',
                  child: ListTile(
                      leading: Icon(Icons.copy_all_outlined),
                      title: Text('Copy ID'))),
              const PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                      leading: Icon(Icons.delete_outline),
                      title: Text('Delete'))),
            ],
          ),
          onTap: () {
            if (_sel.isNotEmpty) {
              setState(() {
                if (selected) {
                  _sel.remove(n.id);
                } else {
                  _sel.add(n.id);
                }
              });
            } else {
              _openDetails(n);
            }
          },
        ),
      ),
    );
  }

  void _openDetails(_AdminNoti n) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final h = MediaQuery.of(ctx).size.height;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: h * .85),
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(children: [
                          const Text('Notification',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w800)),
                          const Spacer(),
                          IconButton(
                              onPressed: () => Navigator.pop(ctx),
                              icon: const Icon(Icons.close)),
                        ]),
                        const SizedBox(height: 8),
                        _kv('ID', n.id),
                        _kv(
                            'User',
                            n.userName.isEmpty
                                ? n.userId
                                : '${n.userName} (${n.userId})'),
                        _kv('Type', n.type.toUpperCase()),
                        _kv('Status', n.status),
                        _kv('Timestamp', n.timestamp),
                        const SizedBox(height: 8),
                        Align(
                            alignment: Alignment.centerLeft,
                            child: Text('Title',
                                style: TextStyle(fontWeight: FontWeight.w700))),
                        const SizedBox(height: 6),
                        _bubble(n.title),
                        const SizedBox(height: 8),
                        Align(
                            alignment: Alignment.centerLeft,
                            child: Text('Message',
                                style: TextStyle(fontWeight: FontWeight.w700))),
                        const SizedBox(height: 6),
                        _bubble(n.body),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: Icon(n.status == 'unread'
                                    ? Icons.mark_email_read
                                    : Icons.mark_email_unread),
                                label: Text(n.status == 'unread'
                                    ? 'Mark as read'
                                    : 'Mark as unread'),
                                onPressed: () async {
                                  await _toggleOne(n);
                                  if (ctx.mounted) Navigator.pop(ctx);
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: kRedSoft,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                                icon: const Icon(Icons.delete_outline),
                                label: const Text('Delete'),
                                onPressed: () async {
                                  await _deleteOne(n);
                                  if (ctx.mounted) Navigator.pop(ctx);
                                },
                              ),
                            ),
                          ],
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
  }

  // Small helpers
  static Widget _chip(bool sel, String label, VoidCallback set,
      void Function(void Function()) updater) {
    return ChoiceChip(
      label: Text(label),
      selected: sel,
      selectedColor: kGold.withOpacity(.25),
      onSelected: (_) => updater(() => set()),
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

  static Widget _bubble(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Text(text),
    );
  }

  static Widget _input({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
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
          contentPadding:
              const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        ),
      ),
    );
  }
}

// ===== Model =====
class _AdminNoti {
  final String id;
  final String title;
  final String body;
  final String type; // alert/info/system/...
  final String status; // unread/read
  final String userId;
  final String userName;
  final String timestamp;
  final DateTime? when;

  _AdminNoti({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.status,
    required this.userId,
    required this.userName,
    required this.timestamp,
    required this.when,
  });

  factory _AdminNoti.fromSnap(DataSnapshot s, Map<String, String> names) {
    final ts = s.child('timestamp').value?.toString() ?? '';
    DateTime? when;
    try {
      when = DateTime.tryParse(ts)?.toLocal();
    } catch (_) {}
    final uid = s.child('userId').value?.toString() ?? '';
    return _AdminNoti(
      id: s.key ?? '',
      title: s.child('title').value?.toString() ?? '',
      body: s.child('body').value?.toString() ?? '',
      type: (s.child('type').value?.toString() ?? 'alert').toLowerCase(),
      status: (s.child('status').value?.toString() ?? 'unread').toLowerCase(),
      userId: uid,
      userName: names[uid] ?? '',
      timestamp: ts,
      when: when,
    );
  }

  _AdminNoti copyWith({String? status}) => _AdminNoti(
        id: id,
        title: title,
        body: body,
        type: type,
        status: status ?? this.status,
        userId: userId,
        userName: userName,
        timestamp: timestamp,
        when: when,
      );

  String get whenLabel {
    if (when == null) return '-';
    final now = DateTime.now();
    final diff = now.difference(when!);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${when!.year}-${when!.month.toString().padLeft(2, '0')}-${when!.day.toString().padLeft(2, '0')}';
  }
}
