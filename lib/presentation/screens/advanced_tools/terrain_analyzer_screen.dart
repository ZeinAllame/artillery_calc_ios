import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../../../theme/theme_provider.dart';

class TerrainAnalyzerScreen extends StatefulWidget {
  const TerrainAnalyzerScreen({Key? key}) : super(key: key);
  @override
  State<TerrainAnalyzerScreen> createState() => _TerrainAnalyzerScreenState();
}

class _TerrainAnalyzerScreenState extends State<TerrainAnalyzerScreen> {
  final _gunElevCtrl = TextEditingController();
  final _tgtElevCtrl = TextEditingController();
  final _distanceCtrl = TextEditingController(text: '5000');
  
  bool _isLoading = false;
  bool _hasInternet = true;
  
  double _gunElevation = 0;
  double _tgtElevation = 0;
  double _distance = 5000;
  double _slope = 0;
  double _slopeAngle = 0;
  String _terrainType = 'مستوي';
  String _gunPosition = 'مناسب';
  String _warning = '';
  List<String> _recommendations = [];

  @override
  void initState() {
    super.initState();
    _loadSavedData();
  }

  Future<void> _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _gunElevation = (prefs.getInt('gun_height') ?? 0).toDouble();
      _tgtElevation = (prefs.getInt('tgt_height') ?? 0).toDouble();
      _gunElevCtrl.text = _gunElevation.toStringAsFixed(0);
      _tgtElevCtrl.text = _tgtElevation.toStringAsFixed(0);
    });
    _analyzeTerrain();
  }

  Future<void> _fetchElevations() async {
    setState(() => _isLoading = true);
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final gunMgrs = prefs.getString('last_gun_mgrs');
      final tgtMgrs = prefs.getString('last_tgt_mgrs');
      
      if (gunMgrs == null || tgtMgrs == null) {
        throw Exception('يجب حساب إحداثيات المدفع والهدف أولاً');
      }
      
      // تحويل MGRS إلى Lat/Lon (مبسط)
      // في الواقع نحتاج مكتبة mgrs_dart
      final gunPoint = _mgrsToPoint(gunMgrs);
      final tgtPoint = _mgrsToPoint(tgtMgrs);
      
      if (gunPoint == null || tgtPoint == null) {
        throw Exception('تعذر تحويل الإحداثيات');
      }
      
      // جلب الارتفاع من Open-Meteo
      final gunElev = await _getElevation(gunPoint[0], gunPoint[1]);
      final tgtElev = await _getElevation(tgtPoint[0], tgtPoint[1]);
      
      if (gunElev == null || tgtElev == null) {
        throw Exception('تعذر جلب الارتفاع - تحقق من الإنترنت');
      }
      
      setState(() {
        _gunElevation = gunElev;
        _tgtElevation = tgtElev;
        _gunElevCtrl.text = gunElev.toStringAsFixed(0);
        _tgtElevCtrl.text = tgtElev.toStringAsFixed(0);
        _hasInternet = true;
      });
      
      await prefs.setInt('gun_height', gunElev.round());
      await prefs.setInt('tgt_height', tgtElev.round());
      
      _analyzeTerrain();
      
    } catch (e) {
      setState(() {
        _hasInternet = false;
        _warning = 'تعذر جلب البيانات: $e\nاستخدم الإدخال اليدوي';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<double?> _getElevation(double lon, double lat) async {
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

  List<double>? _mgrsToPoint(String mgrs) {
    // تحويل مبسط - في الواقع نستخدم mgrs_dart
    // هذا مجرد placeholder
    return null;
  }

  void _analyzeTerrain() {
    _distance = double.tryParse(_distanceCtrl.text) ?? 5000;
    
    if (_distance <= 0) return;
    
    final deltaH = _tgtElevation - _gunElevation;
    _slope = deltaH / _distance;
    _slopeAngle = atan(_slope) * (180 / pi);
    
    // تحديد نوع التضاريس
    if (_slope.abs() < 0.02) {
      _terrainType = 'مستوي';
    } else if (_slope.abs() < 0.1) {
      _terrainType = _slope > 0 ? 'منحدر خفيف لأعلى' : 'منحدر خفيف لأسفل';
    } else if (_slope.abs() < 0.3) {
      _terrainType = _slope > 0 ? 'منحدر متوسط لأعلى' : 'منحدر متوسط لأسفل';
    } else {
      _terrainType = _slope > 0 ? 'منحدر شديد لأعلى' : 'منحدر شديد لأسفل';
    }
    
    // تقييم موقع المدفع
    if (_gunElevation > _tgtElevation + 50) {
      _gunPosition = 'ممتاز - موقع مرتفع';
      _warning = '';
    } else if (_gunElevation > _tgtElevation) {
      _gunPosition = 'جيد - ارتفاع مناسب';
      _warning = '';
    } else if (_gunElevation < _tgtElevation - 100) {
      _gunPosition = 'خطر - موقع منخفض';
      _warning = '⚠️ المدفع في موقع منخفض - خطر التعرض للنيران المباشرة';
    } else {
      _gunPosition = 'مقبول';
      _warning = '';
    }
    
    // التوصيات
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

    return Scaffold(
      backgroundColor: colors['bg'],
      appBar: AppBar(
        title: const Text('كاشف تضاريس الخطر'),
        backgroundColor: colors['surface'],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // زر جلب تلقائي
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _fetchElevations,
              icon: _isLoading 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.cloud_download),
              label: Text(_isLoading ? 'جاري الجلب...' : 'جلب الارتفاع تلقائياً (GPS)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: colors['primary'],
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
            const SizedBox(height: 16),

            // إدخال يدوي
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
                  Text('الإدخال اليدوي (إذا فشل الجلب التلقائي)', 
                      style: TextStyle(color: colors['primary'], fontSize: 14, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _gunElevCtrl,
                          keyboardType: TextInputType.number,
                          style: TextStyle(color: colors['text']),
                          decoration: InputDecoration(
                            labelText: 'ارتفاع المدفع (م)',
                            labelStyle: TextStyle(color: colors['text']?.withOpacity(0.7)),
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
                          keyboardType: TextInputType.number,
                          style: TextStyle(color: colors['text']),
                          decoration: InputDecoration(
                            labelText: 'ارتفاع الهدف (م)',
                            labelStyle: TextStyle(color: colors['text']?.withOpacity(0.7)),
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
                      labelStyle: TextStyle(color: colors['text']?.withOpacity(0.7)),
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

            // نتائج التحليل
            if (!_isLoading) ...[
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
                        style: TextStyle(color: colors['primary'], fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    _buildResultRow('نوع التضاريس', _terrainType, Icons.terrain, colors),
                    _buildResultRow('زاوية الميلان', '${_slopeAngle.toStringAsFixed(1)}°', Icons.trending_up, colors),
                    _buildResultRow('موقع المدفع', _gunPosition, Icons.location_on, colors),
                    _buildResultRow('فرق الارتفاع', '${(_tgtElevation - _gunElevation).toStringAsFixed(0)} م', Icons.height, colors),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // تحذيرات
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
                            style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                      ),
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
                        style: TextStyle(color: colors['primary'], fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    ..._recommendations.map((rec) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle, color: colors['primary'], size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(rec, 
                                style: TextStyle(color: colors['text'], fontSize: 14)),
                          ),
                        ],
                      ),
                    )),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResultRow(String label, String value, IconData icon, Map<String, Color> colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: colors['primary'], size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, 
                style: TextStyle(color: colors['text']?.withOpacity(0.8), fontSize: 14)),
          ),
          Text(value, 
              style: TextStyle(color: colors['primary'], fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}