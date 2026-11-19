import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../theme/theme_provider.dart';

class SmokeCalculatorScreen extends StatefulWidget {
  const SmokeCalculatorScreen({Key? key}) : super(key: key);
  @override
  State<SmokeCalculatorScreen> createState() => _SmokeCalculatorScreenState();
}

class _SmokeCalculatorScreenState extends State<SmokeCalculatorScreen> {
  final _areaWidthCtrl = TextEditingController(text: '100');
  final _areaLengthCtrl = TextEditingController(text: '50');
  final _windSpeedCtrl = TextEditingController(text: '5');
  final _windDirCtrl = TextEditingController(text: '90');
  final _durationCtrl = TextEditingController(text: '10');
  
  String _selectedWeapon = 'mortar120';
  String _selectedShell = 'smoke';
  
  int _requiredRounds = 0;
  double _coverageTime = 0;
  double _driftDistance = 0;
  String _launchTiming = '';
  List<String> _recommendations = [];

  // معدلات التغطية (م²/قذيفة)
  static const Map<String, double> _coverageRates = {
    'mortar60': 50,
    'mortar81': 100,
    'mortar120': 300,
    'm109a6': 500,
    'm198': 500,
  };

  // مدة فعالية الدخان (ثانية)
  static const Map<String, double> _smokeDuration = {
    'smoke': 180, // 3 دقائق
    'wp': 120,    // 2 دقيقة
  };

