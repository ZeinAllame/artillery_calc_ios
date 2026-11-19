import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../../../theme/theme_provider.dart';
import '../../widgets/app_drawer.dart' show rootScaffoldKey; // ← الاستيراد المهم

class _Mission {
  String id;
  String name;
  DateTime target;
  bool enabled;
  bool alarmActive;
  _Mission({required this.id, required this.name, required this.target, this.enabled = true, this.alarmActive = false});
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'target': target.toIso8601String(), 'enabled': enabled};
  factory _Mission.fromJson(Map<String, dynamic> j) => _Mission(id: j['id'], name: j['name'], target: DateTime.parse(j['target']), enabled: j['enabled'] ?? true);
}

class FiringTimerScreen extends StatefulWidget {
  const FiringTimerScreen({Key? key}) : super(key: key);
  @override
  State<FiringTimerScreen> createState() => _FiringTimerScreenState();
}

class _FiringTimerScreenState extends State<FiringTimerScreen> {
  List<_Mission> _missions = [];
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _load();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      bool anyActive = false;
      for (var m in _missions) {
        if (m.enabled && !m.alarmActive) {
          final diff = m.target.difference(DateTime.now());
          if (diff.inSeconds <= 0) {
            m.alarmActive = true;
            anyActive = true;
          }
        }
      }
      if (anyActive) {
        FlutterRingtonePlayer().playAlarm(looping: true);
      }
      if (mounted) setState(() {});
    });
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString('mission_timers');
    if (s != null) {
      final list = (json.decode(s) as List).map((e) => _Mission.fromJson(e)).toList();
      setState(() => _missions = list);
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('mission_timers', json.encode(_missions.map((e) => e.toJson()).toList()));
  }

  Future<void> _addMission() async {
    final nameCtrl = TextEditingController();
    final date = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 30)));
    if (date == null) return;
    if (!mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (time == null) return;
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('اسم الهدف'),
        content: TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'مثال: هدف الدبابة')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          TextButton(
            onPressed: () {
              final dt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
              setState(() => _missions.add(_Mission(id: DateTime.now().millisecondsSinceEpoch.toString(), name: nameCtrl.text.isEmpty ? 'هدف' : nameCtrl.text, target: dt)));
              _save();
              Navigator.pop(ctx);
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }

  void _toggle(_Mission m) {
    setState(() => m.enabled = !m.enabled);
    _save();
    if (!m.enabled) FlutterRingtonePlayer().stop();
  }

  void _stopAlarm() {
    FlutterRingtonePlayer().stop();
    setState(() {
      for (var m in _missions) { m.alarmActive = false; }
    });
  }

  void _delete(_Mission m) {
    setState(() => _missions.remove(m));
    _save();
  }

  @override
  void dispose() {
    FlutterRingtonePlayer().stop();
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Provider.of<ThemeProvider>(context).colors;
    final anyAlarm = _missions.any((m) => m.alarmActive);

    return Scaffold(
      backgroundColor: colors['bg'],
      appBar: AppBar(
        // ← إصلاح الشريط الجانبي هنا
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(Icons.menu, color: colors['text']),
            onPressed: () => rootScaffoldKey.currentState?.openDrawer(),
          ),
        ),
        title: const Text('غرفة العمليات - المواعيد'), 
        backgroundColor: colors['surface'],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addMission,
        backgroundColor: colors['primary'],
        foregroundColor: Colors.black,
        child: const Icon(Icons.add_alarm),
      ),
      body: Column(
        children: [
          if (anyAlarm)
            Container(
              width: double.infinity,
              color: Colors.red,
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.warning, color: Colors.white),
                  const SizedBox(width: 10),
                  const Expanded(child: Text('⏰ تنبيه: حان وقت الرمي!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                  TextButton(onPressed: _stopAlarm, child: const Text('إيقاف', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                ],
              ),
            ),
          Expanded(
            child: _missions.isEmpty
                ? Center(child: Text('لا توجد مواعيد. اضغط + للإضافة', style: TextStyle(color: colors['text'])))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _missions.length,
                    itemBuilder: (context, i) {
                      final m = _missions[i];
                      final diff = m.target.difference(DateTime.now());
                      final isPast = diff.isNegative;
                      return Card(
                        color: colors['surface'],
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: m.alarmActive ? Colors.red : colors['border']!)),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.flag, color: m.alarmActive ? Colors.red : colors['primary']),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(m.name, style: TextStyle(color: colors['text'], fontSize: 18, fontWeight: FontWeight.bold))),
                                  Switch(value: m.enabled, activeColor: colors['primary'], onChanged: (_) => _toggle(m)),
                                ],
                              ),
                              Text('الموعد: ${DateFormat('yyyy-MM-dd HH:mm').format(m.target)}', style: TextStyle(color: colors['text']?.withOpacity(0.7))),
                              Text(isPast ? 'انتهى الوقت' : 'متبقي: ${diff.inHours}س ${diff.inMinutes % 60}د ${diff.inSeconds % 60}ث',
                                  style: TextStyle(color: isPast ? Colors.red : colors['warning'], fontSize: 16, fontWeight: FontWeight.bold)),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton.icon(onPressed: () => _delete(m), icon: const Icon(Icons.delete, color: Colors.red), label: const Text('حذف', style: TextStyle(color: Colors.red))),
                                ],
                              )
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}