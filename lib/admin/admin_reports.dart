// lib/admin/admin_reports.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import '../config.dart';

const kGold = Color(0xFFFFC107);
const kBrown = Color(0xFFD7B899);
const kBrownDark = Color(0xFF8D6E63);
const kRedSoft = Color(0xFFF28B82);

class AdminReportsPage extends StatefulWidget {
  const AdminReportsPage({super.key});
  @override
  State<AdminReportsPage> createState() => _AdminReportsPageState();
}

class _AdminReportsPageState extends State<AdminReportsPage> {
  bool _loading = true;

  // Range & searching
  int _rangeDays = 7; // 7 / 30 / 90
  final _recSearch = TextEditingController();
  String _recStatusFilter = 'all';

  // Totals / KPIs
  int totalPets = 0, totalCollars = 0, totalOwners = 0, totalVets = 0;
  int totalAlerts = 0, totalAppts = 0, totalMsgs = 0;
  int totalRecords = 0, openRecords = 0, closedRecords = 0;

  // Health aggregates
  double avgHeart = 0, avgTemp = 0, avgActivity = 0, minBattery = 0;
  List<double> heart24h = [];

  // Weekly engagement (appointments + notifications + messages)
  List<double> weeklyEngagement = List.filled(7, 0);

  // Health records list
  final List<_HealthRecord> _records = [];
  final List<_HealthRecord> _recordsView = [];

