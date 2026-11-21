import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mgrs_dart/mgrs_dart.dart';

import '../../../utils/event_bus.dart';
import '../../../models/friendly_unit.dart';
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

class _CalculatorScreenState extends State<CalculatorScreen> with WidgetsBindingObserver {
  final gunZone = TextEditingController();
  final gunBand = TextEditingController();
  final gunSquare = TextEditingController();
  final gunE = TextEditingController();
  final gunN = TextEditingController();
  final gunHeightCtrl = TextEditingController();
  final barrelWearCtrl = TextEditingController();
  final burstHeightCtrl = TextEditingController(text: '15');

  final obsZone = TextEditingController();
  final obsBand = TextEditingController();
  final obsSquare = TextEditingController();
  final obsE = TextEditingController();
  final obsN = TextEditingController();

  final tgtZone = TextEditingController(text: "38");
  final tgtBand = TextEditingController(text: "S");
  final tgtSquare = TextEditingController(text: "MB");
  final tgtE = TextEditingController(text: "35995");
  final tgtN = TextEditingController(text: "83060");
  final tgtHeightCtrl = TextEditingController();

  String selectedWeaponId = "mortar120";
  String selectedWeaponName = "هاون 120 ملم M120/M220";
  ShellType selectedShellType = ShellType.he;
  ShellCountry selectedCountry = ShellCountry.usa;

  String? selectedShellName;
  int? selectedManualCharge;
    var savedAmmoList = [];



  bool isTrainingMode = false;
  bool isHighAngle = false;

  double burstHeight = 15.0;
  bool get isSpecialShell => selectedShellType == ShellType.airburst || selectedShellType == ShellType.illumination;

  double temp = 15.0;
  double pressure = 1013.25;
  double windSpeed = 0.0;
  double windDir = 0.0;
  bool isLoadingWeather = false;
  bool isLoadingGunGps = false;
  bool isLoadingGunElev = false;
  bool isLoadingTgtElev = false;
  bool isLoadingObsGps = false;

  double baseDist = 0;
  double baseAz = 0;

  double gunHeight = 0;
  double tgtHeight = 0;
  double siteAngleMils = 0;
  double baseSlant = 0;

  double gunUtmE = 0;
  double gunUtmN = 0;

  double origTgtEasting = 0;
  double origTgtNorthing = 0;
  double curTgtEasting = 0;
  double curTgtNorthing = 0;
  bool hasCorrectedTarget = false;

  double obsEasting = 0;
  double obsNorthing = 0;
  double obsDist = 0;
  double obsAz = 0;

  bool observerActive = false;
  bool dangerCloseWarning = false;
  String dangerCloseMessage = '';

  String correctionMode = 'gun';

  int correctionStepsLongitudinal = 0;
  int correctionStepsLateral = 0;

  String resultDist = "---";
  String resultAz = "---";
  String resultEl = "---";
  String resultCharge = "---";
  String resultTof = "---";
  String resultFuse = "---";
  String resultRecommended = "---";
  String resultSite = "---";
  String resultSlant = "---";
  String weatherCorrInfo = "لم يتم جلب الطقس بعد";

  List<int> availableCharges = [];

  Timer? _timer;
  double _timeLeft = 0.0;
  bool _isTimerRunning = false;

  Timer? _obsDebounce;

  final ScrollController _scrollCtrl = ScrollController();
  final GlobalKey _resultsKey = GlobalKey();

  SettingsProvider? _sp;
  int _lastDirUnit = 0;
  int _lastElUnit = 0;
  StreamSubscription<AppEvent>? _eventSub;

