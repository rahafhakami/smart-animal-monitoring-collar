// lib/admin_home.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';
import '../LoginPage.dart';
import 'admin_providers.dart';
import 'admin_users.dart';
import 'admin_reports.dart';
import 'admin_notifications.dart';
import 'admin_settings.dart';

const kGold = Color(0xFFFFC107);
const kBrown = Color(0xFFD7B899);
const kBrownDark = Color(0xFF8D6E63);
const kRedSoft = Color(0xFFF28B82);

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});
  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  bool _loading = true;
  int providers = 0,
      owners = 0,
      pets = 0,
      collars = 0,
      appts = 0,
      alerts = 0,
      pendingProviders = 0;
  double avgHeart = 0, avgBattery = 0;
  List<double> weeklySignups = List.filled(7, 0);
  List<double> weeklyAppts = List.filled(7, 0);
  List<double> heartSpark = [];

  int _tab = 0;
  final _search = TextEditingController();

  Future<void> _ensure() async {
    if (Firebase.apps.isEmpty) await FirebaseConfig.initializeFirebase();
  }

  DatabaseReference _db() => FirebaseDatabase.instanceFor(
          app: Firebase.app(), databaseURL: FirebaseConfig.dbUrl)
      .ref();

  int _dayIndex(DateTime t) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day)
        .subtract(const Duration(days: 6));
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

  Future<void> _load() async {
    await _ensure();
    final db = _db();

    final vets = await db.child('veterinarians').get();
    final ownersSnap = await db.child('petOwners').get();
    final petsSnap = await db.child('pets').get();
    final collarsSnap = await db.child('bioCollars').get();
    final apptsSnap = await db.child('appointments').get();
    final notiSnap = await db.child('notifications').get();

    int pend = 0;
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day)
        .subtract(const Duration(days: 6));
    weeklySignups = List.filled(7, 0);
    weeklyAppts = List.filled(7, 0);

    if (vets.exists) {
      providers = vets.children.length;
      for (final v in vets.children) {
        final st = v.child('status').value?.toString() ?? '';
        if (st != 'approved') pend++;
        final createdAt =
            _parseISO(v.child('createdAt').value?.toString() ?? '');
        if (createdAt != null && createdAt.isAfter(start)) {
          weeklySignups[_dayIndex(createdAt)] += 1;
        }
      }
    }

    if (ownersSnap.exists) {
      owners = ownersSnap.children.length;
      for (final o in ownersSnap.children) {
        final createdAt =
            _parseISO(o.child('createdAt').value?.toString() ?? '');
        if (createdAt != null && createdAt.isAfter(start)) {
          weeklySignups[_dayIndex(createdAt)] += 1;
        }
      }
    }

    pets = petsSnap.children.length;
    collars = collarsSnap.children.length;
    appts = apptsSnap.children.length;
    alerts = notiSnap.children.length;
    heartSpark = [];

    double heartSum = 0, heartCount = 0, batSum = 0, batCount = 0;
    if (collarsSnap.exists) {
      for (final col in collarsSnap.children) {
        final b = double.tryParse(col.child('battery').value?.toString() ?? '');
        if (b != null) {
          batSum += b;
          batCount += 1;
        }
        final readings = col.child('readings');
        if (readings.exists) {
          for (final r in readings.children) {
            final hr =
                double.tryParse(r.child('heartRate').value?.toString() ?? '');
            final at = _parseISO(r.child('at').value?.toString() ?? '');
            if (hr != null) {
              heartSum += hr;
              heartCount += 1;
              if (heartSpark.length < 24) heartSpark.add(hr);
            }
            if (at != null && at.isAfter(start)) {
              weeklyAppts[_dayIndex(at)] += 1;
            }
          }
        }
      }
    }

    if (apptsSnap.exists) {
      for (final a in apptsSnap.children) {
        final d = a.child('date').value?.toString();
        final t = a.child('time').value?.toString();
        DateTime? at;
        if (d != null && t != null) {
          at = _parseISO('${d}T${t}:00');
        }
        if (at != null && at.isAfter(start)) {
          weeklyAppts[_dayIndex(at)] += 1;
        }
      }
    }

    setState(() {
      avgHeart = heartCount == 0 ? 0 : heartSum / heartCount;
      avgBattery = batCount == 0 ? 0 : batSum / batCount;
      pendingProviders = pend;
      _loading = false;
    });
  }

  Future<void> _logout() async {
    final p = await SharedPreferences.getInstance();
    await p.clear();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(context,
        MaterialPageRoute(builder: (_) => const LoginPage()), (_) => false);
  }

  void _goSettings() {
    Navigator.push(
        context, MaterialPageRoute(builder: (_) => const AdminSettingsPage()));
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _homeBody(),
      const AdminProvidersPage(),
      const AdminUsersPage(),
      const AdminReportsPage(),
      const AdminSettingsPage(),
    ];
    return Scaffold(
      backgroundColor: kBrown,
      body: pages[_tab],
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          boxShadow: [
            BoxShadow(
                blurRadius: 12, color: Colors.black12, offset: Offset(0, -6))
          ],
        ),
        padding: const EdgeInsets.fromLTRB(6, 6, 6, 10),
        child: SafeArea(
          top: false,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navItem(Icons.home_rounded, 'Home', 0),
              _navItem(Icons.medical_information_outlined, 'Providers', 1),
              _navItem(Icons.people_alt_outlined, 'Users', 2),
              _navItem(Icons.analytics_outlined, 'Reports', 3),
              _navItem(Icons.settings_outlined, 'Settings', 4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, String label, int index) {
    final active = _tab == index;
    return InkWell(
      onTap: () => setState(() => _tab = index),
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? kGold.withOpacity(.25) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: active ? Colors.black87 : Colors.black45),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    color: active ? Colors.black87 : Colors.black45)),
          ],
        ),
      ),
    );
  }

  Widget _homeBody() {
    final size = MediaQuery.of(context).size;
    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(18, 26, 18, 22),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                    colors: [kGold, kBrown],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
                borderRadius:
                    BorderRadius.vertical(bottom: Radius.circular(28)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Text('BioCollar',
                          style: TextStyle(
                              fontSize: 22, fontWeight: FontWeight.w900)),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    const AdminNotificationsPage())),
                        icon: const Icon(Icons.notifications_none),
                      ),
                      IconButton(
                          onPressed: _logout, icon: const Icon(Icons.logout)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 44,
                    child: TextField(
                      controller: _search,
                      decoration: InputDecoration(
                        hintText: 'What service do you need?',
                        filled: true,
                        fillColor: Colors.white,
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: IconButton(
                            icon: const Icon(Icons.tune),
                            onPressed: _goSettings),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(
                            vertical: 0, horizontal: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    height: 132,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      image: const DecorationImage(
                          image: AssetImage('assets/banner.png'),
                          fit: BoxFit.cover,
                          alignment: Alignment.centerRight),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: LinearGradient(
                            colors: [
                              Colors.white,
                              Colors.white.withOpacity(.55)
                            ],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight),
                      ),
                      padding: const EdgeInsets.all(16),
                      alignment: Alignment.centerLeft,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('Hire a Service Man',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 36,
                            child: ElevatedButton(
                              onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          const AdminProvidersPage())),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: kGold,
                                foregroundColor: Colors.black87,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('Book Now'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: _loading
                  ? const Center(
                      child: Padding(
                          padding: EdgeInsets.all(22),
                          child: CircularProgressIndicator()))
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          _statCard(
                              Icons.medical_information_outlined,
                              'Providers',
                              providers,
                              badge: pendingProviders > 0
                                  ? '$pendingProviders pending'
                                  : null,
                              onTap: () => setState(() => _tab = 1)),
                          const SizedBox(width: 12),
                          _statCard(Icons.people_alt_outlined, 'Owners', owners,
                              onTap: () => setState(() => _tab = 2)),
                        ]),
                        const SizedBox(height: 12),
                        Row(children: [
                          _statCard(Icons.pets_outlined, 'Pets', pets),
                          const SizedBox(width: 12),
                          _statCard(Icons.sensors_outlined, 'Collars', collars),
                        ]),
                        const SizedBox(height: 12),
                        Row(children: [
                          _statCard(Icons.calendar_month_outlined,
                              'Appointments', appts),
                          const SizedBox(width: 12),
                          _statCard(Icons.notifications_active_outlined,
                              'Alerts', alerts,
                              onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          const AdminNotificationsPage()))),
                        ]),
                        const SizedBox(height: 18),
                        const Text('Our Services',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 10),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(children: [
                            _serviceChip(Icons.verified_outlined, 'Approvals',
                                () {
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          const AdminProvidersPage()));
                            }),
                            const SizedBox(width: 8),
                            _serviceChip(Icons.person_add_alt_1, 'Add Provider',
                                () {
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          const AdminProvidersPage()));
                            }),
                            const SizedBox(width: 8),
                            _serviceChip(Icons.campaign_outlined, 'Notify', () {
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          const AdminNotificationsPage()));
                            }),
                            const SizedBox(width: 8),
                            _serviceChip(Icons.security_outlined, 'Security',
                                _goSettings),
                          ]),
                        ),
                        const SizedBox(height: 18),
                        const Text('Analytics',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _chartCard(
                                title: 'Weekly Signups',
                                subtitle: '${owners + providers} total users',
                                child: MiniBarChart(data: weeklySignups),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _chartCard(
                                title: 'Weekly Activity',
                                subtitle: '$appts appointments',
                                child: MiniBarChart(data: weeklyAppts),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _chartCard(
                                title: 'Avg Heart Rate',
                                subtitle: '${avgHeart.toStringAsFixed(1)} bpm',
                                child: SparklineChart(
                                    data: heartSpark.isEmpty
                                        ? [60, 65, 62, 70, 68, 72, 66, 64]
                                        : heartSpark.take(20).toList()),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _chartCard(
                                title: 'Collar Battery',
                                subtitle:
                                    '${avgBattery.toStringAsFixed(0)}% avg',
                                child: GaugeBattery(
                                    value: avgBattery.clamp(0, 100).toDouble()),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCard(IconData icon, String label, int value,
      {VoidCallback? onTap, String? badge}) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 110,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(.06),
                  blurRadius: 12,
                  offset: const Offset(0, 6))
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(icon, color: kBrownDark),
                const Spacer(),
                if (badge != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: kRedSoft.withOpacity(.15),
                        borderRadius: BorderRadius.circular(50)),
                    child: Text(badge,
                        style: const TextStyle(
                            color: kRedSoft,
                            fontSize: 11,
                            fontWeight: FontWeight.w700)),
                  ),
              ]),
              const Spacer(),
              Text('$value',
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w900)),
              Text(label, style: const TextStyle(color: Colors.black54)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _serviceChip(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(.05),
                blurRadius: 10,
                offset: const Offset(0, 6))
          ],
          border: Border.all(color: Colors.black12),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: kBrownDark, size: 18),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        ]),
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
              offset: const Offset(0, 6))
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
}

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
    return CustomPaint(painter: _SparkPainter(data), child: Container());
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
    final paintLine = Paint()
      ..color = kBrownDark
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final paintFill = Paint()
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
    canvas.drawPath(fillPath, paintFill);
    canvas.drawPath(path, paintLine);
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
        painter: _GaugePainter(value), child: const SizedBox.expand());
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
    final sweep = 3.14 * (value / 100);
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
