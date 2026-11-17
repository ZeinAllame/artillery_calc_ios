import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:mgrs_dart/mgrs_dart.dart';
import '../../../theme/theme_provider.dart';
import '../../../services/data_service.dart';

class AdvancedToolsScreen extends StatefulWidget {
  final int initialIndex; // متغير لاستقبال رقم التبويب
  const AdvancedToolsScreen({Key? key, this.initialIndex = 0}) : super(key: key);

  @override
  State<AdvancedToolsScreen> createState() => _AdvancedToolsScreenState();
}

class _AdvancedToolsScreenState extends State<AdvancedToolsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    // تعيين التبويب المبدئي بناءً على الرقم القادم من القائمة
    _tabController = TabController(length: 9, vsync: this, initialIndex: widget.initialIndex);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Provider.of<ThemeProvider>(context).colors;

    return Scaffold(
      backgroundColor: colors['bg'],
      appBar: AppBar(
        title: const Text('الأدوات المتقدمة'),
        backgroundColor: colors['surface'],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: colors['primary'],
          labelColor: colors['primary'],
          unselectedLabelColor: colors['text']?.withOpacity(0.6),
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          unselectedLabelStyle: const TextStyle(fontSize: 12),
          isScrollable: true,
          tabs: const [
            Tab(text: 'هدف متحرك'),
            Tab(text: 'إزاحة الهدف'),
            Tab(text: 'الذخيرة المطلوبة'),
            Tab(text: 'قارئ الأوامر'),
            Tab(text: 'نقطة السقوط'),
            Tab(text: 'الانفجار الجوي'),
            Tab(text: 'وقت التهدئة'),
            Tab(text: 'سجل الطقس'),
            Tab(text: 'توزيع النيران'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          MovingTargetTab(),
          ShiftTargetTab(),
          RoundsRequiredTab(),
          CommandParserTab(),
          SpotPointTab(),
          AirburstTab(),
          CoolDownTab(),
          WeatherLogTab(),
          FireDistributionTab(),
        ],
      ),
    );
  }
}

// ============= مكونات مساعدة =============
Widget _buildMgrsRow(
  TextEditingController z, TextEditingController b,
  TextEditingController sq, TextEditingController e, TextEditingController n,
  Map<String, Color> colors,
) {
  InputDecoration deco(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: colors['text']?.withOpacity(0.4), fontSize: 12),
    contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
    isDense: true,
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: colors['border']!)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: colors['primary']!, width: 2)),
  );

  Widget field(TextEditingController c, String hint, {int flex = 1, bool isNum = true}) {
    return Expanded(
      flex: flex,
      child: TextField(
        controller: c,
        keyboardType: isNum ? TextInputType.number : TextInputType.text,
        textAlign: TextAlign.center,
        style: TextStyle(color: colors['text'], fontWeight: FontWeight.bold, fontSize: 16),
        decoration: deco(hint),
      ),
    );
  }

  return Row(
    children: [
      field(z, 'Zone', flex: 2),
      const SizedBox(width: 6),
      field(b, 'Band', flex: 2, isNum: false),
      const SizedBox(width: 6),
      field(sq, 'Sq', flex: 2, isNum: false),
      const SizedBox(width: 6),
      field(e, 'Easting', flex: 3),
      const SizedBox(width: 6),
      field(n, 'Northing', flex: 3),
    ],
  );
}

Widget _buildCalcButton(String text, VoidCallback onPressed, Map<String, Color> colors) {
  return SizedBox(
    width: double.infinity,
    child: ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: colors['primary'],
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(text, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
    ),
  );
}

Widget _buildResultRow(String label, String value, Map<String, Color> colors) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: colors['text']?.withOpacity(0.8), fontSize: 15)),
        Text(value, style: TextStyle(color: colors['primary'], fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    ),
  );
}

Widget _buildField(String label, TextEditingController ctrl, Map<String, Color> colors, {bool isNum = true}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: ctrl,
      keyboardType: isNum ? TextInputType.number : TextInputType.text,
      style: TextStyle(color: colors['text'], fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: colors['text']?.withOpacity(0.7), fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    ),
  );
}

