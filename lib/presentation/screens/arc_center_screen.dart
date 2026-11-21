import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mgrs_dart/mgrs_dart.dart';

import '../../theme/theme_provider.dart';
import '../../domain/mgrs_decoder.dart';
import '../../utils/event_bus.dart';

class ArcCenterScreen extends StatefulWidget {
  const ArcCenterScreen({Key? key}) : super(key: key);
  @override
  State<ArcCenterScreen> createState() => _ArcCenterScreenState();
}

class _ArcCenterScreenState extends State<ArcCenterScreen> {
  final gunZone = TextEditingController(text: "38");
  final gunBand = TextEditingController(text: "S");
  final gunSquare = TextEditingController(text: "MB");
  final gunE = TextEditingController();
  final gunN = TextEditingController();
  double gunUtmE = 0, gunUtmN = 0;
  bool _loadingGunGps = false;

  List<Map<String, dynamic>> _folders = [];
  int _currentFolder = 0;
  int _dirUnit = 6400;

  List<Map<String, dynamic>> _results = [];
  int _centerIdx = 0;
  double _centerAz = 0;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    gunZone.dispose(); gunBand.dispose(); gunSquare.dispose();
    gunE.dispose(); gunN.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    final p = await SharedPreferences.getInstance();
    final fJson = p.getString('arc_folders');
    final gJson = p.getString('arc_gun');
    final unit = p.getInt('arc_unit');
    final cur = p.getInt('arc_current_folder') ?? 0;
    if (!mounted) return;
    setState(() {
      if (unit != null) _dirUnit = unit;
      if (fJson != null) {
        _folders = List<Map<String, dynamic>>.from(json.decode(fJson));
      }
      if (_folders.isEmpty) {
        _folders = [{'name': 'مجلد 1', 'targets': []}];
      }
      _currentFolder = cur.clamp(0, _folders.length - 1);
      if (gJson != null) {
        final g = json.decode(gJson) as Map<String, dynamic>;
        gunZone.text = g['zone'] ?? "38";
        gunBand.text = g['band'] ?? "S";
        gunSquare.text = g['sq'] ?? "MB";
        gunE.text = g['e'] ?? "";
        gunN.text = g['n'] ?? "";
        gunUtmE = (g['utmE'] ?? 0).toDouble();
        gunUtmN = (g['utmN'] ?? 0).toDouble();
      }
    });
  }

  Future<void> _saveAll() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('arc_folders', json.encode(_folders));
    await p.setInt('arc_unit', _dirUnit);
    await p.setInt('arc_current_folder', _currentFolder);
    await p.setString('arc_gun', json.encode({
      'zone': gunZone.text, 'band': gunBand.text, 'sq': gunSquare.text,
      'e': gunE.text, 'n': gunN.text, 'utmE': gunUtmE, 'utmN': gunUtmN,
    }));
  }

  void _decodeGun() {
    final mgrs = "${gunZone.text}${gunBand.text}${gunSquare.text}${gunE.text}${gunN.text}";
    final utm = MgrsDecoder.decode(mgrs);
    if (utm != null) {
      setState(() { gunUtmE = utm.easting; gunUtmN = utm.northing; });
    } else {
      setState(() { gunUtmE = 0; gunUtmN = 0; });
    }
    _saveAll();
  }

  Future<void> _getGunGps() async {
    setState(() => _loadingGunGps = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.deniedForever) return;
      final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      final mgrsStr = Mgrs.forward([position.longitude, position.latitude], 5);
      if (!mounted) return;
      setState(() {
        gunZone.text = mgrsStr.substring(0, 2);
        gunBand.text = mgrsStr.substring(2, 3);
        gunSquare.text = mgrsStr.substring(3, 5);
        gunE.text = mgrsStr.substring(5, 10);
        gunN.text = mgrsStr.substring(10, 15);
      });
      _decodeGun();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم جلب موقع المدفع'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر جلب الموقع'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _loadingGunGps = false);
    }
  }

  void _newFolder() {
    final ctrl = TextEditingController();
    final colors = Provider.of<ThemeProvider>(context, listen: false).colors;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors['surface'],
        title: Text('مجلد جديد', style: TextStyle(color: colors['text'])),
        content: TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'اسم المجلد')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () {
            if (ctrl.text.isNotEmpty) {
              setState(() {
                _folders.add({'name': ctrl.text, 'targets': []});
                _currentFolder = _folders.length - 1;
                _results = [];
              });
              _saveAll();
              Navigator.pop(ctx);
            }
          }, child: const Text('إنشاء')),
        ],
      ),
    );
  }

  void _deleteFolder() {
    if (_folders.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يمكن حذف آخر مجلد'), backgroundColor: Colors.orange));
      return;
    }
    setState(() {
      _folders.removeAt(_currentFolder);
      _currentFolder = _currentFolder.clamp(0, _folders.length - 1);
      _results = [];
    });
    _saveAll();
  }

  List _targetsOfCurrent() => (_folders[_currentFolder]['targets'] as List);

  void _addTarget() {
    final nameCtrl = TextEditingController(text: 'هدف ${_targetsOfCurrent().length + 1}');
    final zCtrl = TextEditingController(text: gunZone.text);
    final bCtrl = TextEditingController(text: gunBand.text);
    final sCtrl = TextEditingController(text: gunSquare.text);
    final eCtrl = TextEditingController();
    final nCtrl = TextEditingController();
    final colors = Provider.of<ThemeProvider>(context, listen: false).colors;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors['surface'],
        title: Text('إضافة هدف', style: TextStyle(color: colors['text'])),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'اسم الهدف')),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: TextField(controller: zCtrl, maxLength: 2, decoration: const InputDecoration(labelText: 'Zone'))),
                const SizedBox(width: 5),
                Expanded(child: TextField(controller: bCtrl, maxLength: 1, decoration: const InputDecoration(labelText: 'Band'))),
                const SizedBox(width: 5),
                Expanded(child: TextField(controller: sCtrl, maxLength: 2, decoration: const InputDecoration(labelText: 'Sq'))),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: TextField(controller: eCtrl, maxLength: 5, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Easting'))),
                const SizedBox(width: 5),
                Expanded(child: TextField(controller: nCtrl, maxLength: 5, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Northing'))),
              ]),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () {
            final mgrs = "${zCtrl.text}${bCtrl.text}${sCtrl.text}${eCtrl.text}${nCtrl.text}";
            final utm = MgrsDecoder.decode(mgrs);
            if (utm == null) {
              ScaffoldMessenger.of(ctx).showSnackBar(
                const SnackBar(content: Text('MGRS غير صحيح'), backgroundColor: Colors.red));
              return;
            }
            (_folders[_currentFolder]['targets'] as List).add({
              'name': nameCtrl.text,
              'zone': zCtrl.text, 'band': bCtrl.text, 'sq': sCtrl.text,
              'e': eCtrl.text, 'n': nCtrl.text,
              'utmE': utm.easting, 'utmN': utm.northing,
            });
            setState(() => _results = []);
            _saveAll();
            Navigator.pop(ctx);
          }, child: const Text('إضافة')),
        ],
      ),
    );
  }

  void _deleteTarget(int i) {
    setState(() {
      (_folders[_currentFolder]['targets'] as List).removeAt(i);
      _results = [];
    });
    _saveAll();
  }

  // ★★ إرسال الهدف إلى حاسبة الرمي — يعمل فورياً عبر EventBus ★★
  Future<void> _sendToCalculator(Map<String, dynamic> t) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('calc_tgt_zone', t['zone']);
    await p.setString('calc_tgt_band', t['band']);
    await p.setString('calc_tgt_sq', t['sq']);
    await p.setString('calc_tgt_e', t['e']);
    await p.setString('calc_tgt_n', t['n']);

    // ★ بث الحدث — الحاسبة تستمع له حتى لو كانت مفتوحة ★
    EventBus.instance.emit(AppEvent(kTargetSentEvent));

    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(rootScaffoldMessengerContext ?? context).showSnackBar(
      SnackBar(content: Text('تم إرسال "${t['name']}" إلى الحاسبة'), backgroundColor: Colors.green));
  }

  BuildContext? get rootScaffoldMessengerContext => null;

  double _azToUnit(double dE, double dN) {
    var azDeg = math.atan2(dE, dN) * 180 / math.pi;
    if (azDeg < 0) azDeg += 360;
    return azDeg * _dirUnit / 360.0;
  }

  double _normalize(double diff) {
    final half = _dirUnit / 2;
    var d = diff;
    while (d > half) d -= _dirUnit;
    while (d < -half) d += _dirUnit;
    return d;
  }

  // ★★ الحساب المحدّث: يقبل 1 أو 2 أو أكثر ★★
  void _calculate() {
    final targets = _targetsOfCurrent();
    if (gunUtmE == 0 && gunUtmN == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أدخل أو اجلب إحداثيات المدفع'), backgroundColor: Colors.red));
      return;
    }
    if (targets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أضف هدفاً واحداً على الأقل'), backgroundColor: Colors.orange));
      return;
    }

    final list = <Map<String, dynamic>>[];
    for (var t in targets) {
      final dE = t['utmE'] - gunUtmE;
      final dN = t['utmN'] - gunUtmN;
      list.add({...t, 'az': _azToUnit(dE, dN)});
    }

    int centerIdx;
    double centerAz;

    if (list.length == 1) {
      // ★ هدف واحد: المركز = نفس الهدف
      centerIdx = 0;
      centerAz = list[0]['az'] as double;
    } else if (list.length == 2) {
      // ★ هدفان: المركز = المتوسط الدائري بينهما
      final a1 = list[0]['az'] as double;
      final a2 = list[1]['az'] as double;
      final r1 = a1 * 2 * math.pi / _dirUnit;
      final r2 = a2 * 2 * math.pi / _dirUnit;
      final x = math.cos(r1) + math.cos(r2);
      final y = math.sin(r1) + math.sin(r2);
      var mid = math.atan2(y, x) * _dirUnit / (2 * math.pi);
      if (mid < 0) mid += _dirUnit;
      centerAz = mid;
      // نختار الهدف الأقرب لخط المركز ليُعرض كنجم
      final d1 = _normalize(a1 - centerAz).abs();
      final d2 = _normalize(a2 - centerAz).abs();
      centerIdx = d1 <= d2 ? 0 : 1;
    } else {
      // ★ 3+ أهداف: الترتيب واختيار الأوسط
      list.sort((a, b) => (a['az'] as double).compareTo(b['az'] as double));
      centerIdx = list.length ~/ 2;
      centerAz = list[centerIdx]['az'] as double;
    }

    for (var i = 0; i < list.length; i++) {
      list[i]['deviation'] = _normalize((list[i]['az'] as double) - centerAz);
      list[i]['isCenter'] = (i == centerIdx);
    }

    setState(() {
      _results = list;
      _centerIdx = centerIdx;
      _centerAz = centerAz;
    });
    _saveAll();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Provider.of<ThemeProvider>(context).colors;
    final targets = _targetsOfCurrent();

    return Scaffold(
      backgroundColor: colors['bg'],
      appBar: AppBar(
        title: const Text('سجل الأهداف ومركز القوس'),
        backgroundColor: colors['surface'],
        actions: [
          IconButton(icon: const Icon(Icons.create_new_folder), onPressed: _newFolder, tooltip: 'مجلد جديد'),
          IconButton(icon: const Icon(Icons.delete_forever, color: Colors.red), onPressed: _deleteFolder, tooltip: 'حذف المجلد'),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: colors['surface'], borderRadius: BorderRadius.circular(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('المجلد الحالي', style: TextStyle(color: colors['primary'], fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    isExpanded: true,
                    dropdownColor: colors['surface'],
                    value: _currentFolder,
                    style: TextStyle(color: colors['text']),
                    items: List.generate(_folders.length, (i) => DropdownMenuItem(
                      value: i,
                      child: Text('${_folders[i]['name']}  (${(_folders[i]['targets'] as List).length} هدف)'))),
                    onChanged: (v) { if (v != null) setState(() { _currentFolder = v; _results = []; }); },
                  ),
                ),
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
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('إحداثيات المدفع (MGRS)', style: TextStyle(color: colors['primary'], fontWeight: FontWeight.bold)),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: _loadingGunGps ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.gps_fixed, color: Colors.cyan),
                    onPressed: _loadingGunGps ? null : _getGunGps,
                  ),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: _mgrsField(gunZone, "Zone", 2, colors, () => _decodeGun())),
                  const SizedBox(width: 5),
                  Expanded(child: _mgrsField(gunBand, "Band", 1, colors, () => _decodeGun())),
                  const SizedBox(width: 5),
                  Expanded(child: _mgrsField(gunSquare, "Sq", 2, colors, () => _decodeGun())),
                  const SizedBox(width: 5),
                  Expanded(child: _mgrsField(gunE, "E", 5, colors, () => _decodeGun())),
                  const SizedBox(width: 5),
                  Expanded(child: _mgrsField(gunN, "N", 5, colors, () => _decodeGun())),
                ]),
                if (gunUtmE != 0 || gunUtmN != 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text('UTM: E ${gunUtmE.toStringAsFixed(0)}  N ${gunUtmN.toStringAsFixed(0)}',
                        style: TextStyle(color: colors['text']?.withOpacity(0.6), fontSize: 11)),
                  ),
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
                Text('وحدة القياس', style: TextStyle(color: colors['primary'], fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(children: [360, 6000, 6400].map((u) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: ChoiceChip(
                      label: Text(u == 360 ? '360°' : '$u مل', style: const TextStyle(fontSize: 12)),
                      selected: _dirUnit == u,
                      selectedColor: colors['primary'],
                      backgroundColor: colors['bg'],
                      labelStyle: TextStyle(color: _dirUnit == u ? Colors.black : colors['text']),
                      onSelected: (s) { if (s) { setState(() => _dirUnit = u); _saveAll(); if (_results.isNotEmpty) _calculate(); } },
                    ),
                  ),
                )).toList()),
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
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('الأهداف (${targets.length})', style: TextStyle(color: colors['primary'], fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.add_circle), onPressed: _addTarget),
                ]),
                if (targets.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text('لا توجد أهداف — اضغط + لإضافة', style: TextStyle(color: colors['text']?.withOpacity(0.6))),
                  )
                else
                  ...targets.asMap().entries.map((e) => Card(
                    color: colors['bg'],
                    child: ListTile(
                      leading: CircleAvatar(backgroundColor: colors['surface'], child: Text('${e.key + 1}', style: TextStyle(color: colors['text']))),
                      title: Text(e.value['name'] ?? '', style: TextStyle(color: colors['text'])),
                      subtitle: Text('${e.value['zone']}${e.value['band']}${e.value['sq']} ${e.value['e']}${e.value['n']}',
                          style: TextStyle(color: colors['text']?.withOpacity(0.7), fontSize: 11)),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(icon: const Icon(Icons.send, color: Colors.cyan, size: 20),
                          onPressed: () => _sendToCalculator(e.value), tooltip: 'إرسال للحاسبة'),
                        IconButton(icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                          onPressed: () => _deleteTarget(e.key)),
                      ]),
                    ),
                  )),
              ],
            ),
          ),
          const SizedBox(height: 16),

          ElevatedButton.icon(
            onPressed: _calculate,
            icon: const Icon(Icons.architecture),
            label: const Text('حساب مركز القوس', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(backgroundColor: colors['primary'], foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 16)),
          ),
          const SizedBox(height: 16),

          if (_results.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: colors['surface'], borderRadius: BorderRadius.circular(12), border: Border.all(color: colors['primary']!, width: 2)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('نتائج مركز القوس', style: TextStyle(color: colors['primary'], fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  SizedBox(height: 200, width: double.infinity, child: CustomPaint(painter: _ArcPainter(results: _results, centerIdx: _centerIdx, dirUnit: _dirUnit))),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: colors['primary']!.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                    child: Row(children: [
                      Icon(Icons.flag, color: colors['primary']),
                      const SizedBox(width: 8),
                      Expanded(child: Text(
                        _results.length == 1
                            ? 'الاتجاه: ${_results[0]['az'].toStringAsFixed(0)} ${_dirUnit == 360 ? '°' : 'مل'}'
                            : _results.length == 2
                                ? 'خط المركز: ${_centerAz.toStringAsFixed(0)} ${_dirUnit == 360 ? '°' : 'مل'} (منتصف الهدفين)'
                                : 'المركز: ${_results[_centerIdx]['name']}  |  الاتجاه: ${_results[_centerIdx]['az'].toStringAsFixed(0)} ${_dirUnit == 360 ? '°' : 'مل'}',
                        style: TextStyle(color: colors['primary'], fontWeight: FontWeight.bold, fontSize: 13))),
                    ]),
                  ),
                  const SizedBox(height: 12),
                  ..._results.map((t) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(children: [
                      Icon(t['isCenter'] ? Icons.star : Icons.circle, size: 14, color: t['isCenter'] ? Colors.amber : colors['text']),
                      const SizedBox(width: 8),
                      Expanded(child: Text(t['name'] ?? '', style: TextStyle(color: colors['text'], fontSize: 13))),
                      Text(
                        '${(t['deviation'] as double) > 0 ? "+" : ""}${(t['deviation'] as double).toStringAsFixed(0)}',
                        style: TextStyle(
                          color: (t['deviation'] as double) == 0 ? Colors.green : ((t['deviation'] as double) > 0 ? Colors.orange : Colors.blueGrey),
                          fontWeight: FontWeight.bold, fontSize: 14)),
                      Text(' ${_dirUnit == 360 ? '°' : 'مل'}', style: TextStyle(color: colors['text']?.withOpacity(0.6), fontSize: 11)),
                    ]),
                  )),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _mgrsField(TextEditingController c, String label, int max, Map<String, Color> colors, VoidCallback onDone) {
    return TextField(
      controller: c, maxLength: max, textAlign: TextAlign.center,
      style: TextStyle(color: colors['text'], fontWeight: FontWeight.bold),
      onSubmitted: (_) => onDone(),
      decoration: InputDecoration(labelText: label, counterText: "", isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4)),
    );
  }
}

