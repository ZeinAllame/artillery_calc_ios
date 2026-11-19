import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mgrs_dart/mgrs_dart.dart';
import 'package:intl/intl.dart'; // ★ تم التأكد من استيراد intl
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import '../../../theme/theme_provider.dart';

class RocketWarningScreen extends StatefulWidget {
  const RocketWarningScreen({Key? key}) : super(key: key);
  @override
  State<RocketWarningScreen> createState() => _RocketWarningScreenState();
}

class _RocketWarningScreenState extends State<RocketWarningScreen> {
  double? _compassHeading;
  StreamSubscription<CompassEvent>? _compassSub;
  
  bool _isAlert = false;
  DateTime? _alertTime;
  String _selectedRocketType = 'grad';
  String _launchDirection = '---';
  String _estimatedOrigin = '---';
  String _impactTime = '---';
  String _safeZone = '---';
  
  static const Map<String, Map<String, dynamic>> _rocketData = {
    'grad': {'name': 'BM-21 Grad', 'range': 40000, 'tof': 120, 'speed': 690},
    'bm27': {'name': 'BM-27 Uragan', 'range': 35000, 'tof': 100, 'speed': 700},
    'bm30': {'name': 'BM-30 Smerch', 'range': 90000, 'tof': 180, 'speed': 800},
    'fateh110': {'name': 'Fateh-110', 'range': 300000, 'tof': 300, 'speed': 1000},
  };

  @override
  void initState() {
    super.initState();
    _initCompass();
    _loadLastAlert();
  }

  Future<void> _initCompass() async {
    _compassSub = FlutterCompass.events?.listen((event) {
      if (mounted) setState(() => _compassHeading = event.heading);
    });
  }

  Future<void> _loadLastAlert() async {
    final prefs = await SharedPreferences.getInstance();
    final lastAlert = prefs.getString('last_rocket_alert');
    if (lastAlert != null && mounted) {
      setState(() => _alertTime = DateTime.parse(lastAlert));
    }
  }

