import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math';
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:mgrs_dart/mgrs_dart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

import '../../../theme/theme_provider.dart';
import '../../../models/models.dart';
import '../../widgets/app_drawer.dart' show rootScaffoldKey; // ← الاستيراد المهم
import 'target_log_screen.dart';

class TargetCalculatorScreen extends StatefulWidget {
  const TargetCalculatorScreen({Key? key}) : super(key: key);
  @override
  State<TargetCalculatorScreen> createState() => _TargetCalculatorScreenState();
}

class _TargetCalculatorScreenState extends State<TargetCalculatorScreen> {
  final obsZone = TextEditingController(text: "38");
  final obsBand = TextEditingController(text: "S");
  final obsSquare = TextEditingController(text: "MB");
  final obsE = TextEditingController(text: "35782");
  final obsN = TextEditingController(text: "84178");
  final distCtrl = TextEditingController();
  final azCtrl = TextEditingController();

  int selectedUnit = 6400;
  String resultE = "---";
  String resultN = "---";
  bool isLoadingGps = false;
  double calculatedDistance = 0;
  double calculatedAzimuth = 0;

  void _calculateTarget() {
    final e = double.tryParse(obsE.text) ?? 0;
    final n = double.tryParse(obsN.text) ?? 0;
    final dist = double.tryParse(distCtrl.text) ?? 0;
    final az = double.tryParse(azCtrl.text) ?? 0;
    if (dist == 0) return;
    final azRad = (az * 2 * pi) / selectedUnit;
    final dE = dist * sin(azRad);
    final dN = dist * cos(azRad);
    setState(() {
      calculatedDistance = dist;
      calculatedAzimuth = az;
      resultE = (e + dE).toStringAsFixed(0);
      resultN = (n + dN).toStringAsFixed(0);
    });
  }

  void _reversePosition() {
    final e = double.tryParse(obsE.text) ?? 0;
    final n = double.tryParse(obsN.text) ?? 0;
    final dist = double.tryParse(distCtrl.text) ?? 0;
    final az = double.tryParse(azCtrl.text) ?? 0;
    
    if (dist == 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أدخل المسافة والاتجاه أولاً')));
      return;
    }
    final azRad = (az * 2 * pi) / selectedUnit;
    final dE = dist * sin(azRad);
    final dN = dist * cos(azRad);
    setState(() {
      calculatedDistance = dist;
      calculatedAzimuth = az;
      resultE = (e - dE).toStringAsFixed(0);
      resultN = (n - dN).toStringAsFixed(0);
    });
  }