  void _calculateSmoke() {
    final width = double.tryParse(_areaWidthCtrl.text) ?? 0;
    final length = double.tryParse(_areaLengthCtrl.text) ?? 0;
    final windSpeed = double.tryParse(_windSpeedCtrl.text) ?? 0;
    final duration = double.tryParse(_durationCtrl.text) ?? 0;
    
    if (width <= 0 || length <= 0) return;
    
    final area = width * length;
    final coverageRate = _coverageRates[_selectedWeapon] ?? 100;
    final smokeEffectiveness = _smokeDuration[_selectedShell] ?? 180;
    
    // عدد القذائف الأساسي
    _requiredRounds = (area / coverageRate).ceil();
    
    // تعديل حسب الرياح (الرياح القوية تنشر الدخان أسرع)
    if (windSpeed > 10) {
      _requiredRounds = (_requiredRounds * 1.3).ceil();
    } else if (windSpeed > 5) {
      _requiredRounds = (_requiredRounds * 1.1).ceil();
    }
    
    // مدة التغطية
    _coverageTime = smokeEffectiveness - (windSpeed * 5);
    if (_coverageTime < 60) _coverageTime = 60; // حد أدنى دقيقة
    
    // انحراف الدخان بسبب الرياح
    _driftDistance = windSpeed * (_coverageTime / 60) * 10; // 10م/ث لكل دقيقة
    
    // توقيت الإطلاق
    final timePerRound = 30.0; // 30 ثانية بين كل قذيفة
    _launchTiming = 'إطلاق قذيفة كل ${timePerRound.toStringAsFixed(0)} ثانية\nإجمالي وقت الإطلاق: ${(_requiredRounds * timePerRound / 60).toStringAsFixed(1)} دقيقة';
    
    // التوصيات
    _recommendations = [];
    if (windSpeed > 15) {
      _recommendations.add('⚠️ رياح قوية - الدخان سيتبدد بسرعة');
      _recommendations.add('يُنصح بزيادة عدد القذائف 30%');
    }
    if (_driftDistance > width * 0.5) {
      _recommendations.add('⚠️ انحراف الدخان كبير - غيّر اتجاه الإطلاق');
    }
    if (_coverageTime < 120) {
      _recommendations.add('مدة التغطية قصيرة - جهّز قذائف إضافية');
    }
    if (_requiredRounds > 20) {
      _recommendations.add('عدد كبير من القذائف - استخدم راجمة إن أمكن');
    }
    
    _recommendations.add('✓ أطلق القذائف من الحافة البعيدة للهدف');
    _recommendations.add('✓ انتظر 30 ثانية بعد آخر قذيفة قبل العبور');
    
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colors = Provider.of<ThemeProvider>(context).colors;

    return Scaffold(
      backgroundColor: colors['bg'],
      appBar: AppBar(
        title: const Text('حاسبة الدخان والحجب'),
        backgroundColor: colors['surface'],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // شرح
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors['warning']!.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: colors['warning']!),
              ),
              child: Row(
                children: [
                  Icon(Icons.smoke_free, color: colors['warning']),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'حساب عدد قذائف الدخان المطلوبة لتغطية منطقة معينة مع مراعاة تأثير الرياح',
                      style: TextStyle(color: colors['text'], fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // إدخال البيانات
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
                  Text('بيانات المنطقة المستهدفة', 
                      style: TextStyle(color: colors['primary'], fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _areaWidthCtrl,
                          keyboardType: TextInputType.number,
                          style: TextStyle(color: colors['text']),
                          decoration: InputDecoration(
                            labelText: 'عرض المنطقة (م)',
                            labelStyle: TextStyle(color: colors['text']?.withOpacity(0.7)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _areaLengthCtrl,
                          keyboardType: TextInputType.number,
                          style: TextStyle(color: colors['text']),
                          decoration: InputDecoration(
                            labelText: 'طول المنطقة (م)',
                            labelStyle: TextStyle(color: colors['text']?.withOpacity(0.7)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text('ظروف الرياح', 
                      style: TextStyle(color: colors['primary'], fontSize: 14, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _windSpeedCtrl,
                          keyboardType: TextInputType.number,
                          style: TextStyle(color: colors['text']),
                          decoration: InputDecoration(
                            labelText: 'سرعة الرياح (م/ث)',
                            labelStyle: TextStyle(color: colors['text']?.withOpacity(0.7)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _windDirCtrl,
                          keyboardType: TextInputType.number,
                          style: TextStyle(color: colors['text']),
                          decoration: InputDecoration(
                            labelText: 'اتجاه الرياح (ملة)',
                            labelStyle: TextStyle(color: colors['text']?.withOpacity(0.7)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _durationCtrl,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: colors['text']),
                    decoration: InputDecoration(
                      labelText: 'مدة التغطية المطلوبة (دقيقة)',
                      labelStyle: TextStyle(color: colors['text']?.withOpacity(0.7)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      dropdownColor: colors['surface'],
                      value: _selectedWeapon,
                      style: TextStyle(color: colors['text']),
                      items: const [
                        DropdownMenuItem(value: 'mortar60', child: Text('هاون 60mm')),
                        DropdownMenuItem(value: 'mortar81', child: Text('هاون 81mm')),
                        DropdownMenuItem(value: 'mortar120', child: Text('هاون 120mm')),
                        DropdownMenuItem(value: 'm109a6', child: Text('M109A6 155mm')),
                        DropdownMenuItem(value: 'm198', child: Text('M198 155mm')),
                      ],
                      onChanged: (v) { if (v != null) setState(() => _selectedWeapon = v); },
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _calculateSmoke,
                    icon: const Icon(Icons.calculate),
                    label: const Text('حساب قذائف الدخان'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors['primary'],
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // النتائج
            if (_requiredRounds > 0) ...[
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
                    Text('نتائج الحساب', 
                        style: TextStyle(color: colors['primary'], fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    _buildResultCard('عدد القذائف المطلوب', '$_requiredRounds قذيفة', Icons.add_circle, colors),
                    const SizedBox(height: 8),
                    _buildResultCard('مدة التغطية', '${_coverageTime.toStringAsFixed(0)} ثانية (${(_coverageTime/60).toStringAsFixed(1)} دقيقة)', Icons.timer, colors),
                    const SizedBox(height: 8),
                    _buildResultCard('انحراف الدخان', '${_driftDistance.toStringAsFixed(0)} متر', Icons.air, colors),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colors['warning']!.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('توقيت الإطلاق', 
                              style: TextStyle(color: colors['warning'], fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(_launchTiming, 
                              style: TextStyle(color: colors['text'], fontSize: 13)),
                        ],
                      ),
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
                    Text('التوصيات التكتيكية', 
                        style: TextStyle(color: colors['primary'], fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    ..._recommendations.map((rec) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(rec, 
                          style: TextStyle(color: colors['text'], fontSize: 13)),
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

  Widget _buildResultCard(String label, String value, IconData icon, Map<String, Color> colors) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors['bg'],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors['border']!),
      ),
      child: Row(
        children: [
          Icon(icon, color: colors['primary'], size: 24),
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