// ============= 1. الهدف المتحرك =============
class MovingTargetTab extends StatefulWidget {
  const MovingTargetTab({Key? key}) : super(key: key);
  @override
  State<MovingTargetTab> createState() => _MovingTargetTabState();
}

class _MovingTargetTabState extends State<MovingTargetTab> {
  final zCtrl = TextEditingController(text: "38");
  final bCtrl = TextEditingController(text: "S");
  final sqCtrl = TextEditingController(text: "MB");
  final eCtrl = TextEditingController();
  final nCtrl = TextEditingController();
  final speedCtrl = TextEditingController();
  final azCtrl = TextEditingController();
  final tofCtrl = TextEditingController();

  String leadDist = "---";
  String newE = "---";
  String newN = "---";

  void _calculateLead() {
    final e = double.tryParse(eCtrl.text) ?? 0;
    final n = double.tryParse(nCtrl.text) ?? 0;
    final speedKmh = double.tryParse(speedCtrl.text) ?? 0;
    final azMils = double.tryParse(azCtrl.text) ?? 0;
    final tof = double.tryParse(tofCtrl.text) ?? 0;

    if (speedKmh == 0 || tof == 0) return;

    final speedMs = speedKmh / 3.6;
    final lead = speedMs * tof;
    final azRad = (azMils * 2 * pi) / 6400;
    final dE = lead * sin(azRad);
    final dN = lead * cos(azRad);

    setState(() {
      leadDist = "${lead.toStringAsFixed(0)} م";
      newE = (e + dE).toStringAsFixed(0);
      newN = (n + dN).toStringAsFixed(0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Provider.of<ThemeProvider>(context).colors;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('الهدف الحالي (MGRS):', style: TextStyle(color: colors['primary'], fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        _buildMgrsRow(zCtrl, bCtrl, sqCtrl, eCtrl, nCtrl, colors),
        const SizedBox(height: 16),
        _buildField('سرعة الهدف (كم/ساعة)', speedCtrl, colors),
        _buildField('اتجاه حركة الهدف (ملة)', azCtrl, colors),
        _buildField('زمن طيران القذيفة (ثانية)', tofCtrl, colors),
        const SizedBox(height: 12),
        _buildCalcButton('حساب نقطة الاعتراض', _calculateLead, colors),
        const SizedBox(height: 24),
        Text('النتائج:', style: TextStyle(color: colors['warning'], fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _buildResultRow('مسافة التقدم', leadDist, colors),
        _buildResultRow('الهدف الجديد E', newE, colors),
        _buildResultRow('الهدف الجديد N', newN, colors),
      ],
    );
  }
}

// ============= 2. إزاحة الهدف =============
class ShiftTargetTab extends StatefulWidget {
  const ShiftTargetTab({Key? key}) : super(key: key);
  @override
  State<ShiftTargetTab> createState() => _ShiftTargetTabState();
}

class _ShiftTargetTabState extends State<ShiftTargetTab> {
  final zCtrl = TextEditingController(text: "38");
  final bCtrl = TextEditingController(text: "S");
  final sqCtrl = TextEditingController(text: "MB");
  final eCtrl = TextEditingController();
  final nCtrl = TextEditingController();
  final lrCtrl = TextEditingController(text: "0");
  final adCtrl = TextEditingController(text: "0");

  String newE = "---";
  String newN = "---";

  void _calculateShift() {
    final e = double.tryParse(eCtrl.text) ?? 0;
    final n = double.tryParse(nCtrl.text) ?? 0;
    final lr = double.tryParse(lrCtrl.text) ?? 0;
    final ad = double.tryParse(adCtrl.text) ?? 0;
    setState(() {
      newE = (e + lr).toStringAsFixed(0);
      newN = (n + ad).toStringAsFixed(0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Provider.of<ThemeProvider>(context).colors;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('الهدف الأصلي (MGRS):', style: TextStyle(color: colors['primary'], fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        _buildMgrsRow(zCtrl, bCtrl, sqCtrl, eCtrl, nCtrl, colors),
        const SizedBox(height: 16),
        _buildField('يمين (+) / يسار (-) بالمتر', lrCtrl, colors),
        _buildField('زيادة (+) / نقصان (-) بالمتر', adCtrl, colors),
        const SizedBox(height: 12),
        _buildCalcButton('حساب الهدف الجديد', _calculateShift, colors),
        const SizedBox(height: 24),
        _buildResultRow('الهدف الجديد E', newE, colors),
        _buildResultRow('الهدف الجديد N', newN, colors),
      ],
    );
  }
}

// ============= 3. الذخيرة المطلوبة =============
class RoundsRequiredTab extends StatefulWidget {
  const RoundsRequiredTab({Key? key}) : super(key: key);
  @override
  State<RoundsRequiredTab> createState() => _RoundsRequiredTabState();
}

class _RoundsRequiredTabState extends State<RoundsRequiredTab> {
  final widthCtrl = TextEditingController();
  final lengthCtrl = TextEditingController();
  String selectedWeaponId = "mortar120";
  String rounds = "---";

  void _calculateRounds() {
    final w = double.tryParse(widthCtrl.text) ?? 0;
    final l = double.tryParse(lengthCtrl.text) ?? 0;
    if (w <= 0 || l <= 0) return;
    final area = w * l;
    double coverageArea = 100.0;
    if (selectedWeaponId == "mortar60" || selectedWeaponId == "mortar81") coverageArea = 50.0;
    if (selectedWeaponId == "howitzer155") coverageArea = 400.0;
    final req = (area / coverageArea).ceil();
    setState(() => rounds = "$req قذيفة");
  }

  @override
  Widget build(BuildContext context) {
    final colors = Provider.of<ThemeProvider>(context).colors;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(color: colors['surface'], borderRadius: BorderRadius.circular(8)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              dropdownColor: colors['surface'],
              value: selectedWeaponId,
              style: TextStyle(color: colors['text'], fontSize: 15),
              items: DataService.allWeapons.map((w) => DropdownMenuItem(
                value: w.id,
                child: Text(w.nameAr, style: TextStyle(color: colors['text'])),
              )).toList(),
              onChanged: (v) { if (v != null) setState(() => selectedWeaponId = v); },
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildField('عرض الهدف (متر)', widthCtrl, colors),
        _buildField('طول الهدف (متر)', lengthCtrl, colors),
        const SizedBox(height: 12),
        _buildCalcButton('حساب عدد القذائف', _calculateRounds, colors),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: colors['surface'], borderRadius: BorderRadius.circular(12)),
          child: Column(children: [
            Text('العدد المطلوب', style: TextStyle(color: colors['text']?.withOpacity(0.8), fontSize: 16)),
            const SizedBox(height: 8),
            Text(rounds, style: TextStyle(color: colors['warning'], fontSize: 28, fontWeight: FontWeight.bold)),
          ]),
        ),
      ],
    );
  }
}

// ============= 4. قارئ الأوامر =============
class CommandParserTab extends StatefulWidget {
  const CommandParserTab({Key? key}) : super(key: key);
  @override
  State<CommandParserTab> createState() => _CommandParserTabState();
}

class _CommandParserTabState extends State<CommandParserTab> {
  final textCtrl = TextEditingController();
  String mgrs = "---";
  String az = "---";
  String zone = "---";
  String band = "---";
  String square = "---";
  String easting = "---";
  String northing = "---";

  void _parseCommand() {
    final text = textCtrl.text.toUpperCase().replaceAll('ي', 'Y');
    final tenDigits = RegExp(r'\b(\d{10})\b').firstMatch(text);
    final fiveDigits = RegExp(r'\b(\d{5})\b').allMatches(text).toList();
    final zoneMatch = RegExp(r'\b(3[0-9])\b').firstMatch(text);
    final bandMatch = RegExp(r'\b(3[0-9])\s*([A-Z])\s*([A-Z]{2})').firstMatch(text);
    final azMatch = RegExp(r'(?:اتجاه|AZ|AZIMUTH|DIR|DIRECTION)[^\d]*(\d{3,4})').firstMatch(text);

    String? finalE;
    String? finalN;

    if (tenDigits != null) {
      finalE = tenDigits.group(1)!.substring(0, 5);
      finalN = tenDigits.group(1)!.substring(5, 10);
    } else if (fiveDigits.length >= 2) {
      finalE = fiveDigits[0].group(1);
      finalN = fiveDigits[1].group(1);
    }

    setState(() {
      zone = zoneMatch?.group(1) ?? "38";
      band = bandMatch?.group(2) ?? "S";
      square = bandMatch?.group(3) ?? "MB";
      easting = finalE ?? "-----";
      northing = finalN ?? "-----";
      az = azMatch?.group(1) ?? "---";

      if (finalE != null && finalN != null) {
        mgrs = "$zone$band$square$finalE$finalN";
      } else {
        mgrs = "لم يتم العثور على إحداثيات كاملة";
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Provider.of<ThemeProvider>(context).colors;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('مثال: الهدف 1 إحداثيات 38SMB1287718806 اتجاه 1200',
            style: TextStyle(color: colors['warning'], fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        TextField(
          controller: textCtrl, maxLines: 4,
          style: TextStyle(color: colors['text'], fontSize: 15),
          decoration: const InputDecoration(labelText: 'الصق أمر القيادة هنا...'),
        ),
        const SizedBox(height: 16),
        _buildCalcButton('تحليل الأمر', _parseCommand, colors),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: colors['surface'], borderRadius: BorderRadius.circular(12)),
          child: Column(children: [
            _buildResultRow('المنطقة/النطاق/المربع', '$zone$band$square', colors),
            const Divider(),
            _buildResultRow('Easting', easting, colors),
            const Divider(),
            _buildResultRow('Northing', northing, colors),
            const Divider(),
            _buildResultRow('الاتجاه', az, colors),
            const Divider(),
            _buildResultRow('MGRS الكامل', mgrs, colors),
          ]),
        ),
      ],
    );
  }
}

// ============= 5. نقطة السقوط =============
class SpotPointTab extends StatefulWidget {
  const SpotPointTab({Key? key}) : super(key: key);
  @override
  State<SpotPointTab> createState() => _SpotPointTabState();
}

class _SpotPointTabState extends State<SpotPointTab> {
  final zCtrl = TextEditingController(text: "38");
  final bCtrl = TextEditingController(text: "S");
  final sqCtrl = TextEditingController(text: "MB");
  final eCtrl = TextEditingController();
  final nCtrl = TextEditingController();
  final windSpeedCtrl = TextEditingController();
  final windDirCtrl = TextEditingController();
  final tofCtrl = TextEditingController();

  String impactE = "---";
  String impactN = "---";

  void _calculateSpot() {
    final e = double.tryParse(eCtrl.text) ?? 0;
    final n = double.tryParse(nCtrl.text) ?? 0;
    final wSpeed = double.tryParse(windSpeedCtrl.text) ?? 0;
    final wDir = double.tryParse(windDirCtrl.text) ?? 0;
    final tof = double.tryParse(tofCtrl.text) ?? 0;
    final drift = wSpeed * tof;
    final wRad = (wDir * 2 * pi) / 6400;
    setState(() {
      impactE = (e + drift * sin(wRad)).toStringAsFixed(0);
      impactN = (n + drift * cos(wRad)).toStringAsFixed(0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Provider.of<ThemeProvider>(context).colors;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('إحداثيات الهدف (MGRS):', style: TextStyle(color: colors['primary'], fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        _buildMgrsRow(zCtrl, bCtrl, sqCtrl, eCtrl, nCtrl, colors),
        const SizedBox(height: 16),
        _buildField('سرعة الرياح (م/ث)', windSpeedCtrl, colors),
        _buildField('اتجاه الرياح (ملة)', windDirCtrl, colors),
        _buildField('زمن الطيران (ثانية)', tofCtrl, colors),
        const SizedBox(height: 12),
        _buildCalcButton('حساب نقطة السقوط', _calculateSpot, colors),
        const SizedBox(height: 24),
        _buildResultRow('نقطة السقوط E', impactE, colors),
        _buildResultRow('نقطة السقوط N', impactN, colors),
      ],
    );
  }
}

// ============= 6. الانفجار الجوي =============
class AirburstTab extends StatefulWidget {
  const AirburstTab({Key? key}) : super(key: key);
  @override
  State<AirburstTab> createState() => _AirburstTabState();
}

class _AirburstTabState extends State<AirburstTab> {
  final tofCtrl = TextEditingController();
  final hobCtrl = TextEditingController(text: "10");
  String fuzeTime = "---";

  void _calculateAirburst() {
    final tof = double.tryParse(tofCtrl.text) ?? 0;
    final hob = double.tryParse(hobCtrl.text) ?? 0;
    if (tof > 0 && hob > 0) {
      setState(() => fuzeTime = "${(tof - (hob / 10)).toStringAsFixed(1)} ثانية");
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Provider.of<ThemeProvider>(context).colors;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildField('زمن الطيران الإجمالي (ثانية)', tofCtrl, colors),
        _buildField('ارتفاع الانفجار المطلوب (متر)', hobCtrl, colors),
        const SizedBox(height: 12),
        _buildCalcButton('حساب وقت ضبط الصمام', _calculateAirburst, colors),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: colors['surface'], borderRadius: BorderRadius.circular(12)),
          child: Column(children: [
            Text('يجب ضبط الصمام على', style: TextStyle(color: colors['text']?.withOpacity(0.8), fontSize: 16)),
            const SizedBox(height: 8),
            Text(fuzeTime, style: TextStyle(color: colors['warning'], fontSize: 28, fontWeight: FontWeight.bold)),
          ]),
        ),
      ],
    );
  }
}

// ============= 7. وقت التهدئة =============
class CoolDownTab extends StatefulWidget {
  const CoolDownTab({Key? key}) : super(key: key);
  @override
  State<CoolDownTab> createState() => _CoolDownTabState();
}

class _CoolDownTabState extends State<CoolDownTab> {
  final roundsCtrl = TextEditingController();
  Timer? _timer;
  int _secondsLeft = 0;
  bool _isRunning = false;

  void _startCoolDown() {
    final rounds = int.tryParse(roundsCtrl.text) ?? 0;
    if (rounds <= 0) return;
    setState(() { _secondsLeft = rounds * 10; _isRunning = true; });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() {
        if (_secondsLeft > 0) { _secondsLeft--; }
        else { _timer?.cancel(); _isRunning = false; }
      });
    });
  }

  void _stopCoolDown() {
    _timer?.cancel();
    setState(() { _isRunning = false; _secondsLeft = 0; });
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final colors = Provider.of<ThemeProvider>(context).colors;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildField('عدد الطلقات التي تم رميها', roundsCtrl, colors),
        const SizedBox(height: 12),
        _buildCalcButton(_isRunning ? 'جاري التهدئة...' : 'بدء وقت التهدئة', _isRunning ? () {} : _startCoolDown, colors),
        if (_isRunning) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _stopCoolDown,
              style: ElevatedButton.styleFrom(backgroundColor: colors['danger'], foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
              child: const Text('إيقاف', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
        ],
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: colors['surface'], borderRadius: BorderRadius.circular(12)),
          child: Column(children: [
            Text('الوقت المتبقي', style: TextStyle(color: colors['text']?.withOpacity(0.8), fontSize: 16)),
            const SizedBox(height: 8),
            Text('$_secondsLeft ثانية',
                style: TextStyle(color: _secondsLeft > 0 ? colors['warning'] : colors['primary'], fontSize: 40, fontWeight: FontWeight.bold)),
          ]),
        ),
      ],
    );
  }
}