  // name lookup
  final Map<String, String> _petName = {};
  final Map<String, String> _ownerName = {};
  final Map<String, String> _vetName = {};

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
    _recSearch.addListener(_applyRecordFilters);
    _load();
  }

  @override
  void dispose() {
    _recSearch.dispose();
    super.dispose();
  }

  DateTime _startDate() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: _rangeDays - 1));
    return start;
  }

  int _dayIndex(DateTime t) {
    final start = _startDate();
    final d = DateTime(t.year, t.month, t.day).difference(start).inDays;
    return d.clamp(0, 6);
  }

  DateTime? _parseISO(String? s) {
    if (s == null || s.isEmpty) return null;
    try {
      return DateTime.tryParse(s)?.toLocal();
    } catch (_) {
      return null;
    }
  }

  void _applyRecordFilters() {
    final q = _recSearch.text.trim().toLowerCase();
    _recordsView
      ..clear()
      ..addAll(_records.where((r) {
        final stOk = _recStatusFilter == 'all'
            ? true
            : r.status.toLowerCase() == _recStatusFilter;
        final terms = [
          r.petName,
          r.ownerName,
          r.vetName,
          r.diagnosis,
          r.treatment,
          r.notes,
        ].map((e) => e.toLowerCase());
        final textOk = q.isEmpty || terms.any((t) => t.contains(q));
        return stOk && textOk;
      }));
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    await _ensure();
    if (mounted) setState(() => _loading = true);

    final db = _db();
    final start = _startDate();

    final ownersSnap = await db.child('petOwners').get();
    final vetsSnap = await db.child('veterinarians').get();
    final petsSnap = await db.child('pets').get();
    final collarsSnap = await db.child('bioCollars').get();
    final recsSnap = await db.child('healthRecords').get();
    final apptsSnap = await db.child('appointments').get();
    final notiSnap = await db.child('notifications').get();
    final msgSnap = await db.child('messages').get();

    // lookups
    _petName.clear();
    _ownerName.clear();
    _vetName.clear();

    if (ownersSnap.exists) {
      totalOwners = ownersSnap.children.length;
      for (final c in ownersSnap.children) {
        _ownerName[c.key ?? ''] = c.child('name').value?.toString() ?? '';
      }
    }

    if (vetsSnap.exists) {
      totalVets = vetsSnap.children.length;
      for (final c in vetsSnap.children) {
        _vetName[c.key ?? ''] = c.child('name').value?.toString() ?? '';
      }
    }

    if (petsSnap.exists) {
      totalPets = petsSnap.children.length;
      for (final c in petsSnap.children) {
        _petName[c.key ?? ''] = c.child('name').value?.toString() ?? '';
      }
    }

    // Collars + readings aggregates
    totalCollars = collarsSnap.children.length;
    totalAlerts = notiSnap.children.length;
    totalAppts = apptsSnap.children.length;
    totalMsgs = msgSnap.children.length;

    weeklyEngagement = List.filled(7, 0);
    heart24h = [];
    double hrSum = 0, hrCount = 0;
    double tSum = 0, tCount = 0;
    double actSum = 0, actCount = 0;
    double minBat = 999;

    // Collect last-24 points by timestamp to draw sparkline nicely
    final List<_Point> recentHr = [];

    if (collarsSnap.exists) {
      for (final col in collarsSnap.children) {
        final b = double.tryParse(col.child('battery').value?.toString() ?? '');
        if (b != null) minBat = minBat == 999 ? b : (b < minBat ? b : minBat);

        final readings = col.child('readings');
        if (readings.exists) {
          for (final r in readings.children) {
            final at = _parseISO(r.child('at').value?.toString());
            final hr =
                double.tryParse(r.child('heartRate').value?.toString() ?? '');
            final tc = double.tryParse(
                r.child('temperatureC').value?.toString() ?? '');
            final al = double.tryParse(
                r.child('activityLevel').value?.toString() ?? '');

            if (hr != null) {
              hrSum += hr;
              hrCount += 1;
              if (at != null &&
                  at.isAfter(
                      DateTime.now().subtract(const Duration(hours: 24)))) {
                recentHr.add(_Point(at, hr));
              }
            }
            if (tc != null) {
              tSum += tc;
              tCount += 1;
            }
            if (al != null) {
              actSum += al;
              actCount += 1;
            }
          }
        }
      }
    }

    // Sort sparkline points by time
    recentHr.sort((a, b) => a.t.compareTo(b.t));
    heart24h = recentHr.map((e) => e.v).toList();
    if (heart24h.length > 40) {
      final step = (heart24h.length / 40).ceil();
      final tmp = <double>[];
      for (int i = 0; i < heart24h.length; i += step) {
        tmp.add(heart24h[i]);
      }
      heart24h = tmp;
    }

    avgHeart = hrCount == 0 ? 0 : hrSum / hrCount;
    avgTemp = tCount == 0 ? 0 : tSum / tCount;
    avgActivity = actCount == 0 ? 0 : actSum / actCount;
    minBattery = minBat == 999 ? 0 : minBat;

    // Engagement aggregation (appointments + notifications + messages)
    if (apptsSnap.exists) {
      for (final a in apptsSnap.children) {
        final d = a.child('date').value?.toString();
        final t = a.child('time').value?.toString();
        DateTime? at;
        if (d != null && t != null) at = _parseISO('${d}T${t}:00'); // fixed

        if (at != null && at.isAfter(start)) {
          weeklyEngagement[_dayIndex(at)] += 1;
        }
      }
    }
    if (notiSnap.exists) {
      for (final n in notiSnap.children) {
        final at = _parseISO(n.child('timestamp').value?.toString());
        if (at != null && at.isAfter(start)) {
          weeklyEngagement[_dayIndex(at)] += 1;
        }
      }
    }
    if (msgSnap.exists) {
      for (final m in msgSnap.children) {
        final at = _parseISO(m.child('timestamp').value?.toString());
        if (at != null && at.isAfter(start)) {
          weeklyEngagement[_dayIndex(at)] += 1;
        }
      }
    }

    // Health Records
    _records.clear();
    totalRecords = 0;
    openRecords = 0;
    closedRecords = 0;

    if (recsSnap.exists) {
      for (final s in recsSnap.children) {
        final rec = _HealthRecord.fromSnap(
          s,
          petName: _petName[s.child('petId').value?.toString() ?? ''] ?? '',
          ownerName:
              _ownerName[s.child('ownerId').value?.toString() ?? ''] ?? '',
          vetName: _vetName[s.child('vetId').value?.toString() ?? ''] ?? '',
        );
        _records.add(rec);
      }
    }

    totalRecords = _records.length;
    for (final r in _records) {
      if (r.status.toLowerCase() == 'open') {
        openRecords++;
      } else if (r.status.toLowerCase() == 'closed') {
        closedRecords++;
      }
    }

    _applyRecordFilters();

    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _updateRecord(_HealthRecord r) async {
    await _db().child('healthRecords').child(r.id).update({
      'diagnosis': r.diagnosis,
      'treatment': r.treatment,
      'notes': r.notes,
      'status': r.status,
    });
  }

  Future<void> _manageRecord(_HealthRecord r) async {
    final diagnosis = TextEditingController(text: r.diagnosis);
    final treatment = TextEditingController(text: r.treatment);
    final notes = TextEditingController(text: r.notes);
    String status = r.status;

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
              constraints: BoxConstraints(maxHeight: h * .95),
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                child: StatefulBuilder(
                  builder: (ctx, innerSet) {
                    return SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text(
                                  'Manage Health Report',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const Spacer(),
                                IconButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  icon: const Icon(Icons.close),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            _readonlyRow('Pet', r.petName),
                            _readonlyRow('Owner', r.ownerName),
                            _readonlyRow('Vet', r.vetName),
                            const SizedBox(height: 8),
                            _field(
                              controller: diagnosis,
                              hint: 'Diagnosis',
                              icon: Icons.assignment_outlined,
                            ),
                            _field(
                              controller: treatment,
                              hint: 'Treatment',
                              icon: Icons.medical_services_outlined,
                            ),
                            _field(
                              controller: notes,
                              hint: 'Notes',
                              icon: Icons.notes_outlined,
                              maxLines: 3,
                            ),
                            const SizedBox(height: 8),
                            const Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Status',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                ChoiceChip(
                                  label: const Text('Open'),
                                  selected: status == 'open',
                                  selectedColor: kGold.withOpacity(.25),
                                  onSelected: (_) => innerSet(() {
                                    status = 'open';
                                  }),
                                ),
                                ChoiceChip(
                                  label: const Text('Closed'),
                                  selected: status == 'closed',
                                  selectedColor: kGold.withOpacity(.25),
                                  onSelected: (_) => innerSet(() {
                                    status = 'closed';
                                  }),
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
                                  final updated = r.copyWith(
                                    diagnosis: diagnosis.text.trim(),
                                    treatment: treatment.text.trim(),
                                    notes: notes.text.trim(),
                                    status: status,
                                  );
                                  await _updateRecord(updated);
                                  if (ctx.mounted) Navigator.pop(ctx, true);
                                },
                                child: const Text(
                                  'Save Changes',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );

    if (saved == true && mounted) await _load();
  }

  Widget _readonlyRow(String label, String value) {
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
          Text('$label: ',
              style:
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          Expanded(
              child: Text(value,
                  textAlign: TextAlign.end,
                  style: const TextStyle(color: Colors.black54))),
        ],
      ),
    );
  }

  Future<void> _generateReport() async {
    final now = DateTime.now();
    final start = _startDate();

    final csv = StringBuffer()
      ..writeln('Section,Metric,Value')
      ..writeln('Range,From,${start.toIso8601String()}')
      ..writeln('Range,To,${now.toIso8601String()}')
      ..writeln('Totals,Owners,$totalOwners')
      ..writeln('Totals,Veterinarians,$totalVets')
      ..writeln('Totals,Pets,$totalPets')
      ..writeln('Totals,Collars,$totalCollars')
      ..writeln('Engagement,Notifications,$totalAlerts')
      ..writeln('Engagement,Appointments,$totalAppts')
      ..writeln('Engagement,Messages,$totalMsgs')
      ..writeln('Health,Open Records,$openRecords')
      ..writeln('Health,Closed Records,$closedRecords')
      ..writeln('Vitals,Avg Heart Rate (bpm),${avgHeart.toStringAsFixed(1)}')
      ..writeln('Vitals,Avg Temperature (°C),${avgTemp.toStringAsFixed(1)}')
      ..writeln('Vitals,Avg Activity,${avgActivity.toStringAsFixed(1)}')
      ..writeln('Device,Min Battery (%),${minBattery.toStringAsFixed(0)}');

    // Save a snapshot to DB (optional archive)
    await _db().child('adminReports').push().set({
      'generatedAt': now.toIso8601String(),
      'rangeDays': _rangeDays,
      'totals': {
        'owners': totalOwners,
        'vets': totalVets,
        'pets': totalPets,
        'collars': totalCollars,
      },
      'engagement': {
        'alerts': totalAlerts,
        'appointments': totalAppts,
        'messages': totalMsgs,
        'weekly': weeklyEngagement,
      },
      'health': {
        'recordsTotal': totalRecords,
        'recordsOpen': openRecords,
        'recordsClosed': closedRecords,
        'avgHeart': avgHeart,
        'avgTemp': avgTemp,
        'avgActivity': avgActivity,
        'minBattery': minBattery,
      },
      'csv': csv.toString(),
    });

    await Clipboard.setData(ClipboardData(text: csv.toString()));

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Report Generated'),
        content: const Text(
            'A CSV summary was copied to clipboard and archived in the database under "adminReports".'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('OK'))
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBrown,
      appBar: AppBar(
        backgroundColor: kGold,
        foregroundColor: Colors.black87,
        title: const Text('Reports & Analytics'),
        actions: [
          IconButton(
              tooltip: 'Generate Report',
              onPressed: _generateReport,
              icon: const Icon(Icons.file_download_outlined)),
          IconButton(
              tooltip: 'Refresh',
              onPressed: _load,
              icon: const Icon(Icons.refresh)),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              children: [
                // Header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [kGold, kBrown],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius:
                        BorderRadius.vertical(bottom: Radius.circular(28)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Text('Overview',
                              style: TextStyle(
                                  fontSize: 22, fontWeight: FontWeight.w900)),
                          const Spacer(),
                          _rangeChip(7, '7d'),
                          const SizedBox(width: 6),
                          _rangeChip(30, '30d'),
                          const SizedBox(width: 6),
                          _rangeChip(90, '90d'),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_loading) const LinearProgressIndicator(minHeight: 2),
                    ],
                  ),
                ),

                // KPI Cards
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: _loading
                      ? const Center(
                          child: Padding(
                              padding: EdgeInsets.all(22),
                              child: CircularProgressIndicator()))
                      : Column(
                          children: [
                            Row(children: [
                              _kpi('Owners', totalOwners, Icons.people_alt),
                              const SizedBox(width: 12),
                              _kpi('Vets', totalVets,
                                  Icons.medical_information_outlined),
                            ]),
                            const SizedBox(height: 12),
                            Row(children: [
                              _kpi('Pets', totalPets, Icons.pets_outlined),
                              const SizedBox(width: 12),
                              _kpi('Collars', totalCollars,
                                  Icons.sensors_rounded),
                            ]),
                            const SizedBox(height: 12),
                            Row(children: [
                              _kpi('Alerts', totalAlerts,
                                  Icons.notifications_active_outlined),
                              const SizedBox(width: 12),
                              _kpi('Appointments', totalAppts,
                                  Icons.calendar_month_outlined),
                            ]),
                          ],
                        ),
                ),

                // Charts
                if (!_loading)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _chartCard(
                                title: 'Weekly Engagement',
                                subtitle:
                                    'Notifications • Appointments • Messages',
                                child: MiniBarChart(data: weeklyEngagement),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _chartCard(
                                title: 'Heart Rate (24h)',
                                subtitle:
                                    '${avgHeart.toStringAsFixed(1)} bpm average',
                                child: SparklineChart(
                                    data: heart24h.isEmpty
                                        ? [70, 72, 68, 74, 71, 69, 73, 75]
                                        : heart24h),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _chartCard(
                                title: 'Average Temperature',
                                subtitle:
                                    '${avgTemp.toStringAsFixed(1)} °C average',
                                child: SparklineChart(
                                    data: heart24h.isEmpty
                                        ? [37.6, 37.8, 38.1, 37.9, 38.0]
                                        : heart24h
                                            .map((e) => 37.5 + (e - 60) * 0.02)
                                            .toList()),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _chartCard(
                                title: 'Collar Battery',
                                subtitle:
                                    'Min ${minBattery.toStringAsFixed(0)}% across devices',
                                child: GaugeBattery(
                                    value: minBattery.clamp(0, 100)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                // Records
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                  child: const Text('Health Reports',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      TextField(
                        controller: _recSearch,
                        decoration: InputDecoration(
                          hintText:
                              'Search pet / owner / vet / diagnosis / treatment',
                          prefixIcon: const Icon(Icons.search),
                          filled: true,
                          fillColor: const Color(0xFFF7F7F7),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              vertical: 0, horizontal: 12),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _recFilterChip('all', 'All'),
                          const SizedBox(width: 8),
                          _recFilterChip('open', 'Open'),
                          const SizedBox(width: 8),
                          _recFilterChip('closed', 'Closed'),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.all(22),
                    child: CircularProgressIndicator(),
                  )
                else if (_recordsView.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(22),
                    child: Text('No health reports'),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _recordsView.length,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _recordCard(_recordsView[i]),
                  ),

                const SizedBox(height: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // UI helpers
  Widget _rangeChip(int d, String label) {
    final active = _rangeDays == d;
    return ChoiceChip(
      label: Text(label),
      selected: active,
      selectedColor: kGold.withOpacity(.25),
      onSelected: (_) {
        setState(() => _rangeDays = d);
        _load();
      },
    );
  }

  Widget _kpi(String label, int value, IconData icon) {
    return Expanded(
      child: Container(
        height: 100,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(.06),
                blurRadius: 12,
                offset: const Offset(0, 6)),
          ],
          border: Border.all(color: Colors.black12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, color: kBrownDark),
              const Spacer(),
            ]),
            const Spacer(),
            Text('$value',
                style: const TextStyle(
                    fontSize: 22, height: 1.1, fontWeight: FontWeight.w900)),
            Text(label, style: const TextStyle(color: Colors.black54)),
          ],
        ),
      ),
    );
  }

  Widget _chartCard(
      {required String title,
      required String subtitle,
      required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(.06),
              blurRadius: 12,
              offset: const Offset(0, 6)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(subtitle,
            style: const TextStyle(fontSize: 12, color: Colors.black54)),
        const SizedBox(height: 8),
        SizedBox(height: 120, child: child),
      ]),
    );
  }

  Widget _recFilterChip(String key, String label) {
    final sel = _recStatusFilter == key;
    return ChoiceChip(
      label: Text(label),
      selected: sel,
      selectedColor: kGold.withOpacity(.25),
      onSelected: (_) {
        setState(() => _recStatusFilter = key);
        _applyRecordFilters();
      },
    );
  }

  Widget _recordCard(_HealthRecord r) {
    final isOpen = r.status.toLowerCase() == 'open';
    final badgeColor = isOpen ? Colors.orange : Colors.green;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(.06),
              blurRadius: 12,
              offset: const Offset(0, 6)),
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
                  radius: 22,
                  backgroundColor: kBrownDark.withOpacity(.15),
                  child: const Icon(Icons.health_and_safety_outlined,
                      color: kBrownDark),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.petName,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text('Owner: ${r.ownerName} • Vet: ${r.vetName}',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.black54)),
                      Text('Dx: ${r.diagnosis}  |  Tx: ${r.treatment}',
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
                    r.status,
                    style: TextStyle(
                        color: badgeColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.manage_accounts_outlined),
                    label: const Text('Manage'),
                    onPressed: () => _manageRecord(r),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: Icon(isOpen ? Icons.check_circle : Icons.refresh),
                    label: Text(isOpen ? 'Close' : 'Reopen'),
                    onPressed: () async {
                      final upd =
                          r.copyWith(status: isOpen ? 'closed' : 'open');
                      await _updateRecord(upd);
                      await _load();
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ======= Models / Utils =======

class _Point {
  final DateTime t;
  final double v;
  _Point(this.t, this.v);
}

class _HealthRecord {
  final String id;
  final String petId;
  final String ownerId;
  final String vetId;
  final String petName;
  final String ownerName;
  final String vetName;
  final String diagnosis;
  final String treatment;
  final String notes;
  final String status;
  final String createdAt;

  _HealthRecord({
    required this.id,
    required this.petId,
    required this.ownerId,
    required this.vetId,
    required this.petName,
    required this.ownerName,
    required this.vetName,
    required this.diagnosis,
    required this.treatment,
    required this.notes,
    required this.status,
    required this.createdAt,
  });

  factory _HealthRecord.fromSnap(DataSnapshot s,
      {required String petName,
      required String ownerName,
      required String vetName}) {
    return _HealthRecord(
      id: s.key ?? '',
      petId: s.child('petId').value?.toString() ?? '',
      ownerId: s.child('ownerId').value?.toString() ?? '',
      vetId: s.child('vetId').value?.toString() ?? '',
      petName: petName,
      ownerName: ownerName,
      vetName: vetName,
      diagnosis: s.child('diagnosis').value?.toString() ?? '',
      treatment: s.child('treatment').value?.toString() ?? '',
      notes: s.child('notes').value?.toString() ?? '',
      status: s.child('status').value?.toString() ?? 'open',
      createdAt: s.child('createdAt').value?.toString() ?? '',
    );
  }

  _HealthRecord copyWith({
    String? diagnosis,
    String? treatment,
    String? notes,
    String? status,
  }) {
    return _HealthRecord(
      id: id,
      petId: petId,
      ownerId: ownerId,
      vetId: vetId,
      petName: petName,
      ownerName: ownerName,
      vetName: vetName,
      diagnosis: diagnosis ?? this.diagnosis,
      treatment: treatment ?? this.treatment,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      createdAt: createdAt,
    );
  }
}

// ======= Tiny in-house charts (no extra packages) =======

class MiniBarChart extends StatelessWidget {
  final List<double> data;
  const MiniBarChart({super.key, required this.data});
  @override
  Widget build(BuildContext context) {
    final max = (data.isEmpty ? 1 : data.reduce((a, b) => a > b ? a : b))
        .clamp(1, double.infinity);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(data.length, (i) {
        final h = (data[i] / max) * 100 + 8;
        return Container(
          width: 10,
          height: h,
          decoration: BoxDecoration(
            color: i == data.length - 1 ? kGold : kBrownDark.withOpacity(.4),
            borderRadius: BorderRadius.circular(6),
          ),
        );
      }),
    );
  }
}

class SparklineChart extends StatelessWidget {
  final List<double> data;
  const SparklineChart({super.key, required this.data});
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _SparkPainter(data),
      child: Container(),
    );
  }
}