  Future<void> _sendToCalculator() async {
    if (resultE == "---") {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('احسب الهدف أولاً')));
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('calc_tgt_zone', obsZone.text);
    await prefs.setString('calc_tgt_band', obsBand.text);
    await prefs.setString('calc_tgt_sq', obsSquare.text);
    await prefs.setString('calc_tgt_e', resultE);
    await prefs.setString('calc_tgt_n', resultN);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ تم إرسال الهدف للحاسبة'), backgroundColor: Colors.green));
  }

  Future<void> _getGpsLocation() async {
    setState(() => isLoadingGps = true);
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.deniedForever) return;
      Position? pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      final point = [pos.longitude, pos.latitude];
      final mgrsStr = Mgrs.forward(point, 5);
      if (mounted) {
        setState(() {
          obsZone.text = mgrsStr.substring(0, 2);
          obsBand.text = mgrsStr.substring(2, 3);
          obsSquare.text = mgrsStr.substring(3, 5);
          obsE.text = mgrsStr.substring(5, 10);
          obsN.text = mgrsStr.substring(10, 15);
        });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر جلب الموقع')));
    } finally {
      if (mounted) setState(() => isLoadingGps = false);
    }
  }

  Future<void> _saveTargetDialog() async {
    if (resultE == "---") return;
    final nameCtrl = TextEditingController();
    final numberCtrl = TextEditingController();
    final natureCtrl = TextEditingController();
    final colors = Provider.of<ThemeProvider>(context, listen: false).colors;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: colors['surface'],
        title: Text('حفظ الهدف', style: TextStyle(color: colors['text'])),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'اسم الهدف')),
          TextField(controller: numberCtrl, decoration: const InputDecoration(labelText: 'رقم الهدف')),
          TextField(controller: natureCtrl, decoration: const InputDecoration(labelText: 'طبيعة الهدف')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: colors['primary']),
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              final targetsJson = prefs.getString('saved_targets');
              List<SavedTarget> targets = targetsJson != null ? (json.decode(targetsJson) as List).map((e) => SavedTarget.fromJson(e)).toList() : [];
              final obsMgrs = "${obsZone.text}${obsBand.text}${obsSquare.text}${obsE.text}${obsN.text}";
              final tgtMgrs = "${obsZone.text}${obsBand.text}${obsSquare.text}$resultE$resultN";
              targets.insert(0, SavedTarget(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                name: nameCtrl.text, targetNumber: numberCtrl.text, targetNature: natureCtrl.text,
                observerMgrs: obsMgrs, targetMgrs: tgtMgrs, distance: calculatedDistance, azimuth: calculatedAzimuth,
                date: DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now()),
              ));
              await prefs.setString('saved_targets', json.encode(targets.map((e) => e.toJson()).toList()));
              if (mounted) Navigator.pop(context);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Provider.of<ThemeProvider>(context).colors;
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
        title: const Text('حاسبة الهدف'),
        backgroundColor: colors['surface'],
        actions: [
          IconButton(icon: Icon(Icons.list_alt, color: colors['primary']), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TargetLogScreen()))),
          DropdownButtonHideUnderline(child: DropdownButton<int>(
            dropdownColor: colors['surface'], value: selectedUnit,
            style: TextStyle(color: colors['primary'], fontWeight: FontWeight.bold),
            items: const [DropdownMenuItem(value: 6400, child: Text('6400')), DropdownMenuItem(value: 6000, child: Text('6000')), DropdownMenuItem(value: 360, child: Text('360'))],
            onChanged: (v) { if (v != null) setState(() => selectedUnit = v); },
          )),
          const SizedBox(width: 16),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('مكان الراصد (E/N)', style: TextStyle(color: colors['text'], fontWeight: FontWeight.bold)),
            IconButton(onPressed: isLoadingGps ? null : _getGpsLocation,
                icon: isLoadingGps ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.gps_fixed, color: Colors.cyan)),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: TextField(controller: obsZone, decoration: const InputDecoration(labelText: 'Zone'), keyboardType: TextInputType.number)),
            const SizedBox(width: 5), Expanded(child: TextField(controller: obsBand, decoration: const InputDecoration(labelText: 'Band'))),
            const SizedBox(width: 5), Expanded(child: TextField(controller: obsSquare, decoration: const InputDecoration(labelText: 'Sq'))),
            const SizedBox(width: 5), Expanded(flex: 2, child: TextField(controller: obsE, decoration: const InputDecoration(labelText: 'E'), keyboardType: TextInputType.number)),
            const SizedBox(width: 5), Expanded(flex: 2, child: TextField(controller: obsN, decoration: const InputDecoration(labelText: 'N'), keyboardType: TextInputType.number)),
          ]),
          const SizedBox(height: 15),
          TextField(controller: distCtrl, decoration: const InputDecoration(labelText: 'المسافة (م)'), keyboardType: TextInputType.number),
          const SizedBox(height: 10),
          TextField(controller: azCtrl, decoration: InputDecoration(labelText: 'الاتجاه (${selectedUnit == 360 ? "°" : "مل"})'), keyboardType: TextInputType.number),
          const SizedBox(height: 20),
          ElevatedButton(onPressed: _calculateTarget, style: ElevatedButton.styleFrom(backgroundColor: colors['primary'], foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 16)),
              child: const Text('حساب إحداثيات الهدف (Forward)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
          const SizedBox(height: 8),
          ElevatedButton.icon(onPressed: _reversePosition, icon: const Icon(Icons.gps_off), label: const Text('حساب الموقع العكسي (Reverse)'),
              style: ElevatedButton.styleFrom(backgroundColor: colors['surfaceLight'], foregroundColor: colors['text'], padding: const EdgeInsets.symmetric(vertical: 14))),
          const SizedBox(height: 24),
          Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: colors['surfaceLight'], borderRadius: BorderRadius.circular(12), border: Border.all(color: colors['primary']!)),
              child: Column(children: [
                Text('إحداثيات الهدف', style: TextStyle(color: colors['secondary'], fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Text('E: $resultE', style: TextStyle(color: colors['text'], fontSize: 24, fontWeight: FontWeight.bold)),
                Text('N: $resultN', style: TextStyle(color: colors['text'], fontSize: 24, fontWeight: FontWeight.bold)),
              ])),
          const SizedBox(height: 20),
          if (resultE != "---") ElevatedButton.icon(onPressed: _saveTargetDialog, icon: const Icon(Icons.save), label: const Text('حفظ معلومات الهدف'), style: ElevatedButton.styleFrom(backgroundColor: colors['secondary'], foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14))),
          const SizedBox(height: 8),
          if (resultE != "---") ElevatedButton.icon(onPressed: _sendToCalculator, icon: const Icon(Icons.send), label: const Text('إرسال للحاسبة الرئيسية'), style: ElevatedButton.styleFrom(backgroundColor: colors['primary'], foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 14))),
        ],
      ),
    );
  }
}