// ============= 8. سجل الطقس =============
class WeatherLogTab extends StatefulWidget {
  const WeatherLogTab({Key? key}) : super(key: key);
  @override
  State<WeatherLogTab> createState() => _WeatherLogTabState();
}

class _WeatherLogTabState extends State<WeatherLogTab> {
  final tempCtrl = TextEditingController();
  final pressCtrl = TextEditingController();
  final windCtrl = TextEditingController();
  final dirCtrl = TextEditingController();
  List<Map<String, dynamic>> _logs = [];

  @override
  void initState() { super.initState(); _loadLogs(); }

  Future<void> _loadLogs() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString('weather_logs');
    if (s != null) setState(() => _logs = List<Map<String, dynamic>>.from(json.decode(s)));
  }

  Future<void> _addLog() async {
    if (tempCtrl.text.isEmpty) return;
    final newLog = {
      'date': DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now()),
      'temp': tempCtrl.text, 'press': pressCtrl.text,
      'wind': windCtrl.text, 'dir': dirCtrl.text,
    };
    setState(() => _logs.insert(0, newLog));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('weather_logs', json.encode(_logs));
    tempCtrl.clear(); pressCtrl.clear(); windCtrl.clear(); dirCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Provider.of<ThemeProvider>(context).colors;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            Row(children: [
              Expanded(child: _buildField('الحرارة (C)', tempCtrl, colors)),
              const SizedBox(width: 10),
              Expanded(child: _buildField('الضغط (hPa)', pressCtrl, colors)),
            ]),
            Row(children: [
              Expanded(child: _buildField('الرياح (م/ث)', windCtrl, colors)),
              const SizedBox(width: 10),
              Expanded(child: _buildField('الاتجاه (ملة)', dirCtrl, colors)),
            ]),
            _buildCalcButton('حفظ في السجل', _addLog, colors),
          ]),
        ),
        const Divider(),
        Expanded(
          child: _logs.isEmpty
              ? Center(child: Text('لا توجد سجلات', style: TextStyle(color: colors['text']?.withOpacity(0.6))))
              : ListView.builder(
                  itemCount: _logs.length,
                  itemBuilder: (c, i) {
                    final log = _logs[i];
                    return ListTile(
                      leading: Icon(Icons.cloud, color: colors['primary']),
                      title: Text(log['date'], style: TextStyle(color: colors['text'], fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: Text('حرارة: ${log['temp']}C | ضغط: ${log['press']} | رياح: ${log['wind']} @ ${log['dir']}',
                          style: TextStyle(color: colors['text']?.withOpacity(0.7), fontSize: 12)),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ============= 9. توزيع النيران =============
class FireDistributionTab extends StatefulWidget {
  const FireDistributionTab({Key? key}) : super(key: key);
  @override
  State<FireDistributionTab> createState() => _FireDistributionTabState();
}

class _FireDistributionTabState extends State<FireDistributionTab> {
  final totalRoundsCtrl = TextEditingController();
  final targetsCtrl = TextEditingController();
  String distribution = "---";

  void _distributeFire() {
    final total = int.tryParse(totalRoundsCtrl.text) ?? 0;
    final targets = int.tryParse(targetsCtrl.text) ?? 0;
    if (total <= 0 || targets <= 0) return;
    final perTarget = total ~/ targets;
    final remainder = total % targets;
    String result = "";
    for (int i = 1; i <= targets; i++) {
      final rounds = perTarget + (i <= remainder ? 1 : 0);
      result += "الهدف $i: $rounds قذيفة\n";
    }
    setState(() => distribution = result);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Provider.of<ThemeProvider>(context).colors;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildField('إجمالي القذائف المتاحة', totalRoundsCtrl, colors),
        _buildField('عدد الأهداف المطلوب ضربها', targetsCtrl, colors),
        const SizedBox(height: 12),
        _buildCalcButton('توزيع النيران بالتساوي', _distributeFire, colors),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: colors['surface'], borderRadius: BorderRadius.circular(12)),
          child: Text(distribution, style: TextStyle(color: colors['text'], fontSize: 16, height: 1.6)),
        ),
      ],
    );
  }
}