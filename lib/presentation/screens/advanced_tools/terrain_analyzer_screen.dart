import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:mgrs_dart/mgrs_dart.dart';
import '../../../theme/theme_provider.dart';

class TerrainAnalyzerScreen extends StatefulWidget {
  const TerrainAnalyzerScreen({Key? key}) : super(key: key);
  @override
  State<TerrainAnalyzerScreen> createState() => _TerrainAnalyzerScreenState();
}

class _TerrainAnalyzerScreenState extends State<TerrainAnalyzerScreen> {
  // حقول إدخال MGRS يدوي (للمدفع والهدف)
  final _gunMgrsCtrl = TextEditingController();
  final _tgtMgrsCtrl = TextEditingController();

  // حقول إدخال الارتفاعات
  final _gunElevCtrl = TextEditingController();
  final _tgtElevCtrl = TextEditingController();
  final _distanceCtrl = TextEditingController(text: '5000');

  bool _isLoading = false;
  bool _autoLoaded = false;

  double _gunElevation = 0;
  double _tgtElevation = 0;
  double _distance = 5000;
  double _slope = 0;
  double _slopeAngle = 0;
  String _terrainType = 'مستوي';
  String _gunPosition = 'مقبول';
  String _warning = '';
  List<String> _recommendations = [];

  @override
  void initState() {
    super.initState();
    _loadSavedData();
  }

  @override
  void dispose() {
    _gunMgrsCtrl.dispose();
    _tgtMgrsCtrl.dispose();
    _gunElevCtrl.dispose();
    _tgtElevCtrl.dispose();
    _distanceCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    final gunMgrs = prefs.getString('last_gun_mgrs') ?? '';
    final tgtMgrs = prefs.getString('last_tgt_mgrs') ?? '';
    final gunH = (prefs.getInt('gun_height') ?? 0).toDouble();
    final tgtH = (prefs.getInt('tgt_height') ?? 0).toDouble();

    if (mounted) {
      setState(() {
        _gunMgrsCtrl.text = gunMgrs;
        _tgtMgrsCtrl.text = tgtMgrs;
        _gunElevation = gunH;
        _tgtElevation = tgtH;
        _gunElevCtrl.text = gunH.toStringAsFixed(0);
        _tgtElevCtrl.text = tgtH.toStringAsFixed(0);
        _autoLoaded = gunMgrs.isNotEmpty && tgtMgrs.isNotEmpty;
      });
      _analyzeTerrain();
    }
  }

  // ★★ الدالة المصححة - تحويل MGRS إلى [lon, lat] ★★
  List<double>? _mgrsToPoint(String mgrs) {
    try {
      final clean = mgrs.replaceAll(' ', '').toUpperCase();
      if (clean.length < 9) return null;
      final point = Mgrs.toPoint(clean);
      // Mgrs.toPoint يعيد [longitude, latitude]
      return [point[1], point[0]]; // [lat, lon]
    } catch (e) {
      print('MGRS Error: $e');
      return null;
    }
  }