  @override
  void initState() {
    super.initState();
    FriendlyForcesStore.load();
    WidgetsBinding.instance.addObserver(this);
    _loadAmmoFromTracker();
    _checkForIncomingTarget();

    _eventSub = EventBus.instance.stream.listen((e) {
      if (e.type == kTargetSentEvent) {
        _checkForIncomingTarget();
      }
    });

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
    _eventSub?.cancel();
    _obsDebounce?.cancel();
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
    obsZone.dispose();
    obsBand.dispose();
    obsSquare.dispose();
    obsE.dispose();
    obsN.dispose();
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

  void _scheduleObserverUpdate() {
    _obsDebounce?.cancel();
    _obsDebounce = Timer(const Duration(milliseconds: 700), () {
      if (mounted) _updateObserverInfo();
    });
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
    final gUtm = MgrsDecoder.decode("${gunZone.text}${gunBand.text}${gunSquare.text}${gunE.text}${gunN.text}");
    if (gUtm != null) {
      setState(() {
        gunUtmE = gUtm.easting;
        gunUtmN = gUtm.northing;
      });
    }
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
                savedAmmoList = List.from(json.decode(ammoJson));
        final uniqueAmmoKeys = savedAmmoList.map((s) => "${s['name']} (${s['country']})").toList();
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
      final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      final mgrsStr = Mgrs.forward([position.longitude, position.latitude], 5);
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
        final gUtm = MgrsDecoder.decode("${gunZone.text}${gunBand.text}${gunSquare.text}${gunE.text}${gunN.text}");
        if (gUtm != null) {
          setState(() {
            gunUtmE = gUtm.easting;
            gunUtmN = gUtm.northing;
          });
        }
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم جلب موقع المدفع')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر جلب الموقع')));
    } finally {
      if (mounted) setState(() => isLoadingGunGps = false);
    }
  }

  Future<void> _getGpsForObserver() async {
    setState(() => isLoadingObsGps = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.deniedForever) return;
      final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      final mgrsStr = Mgrs.forward([position.longitude, position.latitude], 5);
      if (mounted) {
        setState(() {
          obsZone.text = mgrsStr.substring(0, 2);
          obsBand.text = mgrsStr.substring(2, 3);
          obsSquare.text = mgrsStr.substring(3, 5);
          obsE.text = mgrsStr.substring(5, 10);
          obsN.text = mgrsStr.substring(10, 15);
        });
        _updateObserverInfo();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم جلب موقع الراصد')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر جلب موقع الراصد')));
    } finally {
      if (mounted) setState(() => isLoadingObsGps = false);
    }
  }

  Future<void> _fetchGunElevation() async {
    setState(() => isLoadingGunElev = true);
    try {
      final gMgrs = "${gunZone.text}${gunBand.text}${gunSquare.text}${gunE.text}${gunN.text}";
      final pt = Mgrs.toPoint(gMgrs);
      final h = await ElevationService.fetchElevation(pt[1], pt[0]);
      if (!mounted) return;
      if (h == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر جلب الارتفاع — أدخله يدوياً'), backgroundColor: Colors.red));
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => isLoadingGunElev = false);
    }
  }

  Future<void> _fetchTgtElevation() async {
    setState(() => isLoadingTgtElev = true);
    try {
      final tMgrs = "${tgtZone.text}${tgtBand.text}${tgtSquare.text}${tgtE.text}${tgtN.text}";
      final pt = Mgrs.toPoint(tMgrs);
      final h = await ElevationService.fetchElevation(pt[1], pt[0]);
      if (!mounted) return;
      if (h == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر جلب الارتفاع — أدخله يدوياً'), backgroundColor: Colors.red));
      } else {
        setState(() {
          tgtHeightCtrl.text = h.toStringAsFixed(0);
          tgtHeight = h;
        });
        if (baseDist > 0) _applyCorrections();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => isLoadingTgtElev = false);
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

      setState(() {
        gunUtmE = gUtm.easting;
        gunUtmN = gUtm.northing;
        origTgtEasting = tUtm.easting;
        origTgtNorthing = tUtm.northing;
        curTgtEasting = tUtm.easting;
        curTgtNorthing = tUtm.northing;
        hasCorrectedTarget = false;
        correctionStepsLongitudinal = 0;
        correctionStepsLateral = 0;
      });

      final dE = tUtm.easting - gUtm.easting;
      final dN = tUtm.northing - gUtm.northing;
      final grid = MgrsDecoder.calculateGrid(dE, dN, sp.directionUnit);
      baseDist = grid['distance']!;
      baseAz = grid['azimuth']!;

      _updateObserverInfo();

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

  void _updateObserverInfo() {
    if (obsZone.text.isEmpty || obsE.text.isEmpty || obsN.text.isEmpty || baseDist == 0) {
      setState(() {
        obsEasting = 0;
        obsNorthing = 0;
        obsDist = 0;
        obsAz = 0;
      });
      return;
    }
    try {
      final oMgrs = "${obsZone.text}${obsBand.text.toUpperCase()}${obsSquare.text.toUpperCase()}${obsE.text}${obsN.text}";
      final oUtm = MgrsDecoder.decode(oMgrs);
      if (oUtm == null) {
        setState(() {
          obsEasting = 0;
          obsNorthing = 0;
          obsDist = 0;
          obsAz = 0;
        });
        return;
      }
      setState(() {
        obsEasting = oUtm.easting;
        obsNorthing = oUtm.northing;
      });
      _updateObserverInfoFromCoords();
    } catch (e) {
      setState(() {
        obsDist = 0;
        obsAz = 0;
      });
    }
  }

  void _updateObserverInfoFromCoords() {
    if (obsEasting == 0 && obsNorthing == 0) {
      setState(() {
        obsDist = 0;
        obsAz = 0;
      });
      return;
    }
    final sp = Provider.of<SettingsProvider>(context, listen: false);
    final oDe = curTgtEasting - obsEasting;
    final oDn = curTgtNorthing - obsNorthing;
    final oGrid = MgrsDecoder.calculateGrid(oDe, oDn, sp.directionUnit);
    setState(() {
      obsDist = oGrid['distance']!;
      obsAz = oGrid['azimuth']!;
    });
  }

  Future<void> _doCorrectionStep({required bool isLateral, required bool positive}) async {
    if (baseDist == 0) return;
    final sp = Provider.of<SettingsProvider>(context, listen: false);
    const step = 50.0;

    double refAz;
    if (correctionMode == 'observer') {
      if (obsDist == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('أدخل إحداثيات الراصد أولاً'), backgroundColor: Colors.red),
        );
        return;
      }
      refAz = obsAz;
    } else {
      refAz = baseAz;
    }

    final refRad = (refAz * 2 * math.pi) / sp.directionUnit;
    final r = positive ? step : -step;

    double dE, dN;
    if (isLateral) {
      dE = r * math.cos(refRad);
      dN = -r * math.sin(refRad);
    } else {
      dE = r * math.sin(refRad);
      dN = r * math.cos(refRad);
    }

    setState(() {
      curTgtEasting += dE;
      curTgtNorthing += dN;
      hasCorrectedTarget = true;
      if (isLateral) {
        correctionStepsLateral += positive ? 1 : -1;
      } else {
        correctionStepsLongitudinal += positive ? 1 : -1;
      }
    });

    await _recalcBaseFromCoords();
  }

  Future<void> _recalcBaseFromCoords() async {
    final sp = Provider.of<SettingsProvider>(context, listen: false);
    try {
      final gMgrs = "${gunZone.text}${gunBand.text}${gunSquare.text}${gunE.text}${gunN.text}";
      final gUtm = MgrsDecoder.decode(gMgrs);
      if (gUtm == null) return;

      setState(() {
        gunUtmE = gUtm.easting;
        gunUtmN = gUtm.northing;
      });

      final dE = curTgtEasting - gUtm.easting;
      final dN = curTgtNorthing - gUtm.northing;
      final grid = MgrsDecoder.calculateGrid(dE, dN, sp.directionUnit);
      baseDist = grid['distance']!;
      baseAz = grid['azimuth']!;

      _updateObserverInfoFromCoords();
      await _applyCorrections();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
  }

  Future<void> _resetFireCorrection() async {
    if (!hasCorrectedTarget) return;
    setState(() {
      curTgtEasting = origTgtEasting;
      curTgtNorthing = origTgtNorthing;
      hasCorrectedTarget = false;
      correctionStepsLongitudinal = 0;
      correctionStepsLateral = 0;
    });
    await _recalcBaseFromCoords();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم إلغاء التصحيحات — الهدف عاد لموقعه الأصلي'), backgroundColor: Colors.blue),
    );
  }

  List<String> _candidateTableKeys() {
    final shell = selectedShellType.name.toLowerCase();
    final country = selectedCountry.name.toLowerCase();
    final Map<String, String> shellAlias = {
      'illumination': 'illum',
      'he': 'he',
      'smoke': 'smoke',
      'airburst': 'airburst',
    };
    final shellShort = shellAlias[shell] ?? shell;

    final keys = <String>{
      selectedWeaponId,
      "${selectedWeaponId}_$shellShort",
      "${selectedWeaponId}_$shell",
      "${selectedWeaponId}_${shellShort}_$country",
      "${selectedWeaponId}_${shell}_$country",
    }.toList();

    final seen = <String>{};
    return keys.where((k) => seen.add(k)).toList();
  }

  Future<String?> _resolveTableKey() async {
    final prefs = await SharedPreferences.getInstance();
    for (final k in _candidateTableKeys()) {
      if (FiringTables.getTableForWeapon(k).isNotEmpty) return k;
      if (prefs.getString('custom_table_$k') != null) return k;
    }

    final shell = selectedShellType.name.toLowerCase();
    final country = selectedCountry.name.toLowerCase();
    final shellShort = (shell == 'illumination') ? 'illum' : shell;

    final allKeys = <String>{...FiringTables.getAllTables().keys};
    for (final pk in prefs.getKeys()) {
      if (pk.startsWith('custom_table_')) {
        allKeys.add(pk.replaceFirst('custom_table_', ''));
      }
    }

    for (final k in allKeys) {
      final hasShell = k.contains('_${shellShort}_') || k.contains('_${shell}_') || k.endsWith('_${shellShort}') || k.endsWith('_${shell}');
      final hasCountry = k.endsWith('_$country') || k.contains('_$country');
      if (hasShell && hasCountry) {
        final rows = FiringTables.getTableForWeapon(k);
        if (rows.isNotEmpty) return k;
        if (prefs.getString('custom_table_$k') != null) {
          final list = jsonDecode(prefs.getString('custom_table_$k')!) as List;
          final customRows = list.map((e) => FiringTableRow.fromJson(e as Map<String, dynamic>)).toList();
          FiringTables.addCustomTable(k, customRows);
          return k;
        }
      }
    }

    for (final k in allKeys) {
      final hasShell = k.contains('_${shellShort}_') || k.contains('_${shell}_') || k.endsWith('_${shellShort}') || k.endsWith('_${shell}');
      if (hasShell && FiringTables.getTableForWeapon(k).isNotEmpty) return k;
    }

    return null;
  }

  Future<List<FiringTableRow>> _getSmartRowsForRange() async {
    final key = await _resolveTableKey();
    if (key == null) return [];
    var rows = FiringTables.findRowsForRange(key, baseDist.round());
    if (rows.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      final customJson = prefs.getString('custom_table_$key');
      if (customJson != null) {
        final list = jsonDecode(customJson) as List;
        final customRows = list.map((e) => FiringTableRow.fromJson(e as Map<String, dynamic>)).toList();
        FiringTables.addCustomTable(key, customRows);
        rows = FiringTables.findRowsForRange(key, baseDist.round());
      }
    }
    return rows;
  }

  Future<bool> _checkRangeLimits() async {
    final key = await _resolveTableKey();
    if (!mounted) return false;

    if (key == null) {
      _showMissingTableDialog(selectedWeaponId, "$selectedWeaponName - ${selectedShellType.name.toUpperCase()}");
      return false;
    }

    final allRows = FiringTables.getTableForWeapon(key);
    if (allRows.isEmpty) return true;

    final maxRange = allRows.map((r) => r.rangeMeters.toDouble()).reduce((a, b) => a > b ? a : b);
    final minRange = allRows.map((r) => r.rangeMeters.toDouble()).reduce((a, b) => a < b ? a : b);

    if (!mounted) return false;

    if (baseDist > maxRange) {
      final proceed = await _showContinueDialog(
        "تنبيه: الهدف خارج المدى الأقصى",
        "المسافة (${baseDist.toStringAsFixed(0)} م) تتجاوز المدى الأقصى ($maxRange م).\n\nهل تريد المتابعة بأقصى مدى متوفر؟",
      );
      return proceed ?? false;
    }
    if (baseDist < minRange) {
      final recommended = _getRecommendedWeapon(baseDist);
      final proceed = await _showContinueDialog(
        "تنبيه: المسافة قريبة جداً",
        "المسافة (${baseDist.toStringAsFixed(0)} م) أقل من المدى الأدنى ($minRange م).\n\nيُفضل: $recommended\n\nهل تريد المتابعة بأقل مدى متوفر؟",
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
        title: Text(title, style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
        content: Text(message, style: const TextStyle(fontSize: 16)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('إلغاء', style: TextStyle(color: Colors.grey))),
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

  void _checkDangerClose() {
    dangerCloseWarning = false;
    dangerCloseMessage = '';

    final points = FriendlyForcesStore.roots.expand((r) => r.collectPoints()).toList();
    for (final p in points) {
      if (p.utmE != null && p.utmN != null) {
        final dE = p.utmE! - curTgtEasting;
        final dN = p.utmN! - curTgtNorthing;
        final dist = math.sqrt(dE * dE + dN * dN);
        if (dist <= p.safetyRadiusM) {
          dangerCloseWarning = true;
          dangerCloseMessage = '⚠️ DANGER CLOSE: "${p.name}" على مسافة ${dist.toStringAsFixed(0)}م فقط من الهدف (حد الأمان ${p.safetyRadiusM.toStringAsFixed(0)}م)';
          return;
        }
      }
    }
  }

  Future<bool> _confirmDangerClose() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        backgroundColor: Colors.red.shade900,
        title: const Text('🔴 تحذير اقتراب خطر', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
        content: Text(
          '$dangerCloseMessage\n\nالرمي على هذا الهدف قد يعرّض القوات الصديقة للخطر.\nلا يتم التنفيذ إلا بموافقة قائد الوحدة.',
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('إلغاء الرمي')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () => Navigator.pop(dCtx, true),
            child: const Text('موافقة القائد — متابعة', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _applyCorrections() async {
    if (baseDist == 0) return;

    _checkDangerClose();
    if (dangerCloseWarning) {
      final ok = await _confirmDangerClose();
      if (!ok || !mounted) return;
    }

    final isValid = await _checkRangeLimits();
    if (!isValid || !mounted) return;

    final sp = Provider.of<SettingsProvider>(context, listen: false);
    final dirUnit = sp.directionUnit;
    final elvUnit = sp.elevationUnit;

    final wearLoss = double.tryParse(barrelWearCtrl.text) ?? 0.0;
    final wearCorrection = wearLoss * 0.5;
    final wRangeCorr = Ballistics.calculateRangeCorrection(baseDist, temp, pressure);

    final deltaH = tgtHeight - gunHeight;
    siteAngleMils = Ballistics.siteAngleMils(deltaH, baseDist, 6400);
    baseSlant = Ballistics.slantRangeMeters(baseDist, deltaH);

    var rows = await _getSmartRowsForRange();
    if (!mounted) return;

    if (rows.isEmpty) {
      final key = await _resolveTableKey();
      if (key != null) {
        final allRows = FiringTables.getTableForWeapon(key);
        if (allRows.isNotEmpty) {
          allRows.sort((a, b) => (a.rangeMeters - baseDist).abs().compareTo((b.rangeMeters - baseDist).abs()));
          rows = [allRows.first];
        }
      }
    }
    if (rows.isEmpty) return;

    final List<int> validCharges = [];
    for (final r in rows) {
      if (r.rangeMeters >= baseDist - 100 && !validCharges.contains(r.charge)) validCharges.add(r.charge);
    }
    if (validCharges.isEmpty) validCharges.add(rows.first.charge);
    validCharges.sort();

    if (mounted) {
      setState(() {
        availableCharges = validCharges;
        if (selectedManualCharge != null && !validCharges.contains(selectedManualCharge)) selectedManualCharge = null;
      });
    }

    FiringTableRow selectedRow;
    if (selectedManualCharge != null && availableCharges.contains(selectedManualCharge)) {
      selectedRow = rows.where((r) => r.charge == selectedManualCharge).reduce((a, b) {
        return (a.rangeMeters - baseDist).abs() < (b.rangeMeters - baseDist).abs() ? a : b;
      });
    } else {
      final autoCharge = availableCharges.isNotEmpty ? availableCharges.first : rows.first.charge;
      final matching = rows.where((r) => r.charge == autoCharge).toList();
      selectedRow = matching.isEmpty ? rows.first : matching.reduce((a, b) {
        return (a.rangeMeters - baseDist).abs() < (b.rangeMeters - baseDist).abs() ? a : b;
      });
    }

    final int charge = selectedRow.charge;
    double elMils = selectedRow.elevationMils.toDouble() + siteAngleMils;
    final double baseTof = selectedRow.timeOfFlightSec;

    final wAzCorr6400 = Ballistics.calculateWindCorrection(
      baseDist,
      baseTof,
      windSpeed,
      windDir * (6400 / dirUnit),
      baseAz * (6400 / dirUnit),
      6400,
    );
    final wAzCorr = wAzCorr6400 * (dirUnit / 6400.0);

    final finalDist = baseDist + wRangeCorr + wearCorrection;
    var finalAz = (baseAz + wAzCorr) % dirUnit;
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
      resultSite = "${displaySite >= 0 ? '+' : ''}${displaySite.toStringAsFixed(0)} $elUnitStr";
      resultSlant = "${baseSlant.toStringAsFixed(0)} م";
      weatherCorrInfo = "تصحيح جو: مسافة ${wRangeCorr.toStringAsFixed(0)}م، تآكل: ${wearCorrection.toStringAsFixed(0)}م";
      _timeLeft = tof;
    });
    _stopTimer();

    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('last_charge', resultCharge);
      prefs.setString('last_azimuth', resultAz);
      prefs.setString('last_elevation', resultEl);
      prefs.setString('last_tof', resultTof);
      prefs.setString('last_shell_type', selectedShellType.name);
      prefs.setString('last_distance', resultDist);
    });
  }

  void _showMissingTableDialog(String tableKey, String title) {
    showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Text('جدول الرمي غير متوفر', style: TextStyle(color: Colors.orange)),
        content: Text('لا يوجد جدول رمي محفوظ:\n$title\n\nهل تريد إدخال جدول يدوياً؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('إلغاء', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () {
              Navigator.pop(dCtx);
              Navigator.push(context, MaterialPageRoute(builder: (_) => ManualTableScreen(tableKey: tableKey, title: title))).then((value) {
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر جلب الطقس.'), backgroundColor: Colors.red));
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
    final rootCtx = rootScaffoldKey.currentContext ?? context;
    showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        backgroundColor: colors['surface'],
        title: Text('حفظ الرماية', style: TextStyle(color: colors['text'])),
        content: TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'اسم أو رقم الرماية'), style: TextStyle(color: colors['text'])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('إلغاء', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: colors['primary']),
            onPressed: () async {
              if (nameCtrl.text.isNotEmpty) {
                await _saveFireMission(nameCtrl.text);
                if (dCtx.mounted) Navigator.pop(dCtx);
                if (rootCtx.mounted) {
                  ScaffoldMessenger.of(rootCtx).showSnackBar(const SnackBar(content: Text('تم حفظ الرماية بنجاح'), backgroundColor: Colors.green));
                }
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
                pw.Center(child: pw.Text("أمر الرمي - FIRE ORDER", style: pw.TextStyle(font: fontBold, fontSize: 24))),
                pw.SizedBox(height: 20),
                pw.Text("التاريخ: $dateStr", style: pw.TextStyle(font: font, fontSize: 14)),
                pw.Divider(),
                pw.Text("السلاح: $selectedWeaponName", style: pw.TextStyle(font: fontBold)),
                pw.Text("العتاد: ${selectedShellName ?? 'غير محدد'}", style: pw.TextStyle(font: font)),
                pw.SizedBox(height: 10),
                pw.Text("إحداثيات المدفع: ${gunZone.text}${gunBand.text}${gunSquare.text}${gunE.text}${gunN.text} (ارتفاع: ${gunHeight.toStringAsFixed(0)}م)", style: pw.TextStyle(font: font)),
                pw.Text("إحداثيات الهدف: ${tgtZone.text}${tgtBand.text}${tgtSquare.text}${tgtE.text}${tgtN.text} (ارتفاع: ${tgtHeight.toStringAsFixed(0)}م)", style: pw.TextStyle(font: font)),
                pw.SizedBox(height: 20),
                pw.Text("بيانات الرمي:", style: pw.TextStyle(font: fontBold, fontSize: 18)),
                pw.Text("المسافة: $resultDist | الاتجاه: $resultAz", style: pw.TextStyle(font: font)),
                pw.Text("الارتفاع: $resultEl | الموقع: $resultSite | مائل: $resultSlant", style: pw.TextStyle(font: font)),
                pw.Text("الحشوة: $resultCharge | ToF: $resultTof", style: pw.TextStyle(font: font)),
                if (isSpecialShell) pw.Text("توقيت الصمام: $resultFuse", style: pw.TextStyle(font: font, color: PdfColors.red)),
                pw.SizedBox(height: 20),
                pw.Text("البرقية الجوية:", style: pw.TextStyle(font: fontBold)),
                pw.Text("الحرارة: ${temp.toStringAsFixed(1)}C | الضغط: ${pressure.toStringAsFixed(1)}hPa", style: pw.TextStyle(font: font)),
                pw.Text("الرياح: ${windSpeed.toStringAsFixed(1)}m/s @ ${windDir.toStringAsFixed(0)}", style: pw.TextStyle(font: font)),
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
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('انتهى زمن الطيران - سقوط!'), backgroundColor: Colors.red));
        }
      });
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    if (mounted) setState(() => _isTimerRunning = false);
  }

  String _observerDiagnosis() {
    if (baseDist == 0) return 'احسب المسافة أولاً بالضغط على زر «حساب»';
    final z = obsZone.text.trim();
    final b = obsBand.text.trim();
    final s = obsSquare.text.trim();
    final e = obsE.text.trim();
    final n = obsN.text.trim();
    if (z.isEmpty || b.isEmpty || s.isEmpty || e.isEmpty || n.isEmpty) {
      return 'أكمل جميع حقول الراصد (Zone, Band, Sq, E, N)';
    }
    if (z.length != 2 || !RegExp(r'^\d{2}$').hasMatch(z)) {
      return 'Zone يجب أن يكون رقمين (مثال: 38)';
    }
    if (b.length != 1 || !RegExp(r'^[C-HJ-NP-X]$').hasMatch(b.toUpperCase())) {
      return 'Band يجب أن يكون حرفاً واحداً صحيحاً (C–X بدون I و O)';
    }
    if (s.length != 2 || !RegExp(r'^[A-Z]{2}$').hasMatch(s.toUpperCase())) {
      return 'Sq يجب أن يكون حرفين (مثال: NC) — أنت كتبت ${s.length} حرف فقط';
    }
    if (e.length != 5 || !RegExp(r'^\d{5}$').hasMatch(e)) {
      return 'Easting يجب أن يكون 5 أرقام (مثال: 20000)';
    }
    if (n.length != 5 || !RegExp(r'^\d{5}$').hasMatch(n)) {
      return 'Northing يجب أن يكون 5 أرقام (مثال: 31000)';
    }
    return 'تعذر فك تشفير MGRS — تحقق من صحة الأحرف والأرقام';
  }

  Widget _observerErrorCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.orange, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _observerDiagnosis(),
              style: const TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Provider.of<ThemeProvider>(context).colors;
    final sp = Provider.of<SettingsProvider>(context);
    final uniqueAmmoKeys = savedAmmoList.map((s) => "${s['name']} (${s['country']})").toList();

    return Scaffold(
      backgroundColor: colors['bg'],
      appBar: AppBar(
        leading: IconButton(icon: Icon(Icons.menu, color: colors['text']), onPressed: () => rootScaffoldKey.currentState?.openDrawer()),
        title: Text(isTrainingMode ? 'وضع التدريب' : 'حاسبة الرمي'),
        backgroundColor: colors['surface'],
        centerTitle: true,
        actions: [
          DropdownButton<int>(
            value: sp.gunNumber,
            dropdownColor: colors['surface'],
            underline: const SizedBox(),
            icon: Icon(Icons.rocket_launch, color: colors['warning']),
            items: List.generate(6, (i) => DropdownMenuItem(value: i + 1, child: Text('مدفع ${i + 1}', style: TextStyle(color: colors['text'])))),
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
                  Navigator.push(context, MaterialPageRoute(builder: (_) => MrsiScreen(baseDistance: baseDist, weaponId: selectedWeaponId, shellType: selectedShellType, country: selectedCountry)));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('احسب مسافة أولاً')));
                }
              }
            },
            itemBuilder: (_) => [
              CheckedPopupMenuItem<String>(value: 'training', checked: isTrainingMode, child: Text('رمي التدريب', style: TextStyle(color: colors['text']))),
              CheckedPopupMenuItem<String>(value: 'high', checked: isHighAngle, child: Text('الرمي بزوايا عالية', style: TextStyle(color: colors['text']))),
              PopupMenuItem<String>(value: 'mrsi', child: Text('الرمي المتزامن (MRSI)', style: TextStyle(color: colors['text']))),
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
              child: Row(children: [
                Icon(Icons.arrow_upward, color: colors['warning']),
                const SizedBox(width: 8),
                Text('وضع الزاوية العالية نشط', style: TextStyle(color: colors['warning'], fontWeight: FontWeight.bold)),
              ]),
            ),
          Card(
            color: colors['surface'],
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: colors['border']!)),
            child: ExpansionTile(
              title: Text("إعدادات السلاح والذخيرة", style: TextStyle(color: colors['primary'], fontWeight: FontWeight.bold)),
              subtitle: Text("$selectedWeaponName | ${selectedShellType.name.toUpperCase()} | ${selectedCountry.name.toUpperCase()}", style: TextStyle(color: colors['text']?.withOpacity(0.7), fontSize: 12)),
              iconColor: colors['primary'],
              collapsedIconColor: colors['text'],
              children: [
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    children: [
                      DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          dropdownColor: colors['surface'],
                          value: DataService.allWeapons.any((w) => w.id == selectedWeaponId) ? selectedWeaponId : null,
                          items: DataService.allWeapons.map((w) => DropdownMenuItem(value: w.id, child: Text("${w.nameAr} (${w.origin})", style: TextStyle(color: colors['text'])))).toList(),
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
                            DropdownMenuItem(value: ShellType.illumination, child: Text('تنوير (Illum)')),
                            DropdownMenuItem(value: ShellType.airburst, child: Text('انفلاق جوي (Airburst)')),
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
                            DropdownMenuItem(value: ShellCountry.yugoslavia, child: Text('يوغوسلافيا')),
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
                          controller: burstHeightCtrl,
                          keyboardType: TextInputType.number,
                          style: TextStyle(color: colors['warning'], fontWeight: FontWeight.bold),
                          decoration: InputDecoration(labelText: 'ارتفاع الانفجار المطلوب (متر)', labelStyle: TextStyle(color: colors['warning']), isDense: true),
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
                          value: uniqueAmmoKeys.contains(selectedShellName) ? selectedShellName : null,
                          hint: Text('اختر العتاد', style: TextStyle(color: colors['text'])),
                          items: uniqueAmmoKeys.map((key) => DropdownMenuItem(value: key, child: Text(key, style: TextStyle(color: colors['text'])))).toList(),
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
                          value: availableCharges.contains(selectedManualCharge) ? selectedManualCharge : null,
                          hint: Text('الحشوة (تلقائي)', style: TextStyle(color: colors['text'])),
                          items: [
                            DropdownMenuItem<int?>(value: null, child: Text('تلقائي (أقل حشوة تصل للهدف)', style: TextStyle(color: colors['primary'], fontWeight: FontWeight.bold))),
                            ...availableCharges.map((c) => DropdownMenuItem<int?>(value: c, child: Text('الحشوة $c', style: TextStyle(color: colors['text'])))),
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
                        decoration: InputDecoration(labelText: 'تآكل السبطانة (م/ث)', labelStyle: TextStyle(color: colors['warning']), isDense: true),
                        style: TextStyle(color: colors['warning'], fontWeight: FontWeight.bold),
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

          // ============ المدفع ============
          Card(
            color: colors['surface'],
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: colors['border']!)),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text("إحداثيات المدفع (GUN)", style: TextStyle(color: colors['primary'], fontSize: 16, fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: isLoadingGunGps
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.gps_fixed, color: Colors.cyan),
                      onPressed: _getGpsForGun,
                    ),
                  ]),
                  Row(children: [
                    Expanded(flex: 1, child: _buildField(gunZone, "Zone", 2, colors, digits: true)),
                    const SizedBox(width: 5),
                    Expanded(flex: 1, child: _buildField(gunBand, "Band", 1, colors, letters: true)),
                    const SizedBox(width: 5),
                    Expanded(flex: 1, child: _buildField(gunSquare, "Sq", 2, colors, letters: true)),
                    const SizedBox(width: 5),
                    Expanded(flex: 2, child: _buildField(gunE, "Easting", 5, colors, digits: true)),
                    const SizedBox(width: 5),
                    Expanded(flex: 2, child: _buildField(gunN, "Northing", 5, colors, digits: true)),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: gunHeightCtrl,
                        keyboardType: const TextInputType.numberWithOptions(signed: true),
                        style: TextStyle(color: colors['text'], fontWeight: FontWeight.bold),
                        decoration: const InputDecoration(labelText: 'ارتفاع المدفع (م)', isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 8)),
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
                        icon: isLoadingGunElev ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.terrain, size: 18),
                        label: const Text('جلب', style: TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(foregroundColor: colors['primary']),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ============ الهدف ============
          Card(
            color: colors['surface'],
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: colors['border']!)),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("إحداثيات الهدف (TARGET)", style: TextStyle(color: colors['primary'], fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(flex: 1, child: _buildField(tgtZone, "Zone", 2, colors, digits: true)),
                    const SizedBox(width: 5),
                    Expanded(flex: 1, child: _buildField(tgtBand, "Band", 1, colors, letters: true)),
                    const SizedBox(width: 5),
                    Expanded(flex: 1, child: _buildField(tgtSquare, "Sq", 2, colors, letters: true)),
                    const SizedBox(width: 5),
                    Expanded(flex: 2, child: _buildField(tgtE, "Easting", 5, colors, digits: true)),
                    const SizedBox(width: 5),
                    Expanded(flex: 2, child: _buildField(tgtN, "Northing", 5, colors, digits: true)),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: tgtHeightCtrl,
                        keyboardType: const TextInputType.numberWithOptions(signed: true),
                        style: TextStyle(color: colors['text'], fontWeight: FontWeight.bold),
                        decoration: const InputDecoration(labelText: 'ارتفاع الهدف (م)', isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 8)),
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
                        icon: isLoadingTgtElev ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.terrain, size: 18),
                        label: const Text('جلب', style: TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(foregroundColor: colors['primary']),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ============ الراصد (دائم) ============
          Card(
            color: colors['surface'],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: observerActive ? Colors.green : colors['border']!),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text("إحداثيات الراصد (OBS)", style: TextStyle(color: observerActive ? Colors.green : colors['warning'], fontSize: 16, fontWeight: FontWeight.bold)),
                    Row(children: [
                      IconButton(
                        icon: isLoadingObsGps
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.gps_fixed, color: Colors.cyan),
                        onPressed: _getGpsForObserver,
                      ),
                      Switch(
                        value: observerActive,
                        activeColor: Colors.green,
                        onChanged: (v) {
                          setState(() {
                            observerActive = v;
                            correctionMode = v ? 'observer' : 'gun';
                          });
                          if (v) _updateObserverInfo();
                          if (baseDist > 0) _recalcBaseFromCoords();
                        },
                      ),
                    ]),
                  ]),
                  if (observerActive) ...[
                    Row(children: [
                      Expanded(flex: 1, child: _buildField(obsZone, "Zone", 2, colors, digits: true, debounce: true)),
                      const SizedBox(width: 5),
                      Expanded(flex: 1, child: _buildField(obsBand, "Band", 1, colors, letters: true, debounce: true)),
                      const SizedBox(width: 5),
                      Expanded(flex: 1, child: _buildField(obsSquare, "Sq", 2, colors, letters: true, debounce: true)),
                      const SizedBox(width: 5),
                      Expanded(flex: 2, child: _buildField(obsE, "Easting", 5, colors, digits: true, debounce: true)),
                      const SizedBox(width: 5),
                      Expanded(flex: 2, child: _buildField(obsN, "Northing", 5, colors, digits: true, debounce: true)),
                    ]),
                    const SizedBox(height: 8),
                    if (obsDist > 0) ...[
                      ObserverAngleIndicator(
                        gunE: gunUtmE,
                        gunN: gunUtmN,
                        tgtE: curTgtEasting,
                        tgtN: curTgtNorthing,
                        obsE: obsEasting,
                        obsN: obsNorthing,
                        gunDist: baseDist,
                        obsDist: obsDist,
                        gunCoord: '${gunZone.text}${gunBand.text}${gunSquare.text} ${gunE.text} ${gunN.text}',
                        tgtCoord: '${tgtZone.text}${tgtBand.text}${tgtSquare.text} ${tgtE.text} ${tgtN.text}',
                        obsCoord: '${obsZone.text}${obsBand.text}${obsSquare.text} ${obsE.text} ${obsN.text}',
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                        child: Row(children: [
                          const Icon(Icons.visibility, color: Colors.green, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'راصد→هدف: ${obsDist.toStringAsFixed(0)} م | اتجاه: ${obsAz.toStringAsFixed(0)} ${sp.directionUnit == 360 ? "°" : "مل"}',
                              style: const TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ]),
                      ),
                    ] else
                      _observerErrorCard(),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          Row(children: [
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
                label: const Text('حساب (CALCULATE)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                icon: isLoadingWeather ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.cloud_download),
                label: Text(isLoadingWeather ? 'جاري...' : 'الطقس\nالتلقائي', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
              ),
            ),
          ]),
          if (baseDist > 0)
            Padding(
              padding: const EdgeInsets.only(top: 12.0),
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => MrsiScreen(baseDistance: baseDist, weaponId: selectedWeaponId, shellType: selectedShellType, country: selectedCountry)));
                },
                icon: const Icon(Icons.flash_on, color: Colors.amber),
                label: const Text('حساب الرمي المتزامن (MRSI)'),
                style: ElevatedButton.styleFrom(backgroundColor: colors['surfaceLight'], foregroundColor: colors['text']),
              ),
            ),
          const SizedBox(height: 24),

          // ============ النتائج ============
          Container(
            key: _resultsKey,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: colors['surface'], borderRadius: BorderRadius.circular(12), border: Border.all(color: colors['border']!)),
            child: Column(
              children: [
                _buildResultRow("المسافة (Range)", resultDist, colors),
                const Divider(),
                _buildResultRow("الاتجاه (Azimuth)", resultAz, colors),
                const Divider(),
                _buildResultRow("زاوية الارتفاع (Elevation)", resultEl, colors),
                const Divider(),
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
                  child: Text(weatherCorrInfo, style: TextStyle(color: colors['warning'], fontSize: 12, fontWeight: FontWeight.bold)),
                ),
                if (dangerCloseWarning) ...[
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.red.withOpacity(0.15), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red)),
                      child: Text(dangerCloseMessage, style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (baseDist > 0)
            Row(children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _exportPdf,
                  style: ElevatedButton.styleFrom(backgroundColor: colors['secondary'], foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text('تصدير PDF', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: _saveFireMissionDialog,
                style: ElevatedButton.styleFrom(backgroundColor: colors['primary'], foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20)),
                child: const Icon(Icons.save),
              ),
            ]),
          const SizedBox(height: 24),

          if (baseDist > 0) _buildCorrectionPanel(colors, sp.directionUnit),
          const SizedBox(height: 24),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: colors['surfaceLight'], borderRadius: BorderRadius.circular(12), border: Border.all(color: colors['primary']!, width: 2)),
            child: Column(
              children: [
                Text('مؤقت الرمي (Countdown)', style: TextStyle(color: colors['text'], fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Text(
                  _timeLeft.toStringAsFixed(1),
                  style: TextStyle(color: _timeLeft > 0 ? colors['primary'] : Colors.red, fontSize: 48, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                ),
                const SizedBox(height: 10),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  IconButton(
                    onPressed: _isTimerRunning ? _stopTimer : _startTimer,
                    icon: Icon(_isTimerRunning ? Icons.pause_circle : Icons.play_circle, size: 50, color: colors['primary']),
                  ),
                  const SizedBox(width: 20),
                  IconButton(
                    onPressed: () {
                      _stopTimer();
                      setState(() => _timeLeft = double.tryParse(resultTof.split(" ")[0]) ?? 0.0);
                    },
                    icon: Icon(Icons.refresh, size: 40, color: colors['text']),
                  ),
                ]),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildCorrectionPanel(Map<String, Color> colors, int dirUnit) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: colors['surface'], borderRadius: BorderRadius.circular(12), border: Border.all(color: colors['warning']!, width: 1.5)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Icon(Icons.tune, color: colors['warning']),
            const SizedBox(width: 8),
            Text('تصحيح الرمي اليدوي', style: TextStyle(color: colors['warning'], fontSize: 18, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 8),
          Text(
            'خط المرجع الحالي: ${observerActive ? "راصد ← هدف" : "مدفع ← هدف"}',
            style: TextStyle(color: observerActive ? Colors.green : colors['text'], fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            Column(children: [
              Text('زيد / نقص (م)', style: TextStyle(color: colors['text'], fontSize: 13)),
              const SizedBox(height: 8),
              Row(children: [
                _buildCorrButton(Icons.remove, () => _doCorrectionStep(isLateral: false, positive: false), colors),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text(
                    '${(correctionStepsLongitudinal * 50) > 0 ? "+" : ""}${correctionStepsLongitudinal * 50}',
                    style: TextStyle(
                      color: correctionStepsLongitudinal != 0 ? colors['primary'] : colors['text'],
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _buildCorrButton(Icons.add, () => _doCorrectionStep(isLateral: false, positive: true), colors),
              ]),
            ]),
            Column(children: [
              Text('يمين / يسار (م)', style: TextStyle(color: colors['text'], fontSize: 13)),
              const SizedBox(height: 8),
              Row(children: [
                _buildCorrButton(Icons.arrow_left, () => _doCorrectionStep(isLateral: true, positive: false), colors),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text(
                    '${(correctionStepsLateral * 50) > 0 ? "+" : ""}${correctionStepsLateral * 50}',
                    style: TextStyle(
                      color: correctionStepsLateral != 0 ? colors['primary'] : colors['text'],
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _buildCorrButton(Icons.arrow_right, () => _doCorrectionStep(isLateral: true, positive: true), colors),
              ]),
            ]),
          ]),
          const SizedBox(height: 12),
          Text('كل ضغطة = تحريك الهدف 50 متراً', style: TextStyle(color: colors['text']?.withOpacity(0.5), fontSize: 11), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          if (hasCorrectedTarget)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors['primary']!.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: colors['primary']!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.my_location, color: colors['primary'], size: 18),
                    const SizedBox(width: 6),
                    Text('إحداثيات الهدف بعد التصحيح (UTM)', style: TextStyle(color: colors['primary'], fontSize: 13, fontWeight: FontWeight.bold)),
                  ]),
                  const SizedBox(height: 8),
                  _buildCoordLine('قبل التصحيح:', 'E ${origTgtEasting.toStringAsFixed(0)}  N ${origTgtNorthing.toStringAsFixed(0)}', colors),
                  _buildCoordLine('بعد التصحيح:', 'E ${curTgtEasting.toStringAsFixed(0)}  N ${curTgtNorthing.toStringAsFixed(0)}', colors),
                  _buildCoordLine('الإزاحة:', 'ΔE ${(curTgtEasting - origTgtEasting).toStringAsFixed(0)}  ΔN ${(curTgtNorthing - origTgtNorthing).toStringAsFixed(0)}', colors),
                ],
              ),
            ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: _resetFireCorrection,
            icon: const Icon(Icons.restart_alt, color: Colors.red),
            label: const Text('إلغاء التصحيحات', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildCoordLine(String label, String value, Map<String, Color> colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: colors['text']?.withOpacity(0.7), fontSize: 12)),
          Text(value, style: TextStyle(color: colors['text'], fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
        ],
      ),
    );
  }

  Widget _buildCorrButton(IconData icon, VoidCallback onPressed, Map<String, Color> colors) {
    return InkWell(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: colors['surfaceLight'], borderRadius: BorderRadius.circular(8), border: Border.all(color: colors['border']!)),
        child: Icon(icon, color: colors['primary'], size: 24),
      ),
    );
  }

  Widget _buildField(
    TextEditingController ctrl,
    String label,
    int maxLength,
    Map<String, Color> colors, {
    bool letters = false,
    bool digits = false,
    bool debounce = false,
  }) {
    return TextField(
      controller: ctrl,
      maxLength: maxLength,
      textAlign: TextAlign.center,
      autocorrect: false,
      enableSuggestions: false,
      textCapitalization: letters ? TextCapitalization.characters : TextCapitalization.none,
      inputFormatters: [
        if (letters) FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z]')),
        if (digits) FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(maxLength),
      ],
      style: TextStyle(color: colors['text'], fontWeight: FontWeight.bold),
      decoration: InputDecoration(labelText: label, counterText: "", contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4), isDense: true),
      onChanged: debounce ? (v) => _scheduleObserverUpdate() : null,
    );
  }

  Widget _buildResultRow(String label, String value, Map<String, Color> colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: colors['text']?.withOpacity(0.8), fontSize: 16)),
          Text(value, style: TextStyle(color: colors['primary'], fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

// ============================================================
// ★★ مخطط المواقع — مطابق للشكل المطلوب بدون أي تداخل للنصوص ★★
// ============================================================
class ObserverAngleIndicator extends StatelessWidget {
  final double gunE, gunN;
  final double tgtE, tgtN;
  final double obsE, obsN;
  final double gunDist, obsDist;
  final String gunCoord;
  final String tgtCoord;
  final String obsCoord;

  const ObserverAngleIndicator({
    Key? key,
    required this.gunE,
    required this.gunN,
    required this.tgtE,
    required this.tgtN,
    required this.obsE,
    required this.obsN,
    required this.gunDist,
    required this.obsDist,
    required this.gunCoord,
    required this.tgtCoord,
    required this.obsCoord,
  }) : super(key: key);

  double get angleAtTargetDeg {
    double ang(double dx, double dy) {
      var a = math.atan2(dx, dy) * 180 / math.pi;
      if (a < 0) a += 360;
      return a;
    }

    final a1 = ang(gunE - tgtE, gunN - tgtN);
    final a2 = ang(obsE - tgtE, obsN - tgtN);
    var d = a2 - a1;
    if (d > 180) d -= 360;
    if (d < -180) d += 360;
    return d.abs();
  }

  String _formatAngleValue(int unit) {
    final deg = angleAtTargetDeg;
    if (unit == 360) {
      return '${deg.toStringAsFixed(0)}°';
    }
    final mils = deg * (unit / 360.0);
    return '${mils.toStringAsFixed(0)} مل';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Provider.of<ThemeProvider>(context).colors;
    final sp = Provider.of<SettingsProvider>(context);
    final dirUnit = sp.directionUnit;
    final formattedAngle = _formatAngleValue(dirUnit);
    final infoStyle = GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.bold, color: colors['text']);

    return Container(
      height: 265,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.14),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: CustomPaint(
              painter: _ObserverDiagramPainter(
                gunE: gunE,
                gunN: gunN,
                tgtE: tgtE,
                tgtN: tgtN,
                obsE: obsE,
                obsN: obsN,
                angleText: 'الزاوية: $formattedAngle',
              ),
            ),
          ),
          VerticalDivider(color: colors['border'], width: 1),
          Expanded(
            flex: 2,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _infoRow('المدفع', gunCoord, Colors.blue, infoStyle),
                  const SizedBox(height: 6),
                  _infoRow('الهدف', tgtCoord, Colors.red, infoStyle),
                  const SizedBox(height: 6),
                  _infoRow('الراصد', obsCoord, Colors.green, infoStyle),
                  const SizedBox(height: 6),
                  Divider(color: colors['border'], height: 8),
                  const SizedBox(height: 4),
                  Text('الزاوية عند الهدف:', style: GoogleFonts.cairo(fontSize: 10, color: colors['text']?.withOpacity(0.7))),
                  Text(formattedAngle, style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange)),
                  const SizedBox(height: 4),
                  Text('مدفع→هدف: ${gunDist.toStringAsFixed(0)} م', style: GoogleFonts.cairo(fontSize: 10, color: colors['text']?.withOpacity(0.7))),
                  Text('راصد→هدف: ${obsDist.toStringAsFixed(0)} م', style: GoogleFonts.cairo(fontSize: 10, color: colors['text']?.withOpacity(0.7))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, Color color, TextStyle style) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 4),
            Text(label, style: GoogleFonts.cairo(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
        Text(value, style: style),
      ],
    );
  }
}

