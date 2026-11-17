import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mgrs_dart/mgrs_dart.dart';

import '../../../theme/theme_provider.dart';
import '../../../theme/settings_provider.dart';
import '../../../domain/mgrs_decoder.dart';
import '../../../domain/firing_table.dart';
import '../../../domain/ballistics.dart';
import '../../../domain/weather_service.dart';
import '../../../services/data_service.dart';
import '../../../models/models.dart';
import '../../widgets/weather_dialog.dart';
import '../gun_laying/gun_laying_screen.dart';
import 'fire_mission_log_screen.dart';
import 'mrsi_screen.dart';
import '../advanced_tools/advanced_tools_screen.dart';
import '../advanced_tools/manual_table_screen.dart';
import '../settings/settings_screen.dart';
import '../manuals/manuals_screen.dart';
import '../../widgets/acoustic_mesh_screen.dart';

class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({Key? key}) : super(key: key);
  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> with WidgetsBindingObserver {
  final gunZone = TextEditingController();
  final gunBand = TextEditingController();
  final gunSquare = TextEditingController();
  final gunE = TextEditingController();
  final gunN = TextEditingController();
  final barrelWearCtrl = TextEditingController();

  final tgtZone = TextEditingController(text: "38");
  final tgtBand = TextEditingController(text: "S");
  final tgtSquare = TextEditingController(text: "MB");
  final tgtE = TextEditingController(text: "35995");
  final tgtN = TextEditingController(text: "83060");

  String selectedWeaponId = "mortar120";
  String selectedWeaponName = "هاون 120 ملم M120/M220";
  ShellType selectedShellType = ShellType.he;
  ShellCountry selectedCountry = ShellCountry.usa;

  String? selectedShellName; // ستحتوي على "الاسم (البلد)"
  int? selectedManualCharge;
  List<Map<String, dynamic>> savedAmmoList = [];

  bool isTrainingMode = false;
  bool isHighAngle = false;

  double burstHeight = 15.0;
  bool get isSpecialShell =>
      selectedShellType == ShellType.airburst || selectedShellType == ShellType.illumination;

  double temp = 15.0;
  double pressure = 1013.25;
  double windSpeed = 0.0;
  double windDir = 0.0;
  bool isLoadingWeather = false;
  bool isLoadingGunGps = false;

  double baseDist = 0;
  double baseAz = 0;
  double corrDist = 0;
  double corrAz = 0;

  String resultDist = "---";
  String resultAz = "---";
  String resultEl = "---";
  String resultCharge = "---";
  String resultTof = "---";
  String resultFuse = "---";
  String resultRecommended = "---";
  String weatherCorrInfo = "لم يتم جلب الطقس بعد";

  List<int> availableCharges = [];

  Timer? _timer;
  double _timeLeft = 0.0;
  bool _isTimerRunning = false;

  final ScrollController _scrollCtrl = ScrollController();
  final GlobalKey _resultsKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadAmmoFromTracker();
    _checkForIncomingTarget();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final sp = Provider.of<SettingsProvider>(context, listen: false);
      _loadGunData(sp.gunNumber);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkForIncomingTarget();
  }

  Future<void> _loadGunData(int gunNum) async {
    final p = await SharedPreferences.getInstance();
    setState(() {
      gunZone.text = p.getString('gun_${gunNum}_zone') ?? "38";
      gunBand.text = p.getString('gun_${gunNum}_band') ?? "S";
      gunSquare.text = p.getString('gun_${gunNum}_sq') ?? "MB";
      gunE.text = p.getString('gun_${gunNum}_e') ?? "35782";
      gunN.text = p.getString('gun_${gunNum}_n') ?? "84178";
      barrelWearCtrl.text = (p.getInt('gun_${gunNum}_wear') ?? 0).toString();
    });
  }

  Future<void> _saveGunData(int gunNum) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('gun_${gunNum}_zone', gunZone.text);
    await p.setString('gun_${gunNum}_band', gunBand.text);
    await p.setString('gun_${gunNum}_sq', gunSquare.text);
    await p.setString('gun_${gunNum}_e', gunE.text);
    await p.setString('gun_${gunNum}_n', gunN.text);
    await p.setInt('gun_${gunNum}_wear', int.tryParse(barrelWearCtrl.text) ?? 0);
  }

  Future<void> _checkForIncomingTarget() async {
    final prefs = await SharedPreferences.getInstance();
    final incomingE = prefs.getString('calc_tgt_e');
    if (incomingE != null) {
      setState(() {
        tgtZone.text = prefs.getString('calc_tgt_zone') ?? "38";
        tgtBand.text = prefs.getString('calc_tgt_band') ?? "S";
        tgtSquare.text = prefs.getString('calc_tgt_sq') ?? "MB";
        tgtE.text = incomingE;
        tgtN.text = prefs.getString('calc_tgt_n') ?? "83060";
      });
      await prefs.remove('calc_tgt_e');
      _calculateBase();
    }
  }

  Future<void> _loadAmmoFromTracker() async {
    final prefs = await SharedPreferences.getInstance();
    final ammoJson = prefs.getString('ammo_inventory');
    if (ammoJson != null) {
      setState(() {
        savedAmmoList = List<Map<String, dynamic>>.from(json.decode(ammoJson));

        // إنشاء القائمة الفريدة (الاسم + البلد)
        List<String> uniqueAmmoKeys =
            savedAmmoList.map((s) => "${s['name']} (${s['country']})").toList();

        // التحقق من أن العتاد المختار لا يزال موجوداً في القائمة
        if (!uniqueAmmoKeys.contains(selectedShellName)) {
          selectedShellName = uniqueAmmoKeys.isNotEmpty ? uniqueAmmoKeys.first : null;
        }
      });
    } else {
      setState(() {
        savedAmmoList = [];
        selectedShellName = null;
      });
    }
  }

  Future<void> _getGpsForGun() async {
    setState(() => isLoadingGunGps = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.deniedForever) return;

      Position? position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      final point = [position.longitude, position.latitude];
      final mgrsStr = Mgrs.forward(point, 5);

      if (mounted) {
        setState(() {
          gunZone.text = mgrsStr.substring(0, 2);
          gunBand.text = mgrsStr.substring(2, 3);
          gunSquare.text = mgrsStr.substring(3, 5);
          gunE.text = mgrsStr.substring(5, 10);
          gunN.text = mgrsStr.substring(10, 15);
        });
        final sp = Provider.of<SettingsProvider>(context, listen: false);
        _saveGunData(sp.gunNumber);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم جلب موقع المدفع')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر جلب الموقع')));
    } finally {
      if (mounted) setState(() => isLoadingGunGps = false);
    }
  }

  void _calculateBase() {
    final sp = Provider.of<SettingsProvider>(context, listen: false);
    _saveGunData(sp.gunNumber);

    try {
      final gMgrs = "${gunZone.text}${gunBand.text}${gunSquare.text}${gunE.text}${gunN.text}";
      final tMgrs = "${tgtZone.text}${tgtBand.text}${tgtSquare.text}${tgtE.text}${tgtN.text}";

      final gUtm = MgrsDecoder.decode(gMgrs);
      final tUtm = MgrsDecoder.decode(tMgrs);

      if (gUtm == null || tUtm == null) return;

      final dE = tUtm.easting - gUtm.easting;
      final dN = tUtm.northing - gUtm.northing;

      final grid = MgrsDecoder.calculateGrid(dE, dN);
      baseDist = grid['distance']!;
      double rawAz6400 = grid['azimuth']!;
      baseAz = rawAz6400 * (sp.directionUnit / 6400.0);

      corrDist = 0;
      corrAz = 0;

      SharedPreferences.getInstance().then((prefs) {
        prefs.setString('last_gun_mgrs', gMgrs);
        prefs.setString('last_tgt_mgrs', tMgrs);
      });

      _applyCorrections();

      Future.delayed(const Duration(milliseconds: 400), () {
        if (_resultsKey.currentContext != null) {
          Scrollable.ensureVisible(
            _resultsKey.currentContext!,
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeInOutCubic,
            alignment: 0.05,
          );
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
  }

  Future<List<FiringTableRow>> _getSmartRowsForRange() async {
    String exactKey = "${selectedWeaponId}_${selectedShellType.name}_${selectedCountry.name}";
    String fallbackKey = "${selectedWeaponId}_${selectedShellType.name}";

    var rows = FiringTables.findRowsForRange(exactKey, baseDist.round());

    if (rows.isEmpty) {
      rows = FiringTables.findRowsForRange(fallbackKey, baseDist.round());

      if (rows.isEmpty) {
        final prefs = await SharedPreferences.getInstance();
        String? customJson = prefs.getString('custom_table_$fallbackKey');
        if (customJson != null) {
          List<dynamic> list = jsonDecode(customJson);
          List<FiringTableRow> customRows = list.map((e) => FiringTableRow.fromJson(e)).toList();
          FiringTables.addCustomTable(fallbackKey, customRows);
          rows = FiringTables.findRowsForRange(fallbackKey, baseDist.round());
        }
      }
    }
    return rows;
  }

  Future<bool> _checkRangeLimits() async {
    String exactKey = "${selectedWeaponId}_${selectedShellType.name}_${selectedCountry.name}";
    String fallbackKey = "${selectedWeaponId}_${selectedShellType.name}";

    var allRows = FiringTables.getTableForWeapon(exactKey);
    if (allRows.isEmpty) allRows = FiringTables.getTableForWeapon(fallbackKey);

    if (allRows.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      String? customJson = prefs.getString('custom_table_$fallbackKey');
      if (customJson != null) {
        List<dynamic> list = jsonDecode(customJson);
        List<FiringTableRow> customRows = list.map((e) => FiringTableRow.fromJson(e)).toList();
        FiringTables.addCustomTable(fallbackKey, customRows);
        allRows = FiringTables.getTableForWeapon(fallbackKey);
      }

      if (allRows.isEmpty) {
        _showMissingTableDialog(exactKey, "$selectedWeaponName - ${selectedShellType.name}");
        return false;
      }
    }

    double maxRange = allRows.map((r) => r.rangeMeters.toDouble()).reduce((a, b) => a > b ? a : b);
    double minRange = allRows.map((r) => r.rangeMeters.toDouble()).reduce((a, b) => a < b ? a : b);

    if (baseDist > maxRange) {
      bool? proceed = await _showContinueDialog(
        "تنبيه: الهدف خارج المدى الأقصى",
        "المسافة المدخلة (${baseDist.toStringAsFixed(0)} م) تتجاوز المدى الأقصى المسجل لهذا السلاح (${maxRange.toStringAsFixed(0)} م).\n\nهل تريد المتابعة باستخدام أقصى مدى متوفر في الجدول؟ (قد يكون غير دقيق).",
      );
      return proceed ?? false;
    }

    if (baseDist < minRange) {
      String recommended = _getRecommendedWeapon(baseDist);
      bool? proceed = await _showContinueDialog(
        "تنبيه: المسافة قريبة جداً",
        "المسافة المدخلة (${baseDist.toStringAsFixed(0)} م) أقل من المدى الأدنى لهذا السلاح (${minRange.toStringAsFixed(0)} م).\n\nيُفضل استخدام: $recommended\n\nهل تريد المتابعة بأقل مدى متوفر في الجدول؟",
      );
      return proceed ?? false;
    }

    return true;
  }

  Future<bool?> _showContinueDialog(String title, String message) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).dialogBackgroundColor,
        title: Text(title, style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
        content: Text(message, style: const TextStyle(fontSize: 16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('متابعة', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  String _getRecommendedWeapon(double dist) {
    if (dist < 2000) return "هاون 60/81 ملم";
    else if (dist < 6000) return "هاون 120 ملم";
    else if (dist < 15000) return "مدفعية 122 ملم";
    else if (dist < 22000) return "مدفعية 130 ملم";
    else if (dist < 30000) return "مدفعية 155 ملم";
    else return "راجمة صواريخ";
  }

  Future<void> _applyCorrections() async {
    if (baseDist == 0) return;

    bool isValid = await _checkRangeLimits();
    if (!isValid) return;

    final sp = Provider.of<SettingsProvider>(context, listen: false);
    final dirUnit = sp.directionUnit;
    final elvUnit = sp.elevationUnit;

    double wearLoss = double.tryParse(barrelWearCtrl.text) ?? 0.0;
    double wearCorrection = wearLoss * 0.5;

    double wRangeCorr = Ballistics.calculateRangeCorrection(baseDist, temp, pressure);

    var rows = await _getSmartRowsForRange();

    if (rows.isEmpty) {
      String exactKey = "${selectedWeaponId}_${selectedShellType.name}_${selectedCountry.name}";
      String fallbackKey = "${selectedWeaponId}_${selectedShellType.name}";
      var allRows = FiringTables.getTableForWeapon(exactKey);
      if (allRows.isEmpty) allRows = FiringTables.getTableForWeapon(fallbackKey);

      if (allRows.isNotEmpty) {
        allRows.sort((a, b) => (a.rangeMeters - baseDist).abs().compareTo((b.rangeMeters - baseDist).abs()));
        rows = [allRows.first];
      }
    }

    if (rows.isEmpty) return;

    List<int> validCharges = [];
    for (var r in rows) {
      if (r.rangeMeters >= baseDist - 100 && !validCharges.contains(r.charge)) {
        validCharges.add(r.charge);
      }
    }
    if (validCharges.isEmpty) {
      validCharges.add(rows.first.charge);
    }
    validCharges.sort();

    setState(() {
      availableCharges = validCharges;
      if (selectedManualCharge != null && !validCharges.contains(selectedManualCharge)) {
        selectedManualCharge = null;
      }
    });

    var selectedRow;
    if (selectedManualCharge != null && availableCharges.contains(selectedManualCharge)) {
      selectedRow = rows.where((r) => r.charge == selectedManualCharge).reduce((a, b) {
        return (a.rangeMeters - baseDist).abs() < (b.rangeMeters - baseDist).abs() ? a : b;
      });
    } else {
      int autoCharge = availableCharges.isNotEmpty ? availableCharges.first : rows.first.charge;
      selectedRow = rows.where((r) => r.charge == autoCharge).reduce((a, b) {
        return (a.rangeMeters - baseDist).abs() < (b.rangeMeters - baseDist).abs() ? a : b;
      });
    }

    int charge = selectedRow.charge;
    double elMils = selectedRow.elevationMils.toDouble();
    double baseTof = selectedRow.timeOfFlightSec;

    double wAzCorr6400 = Ballistics.calculateWindCorrection(
        baseDist, baseTof, windSpeed, windDir * (6400 / dirUnit), baseAz * (6400 / dirUnit), 6400);
    double wAzCorr = wAzCorr6400 * (dirUnit / 6400.0);

    double finalDist = baseDist + corrDist + wRangeCorr + wearCorrection;
    double finalAz = (baseAz + corrAz + wAzCorr) % dirUnit;
    if (finalAz < 0) finalAz += dirUnit;

    double tof = baseTof;

    double fuseTime = 0.0;
    if (isSpecialShell) {
      double descentVel = 180.0;
      fuseTime = tof - (burstHeight / descentVel);
      if (fuseTime < 0) fuseTime = 0.1;
    }

    if (isHighAngle) {
      elMils = 1600 - elMils;
      tof = tof * 1.5;
    }

    double displayEl = elMils;
    if (elvUnit == 360) displayEl = elMils * 360 / 6400;
    if (elvUnit == 6000) displayEl = elMils * 6000 / 6400;
    String elUnitStr = elvUnit == 360 ? "°" : "مل";

    String recWeapon = _getRecommendedWeapon(finalDist);

    setState(() {
      resultDist = "${finalDist.toStringAsFixed(0)} م";
      resultAz = "${finalAz.toStringAsFixed(0)} ${dirUnit == 360 ? '°' : 'مل'}";
      resultEl = "${displayEl.toStringAsFixed(0)} $elUnitStr";
      resultCharge = "$charge";
      resultTof = "${tof.toStringAsFixed(1)} ث";
      resultFuse = isSpecialShell ? "${fuseTime.toStringAsFixed(1)} ث" : "---";
      resultRecommended = recWeapon;
      weatherCorrInfo =
          "تصحيح جو: مسافة ${wRangeCorr.toStringAsFixed(0)}م، تآكل: ${wearCorrection.toStringAsFixed(0)}م";
      _timeLeft = tof;
      _stopTimer();
    });
  }

  void _showMissingTableDialog(String tableKey, String title) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('جدول الرمي غير متوفر', style: TextStyle(color: Colors.orange)),
        content: Text('لا يوجد جدول رمي محفوظ لهذه التوليفة:\n$title\n\nهل تريد إدخال جدول رمي جديد يدوياً؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(context,
                      MaterialPageRoute(builder: (_) => ManualTableScreen(tableKey: tableKey, title: title)))
                  .then((value) {
                if (value == true) _calculateBase();
              });
            },
            child: const Text('إدخال جدول الآن', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _fetchWeatherAutomatically() async {
    if (gunE.text.isEmpty || gunN.text.isEmpty) return;
    setState(() => isLoadingWeather = true);
    final gunMgrs = "${gunZone.text}${gunBand.text}${gunSquare.text}${gunE.text}${gunN.text}";
    final weather = await WeatherService.fetchWeatherByMgrs(gunMgrs);
    if (!mounted) return;
    setState(() => isLoadingWeather = false);
    if (weather == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('تعذر جلب الطقس.'), backgroundColor: Colors.red));
      return;
    }
    final sp = Provider.of<SettingsProvider>(context, listen: false);
    final windDirMils = weather.windDirection * (sp.directionUnit / 360.0);
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => WeatherDialog(
        initialTemp: weather.temperature,
        initialPressure: weather.pressure,
        initialWindSpeed: weather.windSpeed,
        initialWindDir: windDirMils,
        onSave: (t, p, ws, wd) {
          setState(() {
            temp = t;
            pressure = p;
            windSpeed = ws;
            windDir = wd;
          });
          _applyCorrections();
        },
      ),
    );
  }

  void _saveFireMissionDialog() async {
    if (isTrainingMode || baseDist == 0) return;
    final nameCtrl = TextEditingController();
    final colors = Provider.of<ThemeProvider>(context, listen: false).colors;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors['surface'],
        title: Text('حفظ الرماية', style: TextStyle(color: colors['text'])),
        content: TextField(
            controller: nameCtrl,
            decoration: const InputDecoration(labelText: 'اسم أو رقم الرماية'),
            style: TextStyle(color: colors['text'])),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: colors['primary']),
            onPressed: () async {
              if (nameCtrl.text.isNotEmpty) {
                await _saveFireMission(nameCtrl.text);
                if (mounted) Navigator.pop(context);
              }
            },
            child: const Text('حفظ', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  Future<void> _saveFireMission(String name) async {
    final prefs = await SharedPreferences.getInstance();
    final String? missionsJson = prefs.getString('fire_missions');
    List<FireMission> missions = missionsJson != null
        ? (json.decode(missionsJson) as List).map((e) => FireMission.fromJson(e)).toList()
        : [];

    final newMission = FireMission(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      date: DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now()),
      gunMgrs: "${gunZone.text}${gunBand.text}${gunSquare.text}${gunE.text}${gunN.text}",
      targetMgrs: "${tgtZone.text}${tgtBand.text}${tgtSquare.text}${tgtE.text}${tgtN.text}",
      weaponName: selectedWeaponName,
      shellName: selectedShellName ?? 'غير محدد',
      distance: resultDist,
      azimuth: resultAz,
      elevation: resultEl,
      charge: resultCharge,
      tof: resultTof,
    );

    missions.insert(0, newMission);
    await prefs.setString('fire_missions', json.encode(missions.map((e) => e.toJson()).toList()));

    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('تم حفظ الرماية بنجاح'), backgroundColor: Colors.green));
  }

  Future<void> _exportPdf() async {
    final pdf = pw.Document();
    final dateStr = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());
    final font = await PdfGoogleFonts.cairoRegular();
    final fontBold = await PdfGoogleFonts.cairoBold();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(32),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Center(
                    child: pw.Text("أمر الرمي - FIRE ORDER",
                        style: pw.TextStyle(font: fontBold, fontSize: 24))),
                pw.SizedBox(height: 20),
                pw.Text("التاريخ: $dateStr", style: pw.TextStyle(font: font, fontSize: 14)),
                pw.Divider(),
                pw.Text("السلاح: $selectedWeaponName", style: pw.TextStyle(font: fontBold)),
                pw.Text("العتاد: ${selectedShellName ?? 'غير محدد'}", style: pw.TextStyle(font: font)),
                pw.SizedBox(height: 10),
                pw.Text(
                    "إحداثيات المدفع: ${gunZone.text}${gunBand.text}${gunSquare.text}${gunE.text}${gunN.text}",
                    style: pw.TextStyle(font: font)),
                pw.Text(
                    "إحداثيات الهدف: ${tgtZone.text}${tgtBand.text}${tgtSquare.text}${tgtE.text}${tgtN.text}",
                    style: pw.TextStyle(font: font)),
                pw.SizedBox(height: 20),
                pw.Text("بيانات الرمي:", style: pw.TextStyle(font: fontBold, fontSize: 18)),
                pw.Text("المسافة: $resultDist | الاتجاه: $resultAz", style: pw.TextStyle(font: font)),
                pw.Text("الارتفاع: $resultEl | الحشوة: $resultCharge | ToF: $resultTof",
                    style: pw.TextStyle(font: font)),
                if (isSpecialShell)
                  pw.Text("توقيت الصمام: $resultFuse",
                      style: pw.TextStyle(font: font, color: PdfColors.red)),
                pw.SizedBox(height: 20),
                pw.Text("البرقية الجوية:", style: pw.TextStyle(font: fontBold)),
                pw.Text("الحرارة: ${temp.toStringAsFixed(1)}C | الضغط: ${pressure.toStringAsFixed(1)}hPa",
                    style: pw.TextStyle(font: font)),
                pw.Text("الرياح: ${windSpeed.toStringAsFixed(1)}m/s @ ${windDir.toStringAsFixed(0)}",
                    style: pw.TextStyle(font: font)),
                pw.Text("تآكل السبطانة: ${barrelWearCtrl.text} م/ث", style: pw.TextStyle(font: font)),
                pw.Spacer(),
                pw.Center(child: pw.Text("حاسبة المدفعية", style: pw.TextStyle(font: font))),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  void _startTimer() {
    if (_timeLeft <= 0) return;
    setState(() => _isTimerRunning = true);
    _timer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      setState(() {
        _timeLeft -= 0.1;
        if (_timeLeft <= 0) {
          _timeLeft = 0;
          _isTimerRunning = false;
          timer.cancel();
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('انتهى زمن الطيران - سقوط!'), backgroundColor: Colors.red));
        }
      });
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    setState(() => _isTimerRunning = false);
  }

  // ==================== دوال جديدة من الكود الثاني ====================

  Future<void> _clearAllData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تأكيد المسح'),
        content: const Text('سيتم مسح كل السجلات والأهداف والإعدادات. لا يمكن التراجع!'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('مسح', style: TextStyle(color: Colors.white))),
        ],
      ),
    );
    if (confirmed == true) {
      final p = await SharedPreferences.getInstance();
      await p.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم مسح كل البيانات'), backgroundColor: Colors.red));
      }
    }
  }

  Widget _drawerItem(String text, IconData icon, int tabIndex) {
    return ListTile(
      leading: Icon(icon, color: Provider.of<ThemeProvider>(context).colors['primary'], size: 18),
      title: Text(text, style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color)),
      onTap: () {
        Navigator.pop(context);
        if (tabIndex >= 0) {
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => AdvancedToolsScreen(initialIndex: tabIndex)));
        } else if (tabIndex == -1) {
          setState(() => isTrainingMode = !isTrainingMode);
        } else if (tabIndex == -2) {
          setState(() => isHighAngle = !isHighAngle);
          if (baseDist > 0) _applyCorrections();
        } else if (tabIndex == -3) {
          if (baseDist > 0) {
            Navigator.push(context, MaterialPageRoute(builder: (_) => MrsiScreen(baseDistance: baseDist)));
          } else {
            ScaffoldMessenger.of(context)
                .showSnackBar(const SnackBar(content: Text('احسب مسافة أولاً')));
          }
        }
      },
    );
  }

  // ==================== بناء الواجهة ====================

  @override
  Widget build(BuildContext context) {
    final colors = Provider.of<ThemeProvider>(context).colors;
    final sp = Provider.of<SettingsProvider>(context);

    // توليد قائمة العتاد الفريدة (الاسم + البلد)
    List<String> uniqueAmmoKeys =
        savedAmmoList.map((s) => "${s['name']} (${s['country']})").toList();

    return Scaffold(
      backgroundColor: colors['bg'],
      // ==================== Drawer من الكود الثاني ====================
      drawer: Drawer(
        backgroundColor: colors['surface'],
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: colors['primary']),
              child: Center(child: Image.asset('assets/logo.png', height: 90)),
            ),
            ListTile(
              leading: Icon(Icons.calculate, color: colors['primary']),
              title: Text('الحاسبة الرئيسية', style: TextStyle(color: colors['text'])),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: Icon(Icons.explore, color: colors['primary']),
              title: Text('توجيه المدفع', style: TextStyle(color: colors['text'])),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const GunLayingScreen()));
              },
            ),
            ListTile(
              leading: Icon(Icons.menu_book, color: colors['warning']),
              title: Text('الكراسات وأدوات المدفعية', style: TextStyle(color: colors['text'])),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ManualsScreen()));
              },
            ),
            ListTile(
              leading: Icon(Icons.mic, color: colors['primary']),
              title: Text('النقل الصوتي (Mesh)', style: TextStyle(color: colors['text'])),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const AcousticMeshScreen()));
              },
            ),
            ExpansionTile(
              leading: Icon(Icons.build, color: colors['warning']),
              title: Text('الأدوات المتقدمة',
                  style: TextStyle(color: colors['text'], fontWeight: FontWeight.bold)),
              iconColor: colors['warning'],
              collapsedIconColor: colors['text'],
              children: [
                _drawerItem('هدف متحرك', Icons.directions_run, 0),
                _drawerItem('إزاحة الهدف', Icons.open_with, 1),
                _drawerItem('الذخيرة المطلوبة', Icons.layers, 2),
                _drawerItem('قارئ الأوامر', Icons.text_snippet, 3),
                _drawerItem('نقطة السقوط', Icons.gps_fixed, 4),
                _drawerItem('الانفجار الجوي', Icons.flight_takeoff, 5),
                _drawerItem('وقت التهدئة', Icons.ac_unit, 6),
                _drawerItem('سجل الطقس', Icons.cloud, 7),
                _drawerItem('توزيع النيران', Icons.grid_view, 8),
                const Divider(),
                _drawerItem('رمي التدريب', Icons.school, -1),
                _drawerItem('الرمي بزوايا عالية', Icons.arrow_upward, -2),
                _drawerItem('الرمي المتزامن (MRSI)', Icons.flash_on, -3),
              ],
            ),
            ListTile(
              leading: Icon(Icons.history, color: colors['primary']),
              title: Text('سجل الرمايات', style: TextStyle(color: colors['text'])),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const FireMissionLogScreen()));
              },
            ),
            ExpansionTile(
              leading: Icon(Icons.settings, color: colors['text']),
              title: Text('الإعدادات',
                  style: TextStyle(color: colors['text'], fontWeight: FontWeight.bold)),
              iconColor: colors['primary'],
              collapsedIconColor: colors['text'],
              children: [
                ListTile(
                  title: Text('زاوية الانحراف (G-M)', style: TextStyle(color: colors['text'])),
                  subtitle: Text('${sp.gMAngle.toStringAsFixed(2)}°',
                      style: TextStyle(color: colors['primary'], fontWeight: FontWeight.bold)),
                  trailing: Icon(Icons.edit, color: colors['primary'], size: 18),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
                  },
                ),
                ListTile(
                  title: Text('وحدة الاتجاه', style: TextStyle(color: colors['text'])),
                  subtitle: Text(
                      sp.directionUnit == 360
                          ? 'درجات 360'
                          : sp.directionUnit == 6000
                              ? 'ملات 6000'
                              : 'ملات 6400',
                      style: TextStyle(color: colors['primary'])),
                  trailing: DropdownButton<int>(
                      value: sp.directionUnit,
                      dropdownColor: colors['surface'],
                      underline: const SizedBox(),
                      items: const [
                        DropdownMenuItem(value: 6400, child: Text('6400')),
                        DropdownMenuItem(value: 6000, child: Text('6000')),
                        DropdownMenuItem(value: 360, child: Text('360'))
                      ],
                      onChanged: (v) {
                        if (v != null) {
                          sp.setDirectionUnit(v);
                          if (baseDist > 0) _calculateBase();
                        }
                      }),
                ),
                ListTile(
                  title: Text('وحدة الارتفاع', style: TextStyle(color: colors['text'])),
                  subtitle: Text(
                      sp.elevationUnit == 360
                          ? 'درجات 360'
                          : sp.elevationUnit == 6000
                              ? 'ملات 6000'
                              : 'ملات 6400',
                      style: TextStyle(color: colors['primary'])),
                  trailing: DropdownButton<int>(
                      value: sp.elevationUnit,
                      dropdownColor: colors['surface'],
                      underline: const SizedBox(),
                      items: const [
                        DropdownMenuItem(value: 6400, child: Text('6400')),
                        DropdownMenuItem(value: 6000, child: Text('6000')),
                        DropdownMenuItem(value: 360, child: Text('360'))
                      ],
                      onChanged: (v) {
                        if (v != null) {
                          sp.setElevationUnit(v);
                          if (baseDist > 0) _applyCorrections();
                        }
                      }),
                ),
              ],
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              title: const Text('مسح جميع البيانات',
                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.pop(context);
                _clearAllData();
              },
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Text('تصميم وعمل',
                      style: TextStyle(color: colors['text']?.withOpacity(0.5), fontSize: 12)),
                  Text('النقيب زين العابدين جاسب اللامي',
                      style: TextStyle(
                          color: colors['primary'], fontSize: 14, fontWeight: FontWeight.bold)),
                  Text('وزارة الدفاع العراقية',
                      style: TextStyle(color: colors['text']?.withOpacity(0.5), fontSize: 10)),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
      // ==================== AppBar ====================
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(Icons.menu, color: colors['text']),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Text(isTrainingMode ? 'وضع التدريب' : 'حاسبة الرمي'),
        backgroundColor: colors['surface'],
        centerTitle: true,
        actions: [
          DropdownButton<int>(
            value: sp.gunNumber,
            dropdownColor: colors['surface'],
            underline: const SizedBox(),
            icon: Icon(Icons.rocket_launch, color: colors['warning']),
            items: List.generate(
                6,
                (i) => DropdownMenuItem(
                    value: i + 1,
                    child: Text('مدفع ${i + 1}', style: TextStyle(color: colors['text'])))),
            onChanged: (v) async {
              if (v != null) {
                await _saveGunData(sp.gunNumber);
                await sp.setGunNumber(v);
                await _loadGunData(v);
                if (baseDist > 0) _calculateBase();
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      // ==================== Body (بدون تغيير) ====================
      body: ListView(
        controller: _scrollCtrl,
        padding: const EdgeInsets.all(16.0),
        children: [
          if (isHighAngle)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: colors['warning']!.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colors['warning']!)),
              child: Row(
                children: [
                  Icon(Icons.arrow_upward, color: colors['warning']),
                  const SizedBox(width: 8),
                  Text('وضع الزاوية العالية نشط',
                      style: TextStyle(color: colors['warning'], fontWeight: FontWeight.bold)),
                ],
              ),
            ),

          Card(
            color: colors['surface'],
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: colors['border']!)),
            child: ExpansionTile(
              title: Text("إعدادات السلاح والذخيرة",
                  style: TextStyle(color: colors['primary'], fontWeight: FontWeight.bold)),
              subtitle: Text(
                  "$selectedWeaponName | ${selectedShellType.name.toUpperCase()} | ${selectedCountry.name.toUpperCase()}",
                  style: TextStyle(color: colors['text']?.withOpacity(0.7), fontSize: 12)),
              iconColor: colors['primary'],
              collapsedIconColor: colors['text'],
              initiallyExpanded: false,
              children: [
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    children: [
                      DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          dropdownColor: colors['surface'],
                          value: DataService.allWeapons.any((w) => w.id == selectedWeaponId)
                              ? selectedWeaponId
                              : null,
                          items: DataService.allWeapons
                              .map((w) => DropdownMenuItem(
                                    value: w.id,
                                    child: Text("${w.nameAr} (${w.origin})",
                                        style: TextStyle(color: colors['text'])),
                                  ))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) {
                              final w = DataService.allWeapons.firstWhere((e) => e.id == val);
                              setState(() {
                                selectedWeaponId = w.id;
                                selectedWeaponName = w.nameAr;
                                selectedManualCharge = null;
                              });
                              if (baseDist > 0) _calculateBase();
                            }
                          },
                        ),
                      ),
                      const Divider(),
                      DropdownButtonHideUnderline(
                        child: DropdownButton<ShellType>(
                          isExpanded: true,
                          dropdownColor: colors['surface'],
                          value: selectedShellType,
                          items: const [
                            DropdownMenuItem(value: ShellType.he, child: Text('مهداد (HE)')),
                            DropdownMenuItem(value: ShellType.smoke, child: Text('دخان (Smoke)')),
                            DropdownMenuItem(
                                value: ShellType.illumination, child: Text('تنوير (Illum)')),
                            DropdownMenuItem(
                                value: ShellType.airburst, child: Text('انفلاق جوي (Airburst)')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => selectedShellType = val);
                              if (baseDist > 0) _calculateBase();
                            }
                          },
                        ),
                      ),
                      const Divider(),
                      DropdownButtonHideUnderline(
                        child: DropdownButton<ShellCountry>(
                          isExpanded: true,
                          dropdownColor: colors['surface'],
                          value: selectedCountry,
                          items: const [
                            DropdownMenuItem(value: ShellCountry.usa, child: Text('أمريكا')),
                            DropdownMenuItem(value: ShellCountry.russia, child: Text('روسيا')),
                            DropdownMenuItem(value: ShellCountry.china, child: Text('الصين')),
                            DropdownMenuItem(value: ShellCountry.iran, child: Text('إيران')),
                            DropdownMenuItem(value: ShellCountry.serbia, child: Text('صربيا')),
                            DropdownMenuItem(
                                value: ShellCountry.yugoslavia, child: Text('يوغوسلافيا')),
                            DropdownMenuItem(value: ShellCountry.iraq, child: Text('العراق')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => selectedCountry = val);
                              if (baseDist > 0) _calculateBase();
                            }
                          },
                        ),
                      ),

                      if (isSpecialShell) ...[
                        const Divider(),
                        TextField(
                          keyboardType: TextInputType.number,
                          style: TextStyle(
                              color: colors['warning'], fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            labelText: 'ارتفاع الانفجار المطلوب (متر)',
                            labelStyle: TextStyle(color: colors['warning']),
                            isDense: true,
                          ),
                          controller: TextEditingController(text: burstHeight.toStringAsFixed(0)),
                          onChanged: (val) {
                            burstHeight = double.tryParse(val) ?? 15.0;
                            if (baseDist > 0) _applyCorrections();
                          },
                        ),
                      ],

                      const Divider(),
                      // القائمة المنسدلة للعتاد - تعرض الاسم والبلد معاً
                      DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          dropdownColor: colors['surface'],
                          value: uniqueAmmoKeys.contains(selectedShellName)
                              ? selectedShellName
                              : null,
                          hint: Text('اختر العتاد', style: TextStyle(color: colors['text'])),
                          items: uniqueAmmoKeys
                              .map((key) => DropdownMenuItem(
                                    value: key,
                                    child: Text(key, style: TextStyle(color: colors['text'])),
                                  ))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => selectedShellName = val);
                          },
                        ),
                      ),
                      const Divider(),
                      DropdownButtonHideUnderline(
                        child: DropdownButton<int?>(
                          isExpanded: true,
                          dropdownColor: colors['surface'],
                          value: availableCharges.contains(selectedManualCharge)
                              ? selectedManualCharge
                              : null,
                          hint: Text('الحشوة (تلقائي)', style: TextStyle(color: colors['text'])),
                          items: [
                            DropdownMenuItem<int?>(
                                value: null,
                                child: Text('تلقائي (أقل حشوة تصل للهدف)',
                                    style: TextStyle(
                                        color: colors['primary'],
                                        fontWeight: FontWeight.bold))),
                            ...availableCharges.map((c) => DropdownMenuItem<int?>(
                                value: c,
                                child: Text('الحشوة $c',
                                    style: TextStyle(color: colors['text'])))),
                          ],
                          onChanged: (val) {
                            setState(() => selectedManualCharge = val);
                            if (baseDist > 0) _applyCorrections();
                          },
                        ),
                      ),
                      const Divider(),
                      TextField(
                        controller: barrelWearCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'تآكل السبطانة (م/ث)',
                          labelStyle: TextStyle(color: colors['warning']),
                          isDense: true,
                          helperText:
                              'يزيد التآكل مع زيادة عدد الرمايات، ويؤثر على مدى القذيفة.',
                          helperStyle:
                              TextStyle(color: colors['text']?.withOpacity(0.5), fontSize: 10),
                        ),
                        style: TextStyle(
                            color: colors['warning'], fontWeight: FontWeight.bold),
                        onChanged: (val) {
                          if (baseDist > 0) _applyCorrections();
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          Card(
            color: colors['surface'],
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: colors['border']!)),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("إحداثيات المدفع (GUN)",
                          style: TextStyle(
                              color: colors['primary'],
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: isLoadingGunGps
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.gps_fixed, color: Colors.cyan),
                        onPressed: _getGpsForGun,
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(flex: 1, child: _buildField(gunZone, "Zone", 2, colors)),
                      const SizedBox(width: 5),
                      Expanded(flex: 1, child: _buildField(gunBand, "Band", 1, colors)),
                      const SizedBox(width: 5),
                      Expanded(flex: 1, child: _buildField(gunSquare, "Sq", 2, colors)),
                      const SizedBox(width: 5),
                      Expanded(flex: 2, child: _buildField(gunE, "Easting", 5, colors)),
                      const SizedBox(width: 5),
                      Expanded(flex: 2, child: _buildField(gunN, "Northing", 5, colors)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildCoordinateCard("إحداثيات الهدف (TARGET)", tgtZone, tgtBand, tgtSquare, tgtE,
              tgtN, colors),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _calculateBase,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors['primary'],
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.calculate, size: 28),
                  label: const Text('حساب (CALCULATE)',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 1,
                child: ElevatedButton.icon(
                  onPressed: isLoadingWeather ? null : _fetchWeatherAutomatically,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueGrey,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: isLoadingWeather
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.cloud_download),
                  label: Text(isLoadingWeather ? 'جاري...' : 'الطقس\nالتلقائي',
                      textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
                ),
              ),
            ],
          ),
          if (baseDist > 0)
            Padding(
              padding: const EdgeInsets.only(top: 12.0),
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(context,
                      MaterialPageRoute(builder: (context) => MrsiScreen(baseDistance: baseDist)));
                },
                icon: const Icon(Icons.flash_on, color: Colors.amber),
                label: const Text('حساب الرمي المتزامن (MRSI)'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: colors['surfaceLight'], foregroundColor: colors['text']),
              ),
            ),
          const SizedBox(height: 24),
          Container(
            key: _resultsKey,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors['surface'],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors['border']!),
            ),
            child: Column(
              children: [
                _buildResultRow("المسافة (Range)", resultDist, colors),
                const Divider(),
                _buildResultRow("الاتجاه (Azimuth)", resultAz, colors),
                const Divider(),
                _buildResultRow("زاوية الارتفاع (Elevation)", resultEl, colors),
                const Divider(),
                _buildResultRow("الحشوة (Charge)", resultCharge, colors),
                const Divider(),
                _buildResultRow("زمن الطيران (ToF)", resultTof, colors),
                if (isSpecialShell) ...[
                  const Divider(),
                  _buildResultRow("توقيت الصمام (Fuse)", resultFuse, colors),
                ],
                const Divider(),
                _buildResultRow("السلاح الموصى به", resultRecommended, colors),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(weatherCorrInfo,
                      style: TextStyle(
                          color: colors['warning'], fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (baseDist > 0)
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _exportPdf,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors['secondary'],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(Icons.picture_as_pdf),
                    label: const Text('تصدير PDF',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _saveFireMissionDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors['primary'],
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                  ),
                  child: const Icon(Icons.save),
                ),
              ],
            ),
          const SizedBox(height: 24),
          if (baseDist > 0) _buildCorrectionPanel(colors),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors['surfaceLight'],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors['primary']!, width: 2),
            ),
            child: Column(
              children: [
                Text('مؤقت الرمي (Countdown)',
                    style: TextStyle(
                        color: colors['text'], fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Text(
                  _timeLeft.toStringAsFixed(1),
                  style: TextStyle(
                      color: _timeLeft > 0 ? colors['primary'] : Colors.red,
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace'),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: _isTimerRunning ? _stopTimer : _startTimer,
                      icon: Icon(_isTimerRunning ? Icons.pause_circle : Icons.play_circle,
                          size: 50, color: colors['primary']),
                    ),
                    const SizedBox(width: 20),
                    IconButton(
                      onPressed: () {
                        _stopTimer();
                        setState(() =>
                            _timeLeft = double.tryParse(resultTof.split(" ")[0]) ?? 0.0);
                      },
                      icon: Icon(Icons.refresh, size: 40, color: colors['text']),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildCorrectionPanel(Map<String, Color> colors) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors['surface'],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors['warning']!, width: 1.5),
      ),
      child: Column(
        children: [
          Text('تصحيح الرمي اليدوي',
              style: TextStyle(
                  color: colors['warning'], fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Column(
                children: [
                  Text('المسافة (م)', style: TextStyle(color: colors['text'])),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildCorrButton(Icons.remove, () {
                        corrDist -= 50;
                        _applyCorrections();
                      }, colors),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Text('$corrDist',
                            style: TextStyle(
                                color: colors['text'],
                                fontSize: 18,
                                fontWeight: FontWeight.bold)),
                      ),
                      _buildCorrButton(Icons.add, () {
                        corrDist += 50;
                        _applyCorrections();
                      }, colors),
                    ],
                  ),
                ],
              ),
              Column(
                children: [
                  Text('الاتجاه', style: TextStyle(color: colors['text'])),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildCorrButton(Icons.arrow_left, () {
                        corrAz -= 50;
                        _applyCorrections();
                      }, colors),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Text('$corrAz',
                            style: TextStyle(
                                color: colors['text'],
                                fontSize: 18,
                                fontWeight: FontWeight.bold)),
                      ),
                      _buildCorrButton(Icons.arrow_right, () {
                        corrAz += 50;
                        _applyCorrections();
                      }, colors),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: () {
              corrDist = 0;
              corrAz = 0;
              _applyCorrections();
            },
            icon: const Icon(Icons.restart_alt, color: Colors.red),
            label: const Text('إلغاء التصحيحات', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildCorrButton(IconData icon, VoidCallback onPressed, Map<String, Color> colors) {
    return InkWell(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            color: colors['surfaceLight'],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colors['border']!)),
        child: Icon(icon, color: colors['primary'], size: 24),
      ),
    );
  }

  Widget _buildCoordinateCard(String title, TextEditingController z, TextEditingController b,
      TextEditingController sq, TextEditingController e, TextEditingController n,
      Map<String, Color> colors) {
    return Card(
      color: colors['surface'],
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12), side: BorderSide(color: colors['border']!)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: TextStyle(
                    color: colors['primary'], fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(flex: 1, child: _buildField(z, "Zone", 2, colors)),
                const SizedBox(width: 5),
                Expanded(flex: 1, child: _buildField(b, "Band", 1, colors)),
                const SizedBox(width: 5),
                Expanded(flex: 1, child: _buildField(sq, "Sq", 2, colors)),
                const SizedBox(width: 5),
                Expanded(flex: 2, child: _buildField(e, "Easting", 5, colors)),
                const SizedBox(width: 5),
                Expanded(flex: 2, child: _buildField(n, "Northing", 5, colors)),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildField(
      TextEditingController ctrl, String label, int maxLength, Map<String, Color> colors) {
    return TextField(
      controller: ctrl,
      maxLength: maxLength,
      textAlign: TextAlign.center,
      style: TextStyle(color: colors['text'], fontWeight: FontWeight.bold),
      decoration: InputDecoration(
        labelText: label,
        counterText: "",
        contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        isDense: true,
      ),
    );
  }

  Widget _buildResultRow(String label, String value, Map<String, Color> colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(color: colors['text']?.withOpacity(0.8), fontSize: 16)),
          Text(value,
              style: TextStyle(
                  color: colors['primary'], fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}