class _ArcPainter extends CustomPainter {
  final List results;
  final int centerIdx;
  final int dirUnit;
  _ArcPainter({required this.results, required this.centerIdx, required this.dirUnit});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.92);
    final radius = size.height * 0.78;

    final gridPaint = Paint()..color = Colors.white.withOpacity(0.08)..style = PaintingStyle.stroke..strokeWidth = 1;
    canvas.drawCircle(center, radius, gridPaint);
    canvas.drawCircle(center, radius * 0.66, gridPaint);
    canvas.drawCircle(center, radius * 0.33, gridPaint);

    final northPaint = Paint()..color = Colors.white.withOpacity(0.25)..strokeWidth = 1;
    canvas.drawLine(center, Offset(center.dx, center.dy - radius), northPaint);

    Offset posOf(double az) {
      final rad = (az * 2 * math.pi) / dirUnit;
      return Offset(center.dx + radius * math.sin(rad), center.dy - radius * math.cos(rad));
    }

    // ★ خط المركز (حتى لو هدفان — يرسم المتوسط) ★
    if (results.isNotEmpty) {
      double centerAz;
      if (results.length == 2) {
        final a1 = results[0]['az'] as double;
        final a2 = results[1]['az'] as double;
        final r1 = a1 * 2 * math.pi / dirUnit;
        final r2 = a2 * 2 * math.pi / dirUnit;
        final x = math.cos(r1) + math.cos(r2);
        final y = math.sin(r1) + math.sin(r2);
        var mid = math.atan2(y, x) * dirUnit / (2 * math.pi);
        if (mid < 0) mid += dirUnit;
        centerAz = mid;
      } else {
        centerAz = results[centerIdx]['az'] as double;
      }
      final centerLine = Paint()..color = Colors.amber..strokeWidth = 2.5;
      canvas.drawLine(center, posOf(centerAz), centerLine);
    }

    for (var i = 0; i < results.length; i++) {
      final az = results[i]['az'] as double;
      final pos = posOf(az);
      final isC = i == centerIdx;
      canvas.drawLine(center, pos, Paint()..color = (isC ? Colors.amber : Colors.cyan).withOpacity(0.5)..strokeWidth = 1.5);
      canvas.drawCircle(pos, isC ? 8 : 6, Paint()..color = isC ? Colors.amber : Colors.cyan);
    }

    canvas.drawCircle(center, 7, Paint()..color = Colors.red);
    _label(canvas, 'المدفع', Offset(center.dx, center.dy + 14), 11, Colors.red, size);
  }

  void _label(Canvas canvas, String text, Offset pos, double fs, Color color, Size size) {
    final tp = TextPainter(text: TextSpan(text: text, style: TextStyle(fontSize: fs, fontWeight: FontWeight.bold, color: color)), textDirection: ui.TextDirection.rtl);
    tp.layout();
    final x = (pos.dx - tp.width / 2).clamp(2.0, size.width - tp.width - 2);
    final y = (pos.dy - tp.height / 2).clamp(2.0, size.height - tp.height - 2);
    tp.paint(canvas, Offset(x, y));
  }

  @override
  bool shouldRepaint(covariant _ArcPainter old) => true;
}