  // ★★ حساب المسافة الأفقية بين نقطتين ★★
  double _haversineDistance(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371000.0;
    final dLat = (lat2 - lat1) * pi / 180;
    final dLon = (lon2 - lon1) * pi / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) * cos(lat2 * pi / 180) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  Future<void> _fetchElevations() async {
    setState(() => _isLoading = true);

    try {
      final gunPoint = _mgrsToPoint(_gunMgrsCtrl.text);
      final tgtPoint = _mgrsToPoint(_tgtMgrsCtrl.text);

      if (gunPoint == null || tgtPoint == null) {
        throw Exception('MGRS غير صحيح - تحقق من التنسيق (مثال: 38SMB1287718806)');
      }

      final gunLat = gunPoint[0];
      final gunLon = gunPoint[1];
      final tgtLat = tgtPoint[0];
      final tgtLon = tgtPoint[1];

      // جلب الارتفاعات بالتوازي
      final results = await Future.wait([
        _getElevation(gunLat, gunLon),
        _getElevation(tgtLat, tgtLon),
      ]);

      final gunElev = results[0];
      final tgtElev = results[1];

      if (gunElev == null || tgtElev == null) {
        throw Exception('تعذر الاتصال بخدمة الارتفاعات - تحقق من الإنترنت');
      }

      final distance = _haversineDistance(gunLat, gunLon, tgtLat, tgtLon);

      if (mounted) {
        setState(() {
          _gunElevation = gunElev;
          _tgtElevation = tgtElev;
          _distance = distance;
          _gunElevCtrl.text = gunElev.toStringAsFixed(0);
          _tgtElevCtrl.text = tgtElev.toStringAsFixed(0);
          _distanceCtrl.text = distance.toStringAsFixed(0);
          _warning = '';
        });
        _analyzeTerrain();

        // حفظ البيانات
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('gun_height', gunElev.round());
        await prefs.setInt('tgt_height', tgtElev.round());

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ تم جلب الارتفاعات بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _warning = '⚠️ $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<double?> _getElevation(double lat, double lon) async {
    try {
      final url = Uri.parse(
          'https://api.open-meteo.com/v1/elevation?latitude=$lat&longitude=$lon');
      final res = await http.get(url).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final list = data['elevation'] as List;
        if (list.isNotEmpty) return (list[0] as num).toDouble();
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  void _analyzeTerrain() {
    _distance = double.tryParse(_distanceCtrl.text) ?? 5000;
    _gunElevation = double.tryParse(_gunElevCtrl.text) ?? 0;
    _tgtElevation = double.tryParse(_tgtElevCtrl.text) ?? 0;

    if (_distance <= 0) return;

    final deltaH = _tgtElevation - _gunElevation;
    _slope = deltaH / _distance;
    _slopeAngle = atan(_slope) * (180 / pi);

    if (_slope.abs() < 0.02) {
      _terrainType = 'مستوي';
    } else if (_slope.abs() < 0.1) {
      _terrainType = _slope > 0 ? 'منحدر خفيف لأعلى' : 'منحدر خفيف لأسفل';
    } else if (_slope.abs() < 0.3) {
      _terrainType = _slope > 0 ? 'منحدر متوسط لأعلى' : 'منحدر متوسط لأسفل';
    } else {
      _terrainType = _slope > 0 ? 'منحدر شديد لأعلى' : 'منحدر شديد لأسفل';
    }

    if (_gunElevation > _tgtElevation + 50) {
      _gunPosition = 'ممتاز - موقع مرتفع';
    } else if (_gunElevation > _tgtElevation) {
      _gunPosition = 'جيد - ارتفاع مناسب';
    } else if (_gunElevation < _tgtElevation - 100) {
      _gunPosition = 'خطر - موقع منخفض';
    } else {
      _gunPosition = 'مقبول';
    }

    _recommendations = [];
    if (_slope.abs() > 0.1) {
      _recommendations.add('يُنصح بتصحيح زاوية الموقع (Site Angle)');
    }
    if (_gunElevation < _tgtElevation) {
      _recommendations.add('تأكد من وجود ساتر خلفي للمدفع');
    }
    if (_distance < 1000) {
      _recommendations.add('مسافة قريبة - استخدم حشوة منخفضة');
    }
    if (_terrainType.contains('شديد')) {
      _recommendations.add('تضاريس وعرة - تحقق من خط الرؤية');
    }
    if (_recommendations.isEmpty) {
      _recommendations.add('التضاريس مناسبة للرمي');
    }

    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colors = Provider.of<ThemeProvider>(context).colors;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // قسم إدخال MGRS
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors['surface'],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors['border']!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.location_searching, color: colors['primary']),
                  const SizedBox(width: 8),
                  Text('إحداثيات MGRS',
                      style: TextStyle(
                          color: colors['primary'],
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _gunMgrsCtrl,
                style: TextStyle(color: colors['text']),
                decoration: InputDecoration(
                  labelText: 'MGRS المدفع (مثال: 38SMB1287718806)',
                  labelStyle:
                      TextStyle(color: colors['text']?.withOpacity(0.7)),
                  border:
                      OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _tgtMgrsCtrl,
                style: TextStyle(color: colors['text']),
                decoration: InputDecoration(
                  labelText: 'MGRS الهدف',
                  labelStyle:
                      TextStyle(color: colors['text']?.withOpacity(0.7)),
                  border:
                      OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _fetchElevations,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.cloud_download),
                label: Text(_isLoading
                    ? 'جاري الجلب...'
                    : 'جلب الارتفاع والمسافة تلقائياً'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors['primary'],
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
              if (_autoLoaded) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 16),
                    const SizedBox(width: 4),
                    Text('تم تحميل الإحداثيات المحفوظة من آخر عملية حساب',
                        style: TextStyle(
                            color: Colors.green, fontSize: 11)),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        // الإدخال اليدوي
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors['surface'],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors['border']!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('الإدخال اليدوي',
                  style: TextStyle(
                      color: colors['primary'],
                      fontSize: 14,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _gunElevCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(signed: true),
                      style: TextStyle(color: colors['text']),
                      decoration: InputDecoration(
                        labelText: 'ارتفاع المدفع (م)',
                        labelStyle: TextStyle(
                            color: colors['text']?.withOpacity(0.7)),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      onChanged: (v) {
                        _gunElevation = double.tryParse(v) ?? 0;
                        _analyzeTerrain();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _tgtElevCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(signed: true),
                      style: TextStyle(color: colors['text']),
                      decoration: InputDecoration(
                        labelText: 'ارتفاع الهدف (م)',
                        labelStyle: TextStyle(
                            color: colors['text']?.withOpacity(0.7)),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      onChanged: (v) {
                        _tgtElevation = double.tryParse(v) ?? 0;
                        _analyzeTerrain();
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _distanceCtrl,
                keyboardType: TextInputType.number,
                style: TextStyle(color: colors['text']),
                decoration: InputDecoration(
                  labelText: 'المسافة الأفقية (م)',
                  labelStyle:
                      TextStyle(color: colors['text']?.withOpacity(0.7)),
                  border:
                      OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onChanged: (v) {
                  _distance = double.tryParse(v) ?? 5000;
                  _analyzeTerrain();
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // تحذير الخطأ
        if (_warning.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning, color: Colors.red),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(_warning,
                      style: const TextStyle(
                          color: Colors.red, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),

        // نتائج التحليل
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors['surface'],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors['primary']!, width: 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('نتائج تحليل التضاريس',
                  style: TextStyle(
                      color: colors['primary'],
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              _buildResultRow(
                  'نوع التضاريس', _terrainType, Icons.terrain, colors),
              _buildResultRow(
                  'زاوية الميلان',
                  '${_slopeAngle.toStringAsFixed(1)}°',
                  Icons.trending_up,
                  colors),
              _buildResultRow(
                  'موقع المدفع', _gunPosition, Icons.location_on, colors),
              _buildResultRow(
                  'فرق الارتفاع',
                  '${(_tgtElevation - _gunElevation).toStringAsFixed(0)} م',
                  Icons.swap_vert,
                  colors),
              _buildResultRow(
                  'المسافة الأفقية',
                  '${_distance.toStringAsFixed(0)} م',
                  Icons.straighten,
                  colors),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // التوصيات
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors['surface'],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('التوصيات',
                  style: TextStyle(
                      color: colors['primary'],
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ..._recommendations.map((rec) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle,
                            color: colors['primary'], size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(rec,
                              style: TextStyle(
                                  color: colors['text'], fontSize: 14)),
                        ),
                      ],
                    ),
                  )),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResultRow(
      String label, String value, IconData icon, Map<String, Color> colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: colors['primary'], size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
                style: TextStyle(
                    color: colors['text']?.withOpacity(0.8), fontSize: 14)),
          ),
          Text(value,
              style: TextStyle(
                  color: colors['primary'],
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}