class _ObserverDiagramPainter extends CustomPainter {
  final double gunE, gunN;
  final double tgtE, tgtN;
  final double obsE, obsN;
  final String angleText;

  _ObserverDiagramPainter({
    required this.gunE,
    required this.gunN,
    required this.tgtE,
    required this.tgtN,
    required this.obsE,
    required this.obsN,
    required this.angleText,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.52);
    final maxRadius = (size.shortestSide * 0.36).clamp(42.0, 82.0);

    final ringPaint = Paint()
      ..color = Colors.white.withOpacity(0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(center, maxRadius, ringPaint);
    canvas.drawCircle(center, maxRadius * 0.65, ringPaint);
    canvas.drawCircle(center, maxRadius * 0.32, ringPaint);

    final gdx = gunE - tgtE;
    final gdy = gunN - tgtN;
    final odx = obsE - tgtE;
    final ody = obsN - tgtN;

    final maxSpan = [gdx.abs(), gdy.abs(), odx.abs(), ody.abs()].reduce(math.max);
    final scale = maxSpan > 0 ? (maxRadius * 0.90) / maxSpan : 0.04;

    final gunPos = Offset(center.dx + gdx * scale, center.dy - gdy * scale);
    final obsPos = Offset(center.dx + odx * scale, center.dy - ody * scale);

    canvas.drawLine(
      center,
      gunPos,
      Paint()
        ..color = Colors.blue
        ..strokeWidth = 3.2
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      center,
      obsPos,
      Paint()
        ..color = Colors.green
        ..strokeWidth = 3.2
        ..strokeCap = StrokeCap.round,
    );

    final a1 = math.atan2(gdx, -gdy);
    final a2 = math.atan2(odx, -ody);
    var start = a1 - math.pi / 2;
    var sweep = a2 - a1;
    if (sweep > math.pi) sweep -= 2 * math.pi;
    if (sweep < -math.pi) sweep += 2 * math.pi;

    const arcRadius = 26.0;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: arcRadius),
      start,
      sweep,
      false,
      Paint()
        ..color = Colors.orange
        ..strokeWidth = 2.6
        ..style = PaintingStyle.stroke,
    );