  void _triggerAlert() {
    if (_compassHeading == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يجب تحديد اتجاه الصوت أولاً'), backgroundColor: Colors.red));
      return;
    }
    final rocket = _rocketData[_selectedRocketType]!;
    final now = DateTime.now();
    final launchDir = (_compassHeading! + 180) % 360;
    final distance = rocket['range'] as int;
    
    final launchLat = 33.3152 + (distance / 111000) * cos(launchDir * pi / 180);
    final launchLon = 44.3661 + (distance / 111000) * sin(launchDir * pi / 180) / cos(33.3152 * pi / 180);
    
    String launchMgrs = 'غير معروف';
    try { launchMgrs = Mgrs.forward([launchLon, launchLat], 5); } catch (_) {}
    
    final tof = rocket['tof'] as int;
    final impactTime = now.add(Duration(seconds: tof));
    final safeDir = (launchDir + 180) % 360;
    
    if (mounted) {
      setState(() {
        _isAlert = true;
        _alertTime = now;
        _launchDirection = '${launchDir.toStringAsFixed(0)}° (${_degreesToDirection(launchDir)})';
        _estimatedOrigin = '$launchMgrs\n(${launchLat.toStringAsFixed(4)}, ${launchLon.toStringAsFixed(4)})';
        _impactTime = '${DateFormat('HH:mm:ss').format(impactTime)}\n(بعد $tof ثانية)';
        _safeZone = 'اتجاه ${safeDir.toStringAsFixed(0)}° (${_degreesToDirection(safeDir)})';
      });
    }
    
    SharedPreferences.getInstance().then((prefs) => prefs.setString('last_rocket_alert', now.toIso8601String()));
    HapticFeedback.heavyImpact();
    FlutterRingtonePlayer().playAlarm(looping: true);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('⚠️ تحذير: صاروخ ${rocket['name']} مكتشف!'), backgroundColor: Colors.red, duration: const Duration(seconds: 5)));
    }
  }

  void _stopAlert() {
    FlutterRingtonePlayer().stop();
    if (mounted) setState(() => _isAlert = false);
  }

  String _degreesToDirection(double degrees) {
    if (degrees >= 337.5 || degrees < 22.5) return 'شمال';
    if (degrees >= 22.5 && degrees < 67.5) return 'شمال شرق';
    if (degrees >= 67.5 && degrees < 112.5) return 'شرق';
    if (degrees >= 112.5 && degrees < 157.5) return 'جنوب شرق';
    if (degrees >= 157.5 && degrees < 202.5) return 'جنوب';
    if (degrees >= 202.5 && degrees < 247.5) return 'جنوب غرب';
    if (degrees >= 247.5 && degrees < 292.5) return 'غرب';
    return 'شمال غرب';
  }

  @override
  void dispose() {
    _compassSub?.cancel();
    FlutterRingtonePlayer().stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Provider.of<ThemeProvider>(context).colors;
    return Scaffold(
      backgroundColor: colors['bg'],
      appBar: AppBar(title: const Text('إنذار الصواريخ'), backgroundColor: colors['surface']),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: colors['surface'], borderRadius: BorderRadius.circular(12), border: Border.all(color: colors['border']!)),
              child: Column(
                children: [
                  Text('اتجاه الصوت المكتشف', style: TextStyle(color: colors['primary'], fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Container(
                    width: 200, height: 200,
                    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: colors['primary']!, width: 4)),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (_compassHeading != null) Transform.rotate(angle: _compassHeading! * pi / 180, child: const Icon(Icons.navigation, color: Colors.red, size: 60)),
                        Text('${_compassHeading?.toStringAsFixed(0) ?? '---'}°', style: TextStyle(color: colors['text'], fontSize: 24, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(_compassHeading != null ? _degreesToDirection(_compassHeading!) : 'في انتظار بيانات البوصلة', style: TextStyle(color: colors['text'], fontSize: 14)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: colors['surface'], borderRadius: BorderRadius.circular(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('نوع الصاروخ المعادي', style: TextStyle(color: colors['primary'], fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true, dropdownColor: colors['surface'], value: _selectedRocketType, style: TextStyle(color: colors['text']),
                      items: _rocketData.entries.map((e) => DropdownMenuItem(value: e.key, child: Text('${e.value['name']} (مدى: ${(e.value['range'] as int) ~/ 1000} كم)'))).toList(),
                      onChanged: (v) { if (v != null && mounted) setState(() => _selectedRocketType = v); },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (!_isAlert)
              ElevatedButton.icon(
                onPressed: _triggerAlert, icon: const Icon(Icons.warning, size: 28),
                label: const Text('تفعيل الإنذار (سمعت صوت إطلاق)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16)),
              )
            else
              Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.red.withOpacity(0.2), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red, width: 3)),
                    child: Column(
                      children: [
                        const Icon(Icons.warning, color: Colors.red, size: 60), const SizedBox(height: 8),
                        const Text('⚠️ تحذير صاروخي ⚠️', style: TextStyle(color: Colors.red, fontSize: 20, fontWeight: FontWeight.bold)), const SizedBox(height: 16),
                        _buildAlertRow('اتجاه الإطلاق', _launchDirection, Colors.red),
                        _buildAlertRow('نقطة الإطلاق التقديرية', _estimatedOrigin, Colors.orange),
                        _buildAlertRow('زمن الوصول', _impactTime, Colors.red),
                        _buildAlertRow('المنطقة الآمنة', _safeZone, Colors.green),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _stopAlert, icon: const Icon(Icons.check_circle), label: const Text('إلغاء الإنذار', style: TextStyle(fontSize: 16)),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                  ),
                ],
              ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: colors['warning']!.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: colors['warning']!)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [Icon(Icons.info_outline, color: colors['warning']), const SizedBox(width: 8), Text('تعليمات الاستخدام', style: TextStyle(color: colors['warning'], fontWeight: FontWeight.bold))]),
                  const SizedBox(height: 8),
                  Text('1. عند سماع صوت إطلاق صاروخ، وجّه هاتفك نحو مصدر الصوت', style: TextStyle(color: colors['text'], fontSize: 12)),
                  Text('2. اضغط زر "تفعيل الإنذار"', style: TextStyle(color: colors['text'], fontSize: 12)),
                  Text('3. التطبيق سيحسب اتجاه الإطلاق ونقطة السقوط التقديرية', style: TextStyle(color: colors['text'], fontSize: 12)),
                  Text('4. اتجه فوراً للمنطقة الآمنة المحددة', style: TextStyle(color: colors['text'], fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13))),
          Expanded(flex: 2, child: Text(value, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold), textAlign: TextAlign.end)),
        ],
      ),
    );
  }
}