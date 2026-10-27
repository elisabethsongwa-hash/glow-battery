import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() => runApp(const GlowApp());

class GlowApp extends StatelessWidget {
  const GlowApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Glow Battery',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
        home: const HomePage(),
      );
}

class Sample {
  final DateTime t;
  final double ma; // positif = entrant, négatif = sortant
  Sample(this.t, this.ma);
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const ch = MethodChannel('glow/battery');
  final List<Sample> _samples = [];
  Timer? _timer;
  bool _charging = false;
  int _percent = 0;
  double _chargeMah = 0;
  double _nowMa = 0;

  @override
  void initState() {
    super.initState();
    _poll();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _poll());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _poll() async {
    try {
      final m = await ch.invokeMapMethod<String, dynamic>('getBattery');
      if (m == null) return;
      final raw = (m['currentUa'] as num).toDouble().abs();
      final ma = raw >= 10000 ? raw / 1000 : raw;
      final charging = m['charging'] as bool;
      final cu = (m['chargeUah'] as num).toDouble();
      final chargeMah = cu > 0 ? (cu > 100000 ? cu / 1000 : cu) : 0.0;
      final now = DateTime.now();
      if (!mounted) return;
      setState(() {
        _charging = charging;
        _percent = (m['percent'] as num).toInt();
        _chargeMah = chargeMah;
        _nowMa = ma;
        _samples.add(Sample(now, charging ? ma : -ma));
        while (_samples.isNotEmpty &&
            now.difference(_samples.first.t).inSeconds > 3600) {
          _samples.removeAt(0);
        }
      });
    } catch (_) {}
  }

  double _avg(int sec) {
    final now = DateTime.now();
    final v = _samples
        .where((s) =>
            now.difference(s.t).inSeconds < sec &&
            (_charging ? s.ma > 0 : s.ma < 0))
        .map((s) => s.ma.abs())
        .toList();
    if (v.isEmpty) return _nowMa;
    return v.reduce((a, b) => a + b) / v.length;
  }

  String _fmt(double hours) {
    if (hours.isNaN || hours.isInfinite || hours > 99) return '—';
    final minutes = (hours * 60).round();
    if (minutes < 1) return '< 1 min';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return h > 0 ? '$h h ${m.toString().padLeft(2, '0')} min' : '$m min';
  }

  String _eta() {
    if (_charging && _percent >= 100) return 'Batterie pleine';
    final ref = _avg(60);
    if (ref < 5) return 'Estimation en cours…';
    final estimated = _chargeMah <= 0 || _percent <= 0;
    final full = estimated ? 5000.0 : _chargeMah / (_percent / 100);
    final remaining = estimated ? full * _percent / 100 : _chargeMah;
    final hours = _charging ? (full - remaining) / ref : remaining / ref;
    final t = _fmt(hours);
    return estimated ? '~ $t' : t;
  }

  @override
  Widget build(BuildContext context) {
    final up = _charging;
    final c1 = up ? const Color(0xFF00E676) : const Color(0xFFFF9100);
    final c2 = up ? const Color(0xFF00695C) : const Color(0xFFB71C1C);
    final bg = up
        ? const [Color(0xFF021A12), Color(0xFF04382B)]
        : const [Color(0xFF1C0A02), Color(0xFF3B1205)];
    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 600),
        decoration: BoxDecoration(
          gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: bg),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Text(up ? 'Glow Up' : 'Glow Down',
                    style: TextStyle(
                        fontSize: 34, fontWeight: FontWeight.bold, color: c1)),
                Text(up ? 'En charge' : 'Sur batterie',
                    style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 20),
                _battery(c1, c2),
                const SizedBox(height: 22),
                Text(up ? 'Temps avant charge complète' : "Temps avant extinction",
                    style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 4),
                Text(_eta(),
                    style: TextStyle(
                        fontSize: 30, fontWeight: FontWeight.bold, color: c1)),
                const SizedBox(height: 22),
                Text(up ? 'Courant entrant (moyennes)' : 'Courant sortant (moyennes)',
                    style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 8),
                Row(children: [
                  _tile('Par seconde', _nowMa, 1, c1),
                  _tile('Par minute', _avg(60), 60, c1),
                  _tile('Par heure', _avg(3600), 3600, c1),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _battery(Color c1, Color c2) {
    return Column(children: [
      Container(
        width: 50,
        height: 14,
        decoration:
            BoxDecoration(color: c1, borderRadius: BorderRadius.circular(4)),
      ),
      const SizedBox(height: 4),
      Container(
        width: 150,
        height: 260,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: c1, width: 4),
          boxShadow: [
            BoxShadow(
                color: c1.withOpacity(0.45), blurRadius: 40, spreadRadius: 4)
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              FractionallySizedBox(
                heightFactor: (_percent / 100).clamp(0.0, 1.0),
                widthFactor: 1,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [c2, c1]),
                  ),
                ),
              ),
              Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('$_percent%',
                      style: const TextStyle(
                          fontSize: 38,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                  Text('${_nowMa.round()} mA',
                      style: const TextStyle(color: Colors.white)),
                ]),
              ),
            ],
          ),
        ),
      ),
    ]);
  }

  Widget _tile(String label, double ma, double windowSec, Color c) {
    final mah = ma * windowSec / 3600;
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.withOpacity(0.4)),
        ),
        child: Column(children: [
          Text(label,
              style: const TextStyle(fontSize: 12, color: Colors.white70)),
          const SizedBox(height: 6),
          Text(ma.round().toString(),
              style: TextStyle(
                  fontSize: 24, fontWeight: FontWeight.bold, color: c)),
          const Text('mA',
              style: TextStyle(fontSize: 12, color: Colors.white70)),
          const SizedBox(height: 4),
          Text('≈ ${mah.toStringAsFixed(mah < 10 ? 2 : 1)} mAh',
              style: const TextStyle(fontSize: 11, color: Colors.white54)),
        ]),
      ),
    );
  }
}
