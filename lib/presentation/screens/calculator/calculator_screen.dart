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
import '../../../domain/elevation_service.dart';
import '../../../services/data_service.dart';
import '../../../models/models.dart';
import '../../widgets/weather_dialog.dart';
import '../../widgets/app_drawer.dart' show rootScaffoldKey;
import 'mrsi_screen.dart';
import '../advanced_tools/manual_table_screen.dart';

class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});
  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen>
    with WidgetsBindingObserver {
  final gunZone = TextEditingController();
  final gunBand = TextEditingController();
  final gunSquare = TextEditingController();
  final gunE = TextEditingController();
  final gunN = TextEditingController();
  final gunHeightCtrl = TextEditingController();          // ★ جديد
  final barrelWearCtrl = TextEditingController();
  final burstHeightCtrl = TextEditingController(text: '15');

  final tgtZone = TextEditingController(text: "38");
  final tgtBand = TextEditingController(text: "S");
  final tgtSquare = TextEditingController(text: "MB");
  final tgtE = TextEditingController(text: "35995");
  final tgtN = TextEditingController(text: "83060");
  final tgtHeightCtrl = TextEditingController();          // ★ جديد

  String selectedWeaponId = "mortar120";
  String selectedWeaponName = "هاون 120 ملم M120/M220";
  ShellType selectedShellType = ShellType.he;
  ShellCountry selectedCountry = ShellCountry.usa;

  String? selectedShellName;
  int? selectedManualCharge;
  List<Map<String, dynamic>> savedAmmoList = [];

  bool isTrainingMode = false;
  bool isHighAngle = false;

  double burstHeight = 15.0;
  bool get isSpecialShell =>
      selectedShellType == ShellType.airburst ||
      selectedShellType == ShellType.illumination;

  double temp = 15.0;
  double pressure = 1013.25;
  double windSpeed = 0.0;
  double windDir = 0.0;
  bool isLoadingWeather = false;
  bool isLoadingGunGps = false;
  bool isLoadingGunElev = false;   // ★ جديد
  bool isLoadingTgtElev = false;   // ★ جديد

  double baseDist = 0;
  double baseAz = 0;
  double corrDist = 0;
  double corrAz = 0;

  double gunHeight = 0;   // ★ جديد
  double tgtHeight = 0;   // ★ جديد
  double siteAngleMils = 0; // ★ جديد (بوحدة 6400)
  double baseSlant = 0;   // ★ جديد

  String resultDist = "---";
  String resultAz = "---";
  String resultEl = "---";
  String resultCharge = "---";
  String resultTof = "---";
  String resultFuse = "---";
  String resultRecommended = "---";
  String resultSite = "---";    // ★ جديد
  String resultSlant = "---";   // ★ جديد
  String weatherCorrInfo = "لم يتم جلب الطقس بعد";

  List<int> availableCharges = [];

  Timer? _timer;
  double _timeLeft = 0.0;
  bool _isTimerRunning = false;

  final ScrollController _scrollCtrl = ScrollController();
  final GlobalKey _resultsKey = GlobalKey();

  SettingsProvider? _sp;
  int _lastDirUnit = 0;
  int _lastElUnit = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadAmmoFromTracker();
    _checkForIncomingTarget();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final sp = Provider.of<SettingsProvider>(context, listen: false);
      _sp = sp;
      _lastDirUnit = sp.directionUnit;
      _lastElUnit = sp.elevationUnit;
      sp.addListener(_onSettingsChanged);
      _loadGunData(sp.gunNumber);
    });
  }

  void _onSettingsChanged() {
    final sp = _sp;
    if (sp == null || !mounted) return;
    if (sp.directionUnit != _lastDirUnit || sp.elevationUnit != _lastElUnit) {
      _lastDirUnit = sp.directionUnit;
      _lastElUnit = sp.elevationUnit;
      if (baseDist > 0) _calculateBase();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sp?.removeListener(_onSettingsChanged);
    _timer?.cancel();
    _scrollCtrl.dispose();
    gunZone.dispose();
    gunBand.dispose();
    gunSquare.dispose();
    gunE.dispose();
    gunN.dispose();
    gunHeightCtrl.dispose();
    barrelWearCtrl.dispose();
    burstHeightCtrl.dispose();
    tgtZone.dispose();
    tgtBand.dispose();
    tgtSquare.dispose();
    tgtE.dispose();
    tgtN.dispose();
    tgtHeightCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkForIncomingTarget();
  }

  Future<void> _loadGunData(int gunNum) async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      gunZone.text = p.getString('gun_${gunNum}_zone') ?? "38";
      gunBand.text = p.getString('gun_${gunNum}_band') ?? "S";
      gunSquare.text = p.getString('gun_${gunNum}_sq') ?? "MB";
      gunE.text = p.getString('gun_${gunNum}_e') ?? "35782";
      gunN.text = p.getString('gun_${gunNum}_n') ?? "84178";
      gunHeightCtrl.text = (p.getInt('gun_${gunNum}_height') ?? 0).toString();
      gunHeight = double.tryParse(gunHeightCtrl.text) ?? 0;
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
    await p.setInt('gun_${gunNum}_height', int.tryParse(gunHeightCtrl.text) ?? 0);
    await p.setInt('gun_${gunNum}_wear', int.tryParse(barrelWearCtrl.text) ?? 0);
  }

  Future<void> _checkForIncomingTarget() async {
    final prefs = await SharedPreferences.getInstance();
    final incomingE = prefs.getString('calc_tgt_e');
    if (incomingE != null) {
      if (!mounted) return;
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
    if (!mounted) return;
    if (ammoJson != null) {
      setState(() {
        savedAmmoList = List<Map<String, dynamic>>.from(json.decode(ammoJson));
        final uniqueAmmoKeys =
            savedAmmoList.map((s) => "${s['name']} (${s['country']})").toList();
        if (!uniqueAmmoKeys.contains(selectedShellName)) {
          selectedShellName =
              uniqueAmmoKeys.isNotEmpty ? uniqueAmmoKeys.first : null;
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
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) return;

      final position =
          await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
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
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('تم جلب موقع المدفع')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('تعذر جلب الموقع')));
      }
    } finally {
      if (mounted) setState(() => isLoadingGunGps = false);
    }
  }

  // ★ جديد: جلب ارتفاع المدفع تلقائياً
  Future<void> _fetchGunElevation() async {
    setState(() => isLoadingGunElev = true);
    try {
      final gMgrs =
          "${gunZone.text}${gunBand.text}${gunSquare.text}${gunE.text}${gunN.text}";
      final pt = Mgrs.toPoint(gMgrs);
      final lat = pt[1];
      final lon = pt[0];
      final h = await ElevationService.fetchElevation(lat, lon);
      if (!mounted) return;
      if (h == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('تعذر جلب الارتفاع — أدخله يدوياً'),
            backgroundColor: Colors.red));
      } else {
        setState(() {
          gunHeightCtrl.text = h.toStringAsFixed(0);
          gunHeight = h;
        });
        final sp = Provider.of<SettingsProvider>(context, listen: false);
        _saveGunData(sp.gunNumber);
        if (baseDist > 0) _applyCorrections();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('خطأ: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => isLoadingGunElev = false);
    }
  }

  // ★ جديد: جلب ارتفاع الهدف تلقائياً
  Future<void> _fetchTgtElevation() async {
    setState(() => isLoadingTgtElev = true);
    try {
      final tMgrs =
          "${tgtZone.text}${tgtBand.text}${tgtSquare.text}${tgtE.text}${tgtN.text}";
      final pt = Mgrs.toPoint(tMgrs);
      final lat = pt[1];
      final lon = pt[0];
      final h = await ElevationService.fetchElevation(lat, lon);
      if (!mounted) return;
      if (h == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('تعذر جلب الارتفاع — أدخله يدوياً'),
            backgroundColor: Colors.red));
      } else {
        setState(() {
          tgtHeightCtrl.text = h.toStringAsFixed(0);
          tgtHeight = h;
        });
        if (baseDist > 0) _applyCorrections();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('خطأ: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => isLoadingTgtElev = false);
    }
  }

  void _calculateBase() {
    final sp = Provider.of<SettingsProvider>(context, listen: false);
    _saveGunData(sp.gunNumber);

    try {
      final gMgrs =
          "${gunZone.text}${gunBand.text}${gunSquare.text}${gunE.text}${gunN.text}";
      final tMgrs =
          "${tgtZone.text}${tgtBand.text}${tgtSquare.text}${tgtE.text}${tgtN.text}";

      final gUtm = MgrsDecoder.decode(gMgrs);
      final tUtm = MgrsDecoder.decode(tMgrs);
      if (gUtm == null || tUtm == null) return;

      final dE = tUtm.easting - gUtm.easting;
      final dN = tUtm.northing - gUtm.northing;

      // ★ تمرير وحدة الاتجاه للدالة المحدثة
      final grid = MgrsDecoder.calculateGrid(dE, dN, sp.directionUnit);
      baseDist = grid['distance']!;
      baseAz = grid['azimuth']!;

      corrDist = 0;
      corrAz = 0;

      SharedPreferences.getInstance().then((prefs) {
        prefs.setString('last_gun_mgrs', gMgrs);
        prefs.setString('last_tgt_mgrs', tMgrs);
      });

      _applyCorrections();

      Future.delayed(const Duration(milliseconds: 400), () {
        if (!mounted) return;
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
  }

  Future<List<FiringTableRow>> _getSmartRowsForRange() async {
    final exactKey =
        "${selectedWeaponId}_${selectedShellType.name}_${selectedCountry.name}";
    final fallbackKey = "${selectedWeaponId}_${selectedShellType.name}";

    var rows = FiringTables.findRowsForRange(exactKey, baseDist.round());
    if (rows.isEmpty) {
      rows = FiringTables.findRowsForRange(fallbackKey, baseDist.round());
      if (rows.isEmpty) {
        final prefs = await SharedPreferences.getInstance();
        final customJson = prefs.getString('custom_table_$fallbackKey');
        if (customJson != null) {
          final list = jsonDecode(customJson) as List;
          final customRows = list
              .map((e) => FiringTableRow.fromJson(e as Map<String, dynamic>))
              .toList();
          FiringTables.addCustomTable(fallbackKey, customRows);
          rows = FiringTables.findRowsForRange(fallbackKey, baseDist.round());
        }
      }
    }
    return rows;
  }

  Future<bool> _checkRangeLimits() async {
    final exactKey =
        "${selectedWeaponId}_${selectedShellType.name}_${selectedCountry.name}";
    final fallbackKey = "${selectedWeaponId}_${selectedShellType.name}";

    var allRows = FiringTables.getTableForWeapon(exactKey);
    if (allRows.isEmpty) allRows = FiringTables.getTableForWeapon(fallbackKey);

    if (allRows.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      final customJson = prefs.getString('custom_table_$fallbackKey');
      if (customJson != null) {
        final list = jsonDecode(customJson) as List;
        final customRows = list
            .map((e) => FiringTableRow.fromJson(e as Map<String, dynamic>))
            .toList();
        FiringTables.addCustomTable(fallbackKey, customRows);
        allRows = FiringTables.getTableForWeapon(fallbackKey);
      }
      if (allRows.isEmpty) {
        if (!mounted) return false;
        _showMissingTableDialog(
            exactKey, "$selectedWeaponName - ${selectedShellType.name}");
        return false;
      }
    }

    final maxRange =
        allRows.map((r) => r.rangeMeters.toDouble()).reduce((a, b) => a > b ? a : b);
    final minRange =
        allRows.map((r) => r.rangeMeters.toDouble()).reduce((a, b) => a < b ? a : b);

    if (!mounted) return false;

    if (baseDist > maxRange) {
      final proceed = await _showContinueDialog(
        "تنبيه: الهدف خارج المدى الأقصى",
        "المسافة المدخلة (${baseDist.toStringAsFixed(0)} م) تتجاوز المدى الأقصى المسجل لهذا السلاح (${maxRange.toStringAsFixed(0)} م).\n\nهل تريد المتابعة باستخدام أقصى مدى متوفر في الجدول؟",
      );
      return proceed ?? false;
    }

    if (baseDist < minRange) {
      final recommended = _getRecommendedWeapon(baseDist);
      final proceed = await _showContinueDialog(
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
      builder: (dCtx) => AlertDialog(
        backgroundColor: Theme.of(dCtx).dialogBackgroundColor,
        title: Text(title,
            style: const TextStyle(
                color: Colors.orange, fontWeight: FontWeight.bold)),
        content: Text(message, style: const TextStyle(fontSize: 16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx, false),
            child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () => Navigator.pop(dCtx, true),
            child: const Text('متابعة', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  String _getRecommendedWeapon(double dist) {
    if (dist < 2000) return "هاون 60/81 ملم";
    if (dist < 6000) return "هاون 120 ملم";
    if (dist < 15000) return "مدفعية 122 ملم";
    if (dist < 22000) return "مدفعية 130 ملم";
    if (dist < 30000) return "مدفعية 155 ملم";
    return "راجمة صواريخ";
  }

  Future<void> _applyCorrections() async {
    if (baseDist == 0) return;

    final isValid = await _checkRangeLimits();
    if (!isValid || !mounted) return;

    final sp = Provider.of<SettingsProvider>(context, listen: false);
    final dirUnit = sp.directionUnit;
    final elvUnit = sp.elevationUnit;

    final wearLoss = double.tryParse(barrelWearCtrl.text) ?? 0.0;
    final wearCorrection = wearLoss * 0.5;
    final wRangeCorr = Ballistics.calculateRangeCorrection(baseDist, temp, pressure);

    // ★ حساب زاوية الموقع والمسافة المائلة
    final deltaH = tgtHeight - gunHeight;
    siteAngleMils = Ballistics.siteAngleMils(deltaH, baseDist, 6400);
    baseSlant = Ballistics.slantRangeMeters(baseDist, deltaH);

    var rows = await _getSmartRowsForRange();
    if (!mounted) return;

    if (rows.isEmpty) {
      final exactKey =
          "${selectedWeaponId}_${selectedShellType.name}_${selectedCountry.name}";
      final fallbackKey = "${selectedWeaponId}_${selectedShellType.name}";
      var allRows = FiringTables.getTableForWeapon(exactKey);
      if (allRows.isEmpty) allRows = FiringTables.getTableForWeapon(fallbackKey);
      if (allRows.isNotEmpty) {
        allRows.sort((a, b) =>
            (a.rangeMeters - baseDist).abs().compareTo((b.rangeMeters - baseDist).abs()));
        rows = [allRows.first];
      }
    }

    if (rows.isEmpty) return;

    final List<int> validCharges = [];
    for (final r in rows) {
      if (r.rangeMeters >= baseDist - 100 && !validCharges.contains(r.charge)) {
        validCharges.add(r.charge);
      }
    }
    if (validCharges.isEmpty) validCharges.add(rows.first.charge);
    validCharges.sort();

    setState(() {
      availableCharges = validCharges;
      if (selectedManualCharge != null &&
          !validCharges.contains(selectedManualCharge)) {
        selectedManualCharge = null;
      }
    });

    FiringTableRow selectedRow;
    if (selectedManualCharge != null &&
        availableCharges.contains(selectedManualCharge)) {
      selectedRow = rows.where((r) => r.charge == selectedManualCharge).reduce((a, b) {
        return (a.rangeMeters - baseDist).abs() < (b.rangeMeters - baseDist).abs()
            ? a
            : b;
      });
    } else {
      final autoCharge =
          availableCharges.isNotEmpty ? availableCharges.first : rows.first.charge;
      final matching = rows.where((r) => r.charge == autoCharge).toList();
      selectedRow = matching.isEmpty
          ? rows.first
          : matching.reduce((a, b) {
              return (a.rangeMeters - baseDist).abs() <
                      (b.rangeMeters - baseDist).abs()
                  ? a
                  : b;
            });
    }

    final int charge = selectedRow.charge;
    // ★ إضافة زاوية الموقع إلى الارتفاع (الجدول بوحدة 6400)
    double elMils = selectedRow.elevationMils.toDouble() + siteAngleMils;
    final double baseTof = selectedRow.timeOfFlightSec;

    final wAzCorr6400 = Ballistics.calculateWindCorrection(baseDist, baseTof,
        windSpeed, windDir * (6400 / dirUnit), baseAz * (6400 / dirUnit), 6400);
    final wAzCorr = wAzCorr6400 * (dirUnit / 6400.0);

    final finalDist = baseDist + corrDist + wRangeCorr + wearCorrection;
    var finalAz = (baseAz + corrAz + wAzCorr) % dirUnit;
    if (finalAz < 0) finalAz += dirUnit;

    double tof = baseTof;
    double fuseTime = 0.0;
    if (isSpecialShell) {
      const descentVel = 180.0;
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

    // ★ عرض الموقع بنفس الوحدة المختارة
    double displaySite = siteAngleMils;
    if (elvUnit == 360) displaySite = siteAngleMils * 360 / 6400;
    if (elvUnit == 6000) displaySite = siteAngleMils * 6000 / 6400;
    final elUnitStr = elvUnit == 360 ? "°" : "مل";
    final recWeapon = _getRecommendedWeapon(finalDist);

    setState(() {
      resultDist = "${finalDist.toStringAsFixed(0)} م";
      resultAz = "${finalAz.toStringAsFixed(0)} ${dirUnit == 360 ? '°' : 'مل'}";
      resultEl = "${displayEl.toStringAsFixed(0)} $elUnitStr";
      resultCharge = "$charge";
      resultTof = "${tof.toStringAsFixed(1)} ث";
      resultFuse = isSpecialShell ? "${fuseTime.toStringAsFixed(1)} ث" : "---";
      resultRecommended = recWeapon;
      resultSite =
          "${displaySite >= 0 ? '+' : ''}${displaySite.toStringAsFixed(0)} $elUnitStr";
      resultSlant = "${baseSlant.toStringAsFixed(0)} م";
      weatherCorrInfo =
          "تصحيح جو: مسافة ${wRangeCorr.toStringAsFixed(0)}م، تآكل: ${wearCorrection.toStringAsFixed(0)}م";
      _timeLeft = tof;
    });
    _stopTimer();
  }

  void _showMissingTableDialog(String tableKey, String title) {
    showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Text('جدول الرمي غير متوفر',
            style: TextStyle(color: Colors.orange)),
        content: Text(
            'لا يوجد جدول رمي محفوظ لهذه التوليفة:\n$title\n\nهل تريد إدخال جدول رمي جديد يدوياً؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx),
            child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () {
              Navigator.pop(dCtx);
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        ManualTableScreen(tableKey: tableKey, title: title)),
              ).then((value) {
                if (value == true) _calculateBase();
              });
            },
            child: const Text('إدخال جدول الآن',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _fetchWeatherAutomatically() async {
    if (gunE.text.isEmpty || gunN.text.isEmpty) return;
    setState(() => isLoadingWeather = true);
    final gunMgrs =
        "${gunZone.text}${gunBand.text}${gunSquare.text}${gunE.text}${gunN.text}";
    final weather = await WeatherService.fetchWeatherByMgrs(gunMgrs);
    if (!mounted) return;
    setState(() => isLoadingWeather = false);
    if (weather == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('تعذر جلب الطقس.'), backgroundColor: Colors.red));
      return;
    }
    final sp = Provider.of<SettingsProvider>(context, listen: false);
    final windDirMils = weather.windDirection * (sp.directionUnit / 360.0);
    showDialog(
      context: context,
      builder: (_) => WeatherDialog(
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

  void _saveFireMissionDialog() {
    if (isTrainingMode || baseDist == 0) return;
    final nameCtrl = TextEditingController();
    final colors = Provider.of<ThemeProvider>(context, listen: false).colors;
    showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        backgroundColor: colors['surface'],
        title: Text('حفظ الرماية', style: TextStyle(color: colors['text'])),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(labelText: 'اسم أو رقم الرماية'),
          style: TextStyle(color: colors['text']),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dCtx),
              child: const Text('إلغاء', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: colors['primary']),
            onPressed: () async {
              if (nameCtrl.text.isNotEmpty) {
                await _saveFireMission(nameCtrl.text);
                if (mounted) Navigator.pop(dCtx);
              }
            },
            child: const Text('حفظ', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    ).then((_) => nameCtrl.dispose());
  }

  Future<void> _saveFireMission(String name) async {
    final prefs = await SharedPreferences.getInstance();
    final missionsJson = prefs.getString('fire_missions');
    final List<FireMission> missions = missionsJson != null
        ? (json.decode(missionsJson) as List)
            .map((e) => FireMission.fromJson(e))
            .toList()
        : [];

    final newMission = FireMission(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      date: DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now()),
      gunMgrs:
          "${gunZone.text}${gunBand.text}${gunSquare.text}${gunE.text}${gunN.text}",
      targetMgrs:
          "${tgtZone.text}${tgtBand.text}${tgtSquare.text}${tgtE.text}${tgtN.text}",
      weaponName: selectedWeaponName,
      shellName: selectedShellName ?? 'غير محدد',
      distance: resultDist,
      azimuth: resultAz,
      elevation: resultEl,
      charge: resultCharge,
      tof: resultTof,
    );

    missions.insert(0, newMission);
    await prefs.setString(
        'fire_missions', json.encode(missions.map((e) => e.toJson()).toList()));

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('تم حفظ الرماية بنجاح'), backgroundColor: Colors.green));
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
                pw.Text("التاريخ: $dateStr",
                    style: pw.TextStyle(font: font, fontSize: 14)),
                pw.Divider(),
                pw.Text("السلاح: $selectedWeaponName",
                    style: pw.TextStyle(font: fontBold)),
                pw.Text("العتاد: ${selectedShellName ?? 'غير محدد'}",
                    style: pw.TextStyle(font: font)),
                pw.SizedBox(height: 10),
                pw.Text(
                    "إحداثيات المدفع: ${gunZone.text}${gunBand.text}${gunSquare.text}${gunE.text}${gunN.text} (ارتفاع: ${gunHeight.toStringAsFixed(0)}م)",
                    style: pw.TextStyle(font: font)),
                pw.Text(
                    "إحداثيات الهدف: ${tgtZone.text}${tgtBand.text}${tgtSquare.text}${tgtE.text}${tgtN.text} (ارتفاع: ${tgtHeight.toStringAsFixed(0)}م)",
                    style: pw.TextStyle(font: font)),
                pw.SizedBox(height: 20),
                pw.Text("بيانات الرمي:",
                    style: pw.TextStyle(font: fontBold, fontSize: 18)),
                pw.Text("المسافة: $resultDist | الاتجاه: $resultAz",
                    style: pw.TextStyle(font: font)),
                pw.Text("الارتفاع: $resultEl | الموقع: $resultSite | مائل: $resultSlant",
                    style: pw.TextStyle(font: font)),
                pw.Text(
                    "الحشوة: $resultCharge | ToF: $resultTof",
                    style: pw.TextStyle(font: font)),
                if (isSpecialShell)
                  pw.Text("توقيت الصمام: $resultFuse",
                      style: pw.TextStyle(font: font, color: PdfColors.red)),
                pw.SizedBox(height: 20),
                pw.Text("البرقية الجوية:", style: pw.TextStyle(font: fontBold)),
                pw.Text(
                    "الحرارة: ${temp.toStringAsFixed(1)}C | الضغط: ${pressure.toStringAsFixed(1)}hPa",
                    style: pw.TextStyle(font: font)),
                pw.Text(
                    "الرياح: ${windSpeed.toStringAsFixed(1)}m/s @ ${windDir.toStringAsFixed(0)}",
                    style: pw.TextStyle(font: font)),
                pw.Text("تآكل السبطانة: ${barrelWearCtrl.text} م/ث",
                    style: pw.TextStyle(font: font)),
                pw.Spacer(),
                pw.Center(
                    child: pw.Text("حاسبة المدفعية", style: pw.TextStyle(font: font))),
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
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _timeLeft -= 0.1;
        if (_timeLeft <= 0) {
          _timeLeft = 0;
          _isTimerRunning = false;
          timer.cancel();
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('انتهى زمن الطيران - سقوط!'),
              backgroundColor: Colors.red));
        }
      });
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    if (mounted) setState(() => _isTimerRunning = false);
  }

  // ==================== بناء الواجهة ====================
  @override
  Widget build(BuildContext context) {
    final colors = Provider.of<ThemeProvider>(context).colors;
    final sp = Provider.of<SettingsProvider>(context);

    final uniqueAmmoKeys =
        savedAmmoList.map((s) => "${s['name']} (${s['country']})").toList();

    return Scaffold(
      backgroundColor: colors['bg'],
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.menu, color: colors['text']),
          onPressed: () => rootScaffoldKey.currentState?.openDrawer(),
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
                child: Text('مدفع ${i + 1}', style: TextStyle(color: colors['text'])),
              ),
            ),
            onChanged: (v) async {
              if (v != null) {
                await _saveGunData(sp.gunNumber);
                await sp.setGunNumber(v);
                await _loadGunData(v);
                if (baseDist > 0) _calculateBase();
              }
            },
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: colors['text']),
            color: colors['surface'],
            onSelected: (v) {
              if (v == 'training') {
                setState(() => isTrainingMode = !isTrainingMode);
              } else if (v == 'high') {
                setState(() => isHighAngle = !isHighAngle);
                if (baseDist > 0) _applyCorrections();
              } else if (v == 'mrsi') {
                if (baseDist > 0) {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => MrsiScreen(
                              baseDistance: baseDist,
                              weaponId: selectedWeaponId,
                              shellType: selectedShellType,
                              country: selectedCountry)));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('احسب مسافة أولاً')));
                }
              }
            },
            itemBuilder: (_) => [
              CheckedPopupMenuItem<String>(
                value: 'training',
                checked: isTrainingMode,
                child: Text('رمي التدريب', style: TextStyle(color: colors['text'])),
              ),
              CheckedPopupMenuItem<String>(
                value: 'high',
                checked: isHighAngle,
                child: Text('الرمي بزوايا عالية',
                    style: TextStyle(color: colors['text'])),
              ),
              PopupMenuItem<String>(
                value: 'mrsi',
                child: Text('الرمي المتزامن (MRSI)',
                    style: TextStyle(color: colors['text'])),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
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
                border: Border.all(color: colors['warning']!),
              ),
              child: Row(
                children: [
                  Icon(Icons.arrow_upward, color: colors['warning']),
                  const SizedBox(width: 8),
                  Text('وضع الزاوية العالية نشط',
                      style: TextStyle(
                          color: colors['warning'], fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          Card(
            color: colors['surface'],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: colors['border']!),
            ),
            child: ExpansionTile(
              title: Text("إعدادات السلاح والذخيرة",
                  style: TextStyle(
                      color: colors['primary'], fontWeight: FontWeight.bold)),
              subtitle: Text(
                "$selectedWeaponName | ${selectedShellType.name.toUpperCase()} | ${selectedCountry.name.toUpperCase()}",
                style: TextStyle(
                    color: colors['text']?.withOpacity(0.7), fontSize: 12),
              ),
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
                          value: DataService.allWeapons
                                  .any((w) => w.id == selectedWeaponId)
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
                              final w = DataService.allWeapons
                                  .firstWhere((e) => e.id == val);
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
                            DropdownMenuItem(
                                value: ShellType.he, child: Text('مهداد (HE)')),
                            DropdownMenuItem(
                                value: ShellType.smoke, child: Text('دخان (Smoke)')),
                            DropdownMenuItem(
                                value: ShellType.illumination,
                                child: Text('تنوير (Illum)')),
                            DropdownMenuItem(
                                value: ShellType.airburst,
                                child: Text('انفلاق جوي (Airburst)')),
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
                            DropdownMenuItem(
                                value: ShellCountry.usa, child: Text('أمريكا')),
                            DropdownMenuItem(
                                value: ShellCountry.russia, child: Text('روسيا')),
                            DropdownMenuItem(
                                value: ShellCountry.china, child: Text('الصين')),
                            DropdownMenuItem(
                                value: ShellCountry.iran, child: Text('إيران')),
                            DropdownMenuItem(
                                value: ShellCountry.serbia, child: Text('صربيا')),
                            DropdownMenuItem(
                                value: ShellCountry.yugoslavia,
                                child: Text('يوغوسلافيا')),
                            DropdownMenuItem(
                                value: ShellCountry.iraq, child: Text('العراق')),
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
                          controller: burstHeightCtrl,
                          keyboardType: TextInputType.number,
                          style: TextStyle(
                              color: colors['warning'],
                              fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            labelText: 'ارتفاع الانفجار المطلوب (متر)',
                            labelStyle: TextStyle(color: colors['warning']),
                            isDense: true,
                          ),
                          onChanged: (val) {
                            burstHeight = double.tryParse(val) ?? 15.0;
                            if (baseDist > 0) _applyCorrections();
                          },
                        ),
                      ],
                      const Divider(),
                      DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          dropdownColor: colors['surface'],
                          value: uniqueAmmoKeys.contains(selectedShellName)
                              ? selectedShellName
                              : null,
                          hint: Text('اختر العتاد',
                              style: TextStyle(color: colors['text'])),
                          items: uniqueAmmoKeys
                              .map((key) => DropdownMenuItem(
                                    value: key,
                                    child: Text(key,
                                        style: TextStyle(color: colors['text'])),
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
                          hint: Text('الحشوة (تلقائي)',
                              style: TextStyle(color: colors['text'])),
                          items: [
                            DropdownMenuItem<int?>(
                              value: null,
                              child: Text('تلقائي (أقل حشوة تصل للهدف)',
                                  style: TextStyle(
                                      color: colors['primary'],
                                      fontWeight: FontWeight.bold)),
                            ),
                            ...availableCharges.map((c) => DropdownMenuItem<int?>(
                                  value: c,
                                  child: Text('الحشوة $c',
                                      style: TextStyle(color: colors['text'])),
                                )),
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
                          helperStyle: TextStyle(
                              color: colors['text']?.withOpacity(0.5),
                              fontSize: 10),
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
              side: BorderSide(color: colors['border']!),
            ),
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
                  // ★ صف ارتفاع المدفع
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: gunHeightCtrl,
                          keyboardType:
                              const TextInputType.numberWithOptions(signed: true),
                          style: TextStyle(
                              color: colors['text'], fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            labelText: 'ارتفاع المدفع (م)',
                            isDense: true,
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                          ),
                          onChanged: (v) {
                            gunHeight = double.tryParse(v) ?? 0;
                            if (baseDist > 0) _applyCorrections();
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: OutlinedButton.icon(
                          onPressed: isLoadingGunElev ? null : _fetchGunElevation,
                          icon: isLoadingGunElev
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.terrain, size: 18),
                          label: const Text('جلب', style: TextStyle(fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: colors['primary'],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            color: colors['surface'],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: colors['border']!),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("إحداثيات الهدف (TARGET)",
                      style: TextStyle(
                          color: colors['primary'],
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(flex: 1, child: _buildField(tgtZone, "Zone", 2, colors)),
                      const SizedBox(width: 5),
                      Expanded(flex: 1, child: _buildField(tgtBand, "Band", 1, colors)),
                      const SizedBox(width: 5),
                      Expanded(flex: 1, child: _buildField(tgtSquare, "Sq", 2, colors)),
                      const SizedBox(width: 5),
                      Expanded(flex: 2, child: _buildField(tgtE, "Easting", 5, colors)),
                      const SizedBox(width: 5),
                      Expanded(flex: 2, child: _buildField(tgtN, "Northing", 5, colors)),
                    ],
                  ),
                  // ★ صف ارتفاع الهدف
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: tgtHeightCtrl,
                          keyboardType:
                              const TextInputType.numberWithOptions(signed: true),
                          style: TextStyle(
                              color: colors['text'], fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            labelText: 'ارتفاع الهدف (م)',
                            isDense: true,
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                          ),
                          onChanged: (v) {
                            tgtHeight = double.tryParse(v) ?? 0;
                            if (baseDist > 0) _applyCorrections();
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: OutlinedButton.icon(
                          onPressed: isLoadingTgtElev ? null : _fetchTgtElevation,
                          icon: isLoadingTgtElev
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.terrain, size: 18),
                          label: const Text('جلب', style: TextStyle(fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: colors['primary'],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
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
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.calculate, size: 28),
                  label: const Text('حساب (CALCULATE)',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: isLoadingWeather
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.cloud_download),
                  label: Text(isLoadingWeather ? 'جاري...' : 'الطقس\nالتلقائي',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12)),
                ),
              ),
            ],
          ),
          if (baseDist > 0)
            Padding(
              padding: const EdgeInsets.only(top: 12.0),
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => MrsiScreen(
                              baseDistance: baseDist,
                              weaponId: selectedWeaponId,
                              shellType: selectedShellType,
                              country: selectedCountry)));
                },
                icon: const Icon(Icons.flash_on, color: Colors.amber),
                label: const Text('حساب الرمي المتزامن (MRSI)'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: colors['surfaceLight'],
                    foregroundColor: colors['text']),
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
                // ★ أسطر جديدة
                _buildResultRow("زاوية الموقع (Site)", resultSite, colors),
                const Divider(),
                _buildResultRow("المسافة المائلة (Slant)", resultSlant, colors),
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
                          color: colors['warning'],
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
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
                    padding: const EdgeInsets.symmetric(
                        vertical: 14, horizontal: 20),
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
                        color: colors['text'],
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Text(
                  _timeLeft.toStringAsFixed(1),
                  style: TextStyle(
                    color: _timeLeft > 0 ? colors['primary'] : Colors.red,
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: _isTimerRunning ? _stopTimer : _startTimer,
                      icon: Icon(
                          _isTimerRunning ? Icons.pause_circle : Icons.play_circle,
                          size: 50,
                          color: colors['primary']),
                    ),
                    const SizedBox(width: 20),
                    IconButton(
                      onPressed: () {
                        _stopTimer();
                        setState(() =>
                            _timeLeft =
                                double.tryParse(resultTof.split(" ")[0]) ?? 0.0);
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
                  color: colors['warning'],
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
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

  Widget _buildCorrButton(
      IconData icon, VoidCallback onPressed, Map<String, Color> colors) {
    return InkWell(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: colors['surfaceLight'],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colors['border']!),
        ),
        child: Icon(icon, color: colors['primary'], size: 24),
      ),
    );
  }

  Widget _buildField(TextEditingController ctrl, String label, int maxLength,
      Map<String, Color> colors) {
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
              style: TextStyle(
                  color: colors['text']?.withOpacity(0.8), fontSize: 16)),
          Text(value,
              style: TextStyle(
                  color: colors['primary'],
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}