    _drawNonOverlappingAngleLabel(
      canvas: canvas,
      size: size,
      center: center,
      gunPos: gunPos,
      obsPos: obsPos,
      midAngle: start + sweep / 2,
      arcRadius: arcRadius,
      text: angleText,
    );

    _drawGunSymbol(canvas, gunPos, Colors.blue);
    _drawObserverSymbol(canvas, obsPos, Colors.green);
    _drawTargetSymbol(canvas, center, Colors.red);
  }

  void _drawNonOverlappingAngleLabel({
    required Canvas canvas,
    required Size size,
    required Offset center,
    required Offset gunPos,
    required Offset obsPos,
    required double midAngle,
    required double arcRadius,
    required String text,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.orange,
        ),
      ),
      textDirection: ui.TextDirection.rtl,
    );
    tp.layout();

    final candidateAngles = <double>[
      midAngle,
      midAngle + math.pi,
      midAngle + math.pi / 2,
      midAngle - math.pi / 2,
    ];

    Offset bestPos = Offset(
      center.dx + (arcRadius + 24) * math.cos(midAngle),
      center.dy + (arcRadius + 24) * math.sin(midAngle),
    );
    double bestScore = -1e9;

    for (final ang in candidateAngles) {
      for (final dist in [arcRadius + 22.0, arcRadius + 36.0]) {
        final rawX = center.dx + dist * math.cos(ang);
        final rawY = center.dy + dist * math.sin(ang);
        final x = (rawX - tp.width / 2).clamp(6.0, size.width - tp.width - 6.0);
        final y = (rawY - tp.height / 2).clamp(6.0, size.height - tp.height - 6.0);
        final rect = Rect.fromLTWH(x - 4, y - 2, tp.width + 8, tp.height + 4);

        final dGun = _distPointToSegment(rect.center, center, gunPos);
        final dObs = _distPointToSegment(rect.center, center, obsPos);
        final dCenter = (rect.center - center).distance;
        final dGunPt = (rect.center - gunPos).distance;
        final dObsPt = (rect.center - obsPos).distance;

        final minLineDist = math.min(dGun, dObs);
        final minPtDist = [dCenter, dGunPt, dObsPt].reduce(math.min);
        final score = minLineDist * 1.4 + minPtDist * 0.8;

        if (score > bestScore) {
          bestScore = score;
          bestPos = Offset(x, y);
        }
      }
    }

    final bgRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(bestPos.dx - 4, bestPos.dy - 2, tp.width + 8, tp.height + 4),
      const Radius.circular(5),
    );
    canvas.drawRRect(bgRect, Paint()..color = const Color(0xFF1E1B16).withOpacity(0.88));
    tp.paint(canvas, bestPos);
  }

  double _distPointToSegment(Offset p, Offset a, Offset b) {
    final abx = b.dx - a.dx;
    final aby = b.dy - a.dy;
    final lenSq = abx * abx + aby * aby;
    if (lenSq == 0) return (p - a).distance;
    final t = (((p.dx - a.dx) * abx + (p.dy - a.dy) * aby) / lenSq).clamp(0.0, 1.0);
    final proj = Offset(a.dx + t * abx, a.dy + t * aby);
    return (p - proj).distance;
  }

  void _drawTargetSymbol(Canvas canvas, Offset p, Color color) {
    final armPaint = Paint()
      ..color = color
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    const inner = 4.8;
    const outer = 11.5;

    canvas.drawLine(Offset(p.dx - outer, p.dy - outer), Offset(p.dx - inner, p.dy - inner), armPaint);
    canvas.drawLine(Offset(p.dx + inner, p.dy + inner), Offset(p.dx + outer, p.dy + outer), armPaint);
    canvas.drawLine(Offset(p.dx + outer, p.dy - outer), Offset(p.dx + inner, p.dy - inner), armPaint);
    canvas.drawLine(Offset(p.dx - inner, p.dy + inner), Offset(p.dx - outer, p.dy + outer), armPaint);

    canvas.drawCircle(p, 2.8, Paint()..color = color);
  }

  void _drawGunSymbol(Canvas canvas, Offset p, Color color) {
    canvas.drawCircle(
      p,
      8.8,
      Paint()
        ..color = color
        ..strokeWidth = 2.6
        ..style = PaintingStyle.stroke,
    );
    canvas.drawCircle(p, 2.8, Paint()..color = color);
  }

  void _drawObserverSymbol(Canvas canvas, Offset p, Color color) {
    const r = 10.2;
    final path = Path();
    for (int i = 0; i < 3; i++) {
      final angle = -math.pi / 2 + i * (2 * math.pi / 3);
      final vx = p.dx + r * math.cos(angle);
      final vy = p.dy + r * math.sin(angle);
      if (i == 0) {
        path.moveTo(vx, vy);
      } else {
        path.lineTo(vx, vy);
      }
    }
    path.close();

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 2.6
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawCircle(p, 2.6, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _ObserverDiagramPainter old) =>
      old.gunE != gunE ||
      old.gunN != gunN ||
      old.obsE != obsE ||
      old.obsN != obsN ||
      old.tgtE != tgtE ||
      old.tgtN != tgtN ||
      old.angleText != angleText;
}