class _SparkPainter extends CustomPainter {
  final List<double> data;
  _SparkPainter(this.data);
  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    final maxV = data.reduce((a, b) => a > b ? a : b);
    final minV = data.reduce((a, b) => a < b ? a : b);
    final line = Paint()
      ..color = kBrownDark
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final fill = Paint()
      ..color = kGold.withOpacity(.25)
      ..style = PaintingStyle.fill;

    final path = Path();
    final stepX = size.width / (data.length - 1);
    for (int i = 0; i < data.length; i++) {
      final x = i * stepX;
      final y = size.height -
          ((data[i] - minV) / ((maxV - minV) == 0 ? 1 : (maxV - minV))) *
              size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(fillPath, fill);
    canvas.drawPath(path, line);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class GaugeBattery extends StatelessWidget {
  final double value;
  const GaugeBattery({super.key, required this.value});
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _GaugePainter(value),
      child: const SizedBox.expand(),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double value;
  _GaugePainter(this.value);
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * .8);
    final radius = size.width * .45;
    final bg = Paint()
      ..color = Colors.black12
      ..strokeWidth = 10
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final fg = Paint()
      ..color = kGold
      ..strokeWidth = 10
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius), 3.14, 3.14, false, bg);
    final sweep = 3.14 * ((value.clamp(0, 100)) / 100);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), 3.14, sweep,
        false, fg);

    final tp = TextPainter(
      text: TextSpan(
          text: '${value.toStringAsFixed(0)}%',
          style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: Colors.black87)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
        canvas,
        Offset(
            center.dx - tp.width / 2, center.dy - radius / 2 - tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// Reusable input
Widget _field({
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
