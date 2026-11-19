import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../../theme/theme_provider.dart';
import '../../../domain/firing_table.dart';

class MrsiProScreen extends StatefulWidget {
  const MrsiProScreen({Key? key}) : super(key: key);
  @override
  State<MrsiProScreen> createState() => _MrsiProScreenState();
}

class _MrsiProScreenState extends State<MrsiProScreen> {
  String _selectedWeapon = 'm109a6';
  String _targetRange = '';
  int _numCharges = 3;
  List<Map<String, dynamic>> _mrsiResults = [];
  bool _isCalculating = false;

  // بيانات تجريبية لـ ToF حسب الحشوة (ثانية) - سيتم استبدالها ببيانات من الجدول
  final Map<String, Map<int, double>> _tofByCharge = {
    'm109a6': {1: 35, 2: 45, 3: 60, 4: 75, 5: 90, 6: 110, 7: 130, 8: 150},
    'm198': {1: 35, 2: 45, 3: 60, 4: 75, 5: 90, 6: 110, 7: 130, 8: 150},
    'mortar120': {1: 20, 2: 28, 3: 35, 4: 42, 5: 50, 6: 58, 7: 65, 8: 72},
    'mortar81': {1: 15, 2: 20, 3: 25, 4: 30, 5: 35, 6: 40},
    'mortar60': {1: 10, 2: 14, 3: 18},
  };

  Future<void> _calculateMrsi() async {
    final range = double.tryParse(_targetRange);
    if (range == null || range <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أدخل مسافة الهدف'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isCalculating = true);

    // محاكاة حساب ToF من الجدول
    await Future.delayed(const Duration(milliseconds: 500));

    final weaponTof = _tofByCharge[_selectedWeapon] ?? _tofByCharge['m109a6']!;
    final charges = List<int>.generate(_numCharges, (i) => i + 1);
    
    // حساب ToF لكل حشوة (مع تعديل بسيط حسب المسافة)
    final rangeFactor = range / 10000;
    final List<Map<String, dynamic>> results = [];
    
    for (int charge in charges) {
      final baseTof = weaponTof[charge] ?? (30.0 + charge * 10);
      final adjustedTof = baseTof * (0.7 + rangeFactor * 0.5);
      
      results.add({
        'charge': charge,
        'tof': adjustedTof,
        'elevation': _calculateElevation(charge, range),
        'launchDelay': 0.0, // سيتم حسابه لاحقاً
      });
    }

    // ترتيب حسب ToF تنازلياً (الأطول أولاً)
    results.sort((a, b) => (b['tof'] as double).compareTo(a['tof'] as double));

    // حساب فارق زمن الإطلاق
    final maxTof = results.first['tof'] as double;
    for (var r in results) {
      r['launchDelay'] = maxTof - (r['tof'] as double);
    }

    // ترتيب حسب رقم الحشوة للعرض
    results.sort((a, b) => (a['charge'] as int).compareTo(b['charge'] as int));

    setState(() {
      _mrsiResults = results;
      _isCalculating = false;
    });
  }

  double _calculateElevation(int charge, double range) {
    // محاكاة حساب الارتفاع (في الواقع سيُقرأ من الجدول)
    final baseEl = 200.0 + (charge * 50);
    final rangeFactor = range / 5000;
    return baseEl * rangeFactor;
  }

  Future<void> _saveMrsiPlan() async {
    if (_mrsiResults.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final plans = prefs.getStringList('mrsi_plans') ?? [];
    
    final planData = {
      'date': DateTime.now().toIso8601String(),
      'weapon': _selectedWeapon,
      'range': _targetRange,
      'charges': _numCharges,
      'results': _mrsiResults,
    };
    
    plans.insert(0, json.encode(planData));
    if (plans.length > 20) plans.removeLast(); // الاحتفاظ بآخر 20 خطة
    
    await prefs.setStringList('mrsi_plans', plans);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ خطة MRSI'), backgroundColor: Colors.green),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Provider.of<ThemeProvider>(context).colors;

    return Scaffold(
      backgroundColor: colors['bg'],
      appBar: AppBar(
        title: const Text('MRSI Pro - الرمي المتزامن'),
        backgroundColor: colors['surface'],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // شرح MRSI
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors['warning']!.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: colors['warning']!),
              ),
              child: Row(
                children: [
                  Icon(Icons.flash_on, color: colors['warning'], size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Multiple Rounds Simultaneous Impact',
                            style: TextStyle(color: colors['warning'], fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 4),
                        Text('إطلاق عدة حشوات بفواصل زمنية دقيقة لتسقط جميعها على الهدف في نفس اللحظة. تزيد القوة التدميرية 300%.',
                            style: TextStyle(color: colors['text']?.withOpacity(0.8), fontSize: 11)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

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
                  Text('بيانات الهدف', 
                      style: TextStyle(color: colors['primary'], fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      dropdownColor: colors['surface'],
                      value: _selectedWeapon,
                      style: TextStyle(color: colors['text'], fontSize: 15),
                      items: const [
                        DropdownMenuItem(value: 'm109a6', child: Text('M109A6 Paladin 155mm')),
                        DropdownMenuItem(value: 'm198', child: Text('M198 155mm')),
                        DropdownMenuItem(value: 'mortar120', child: Text('هاون 120mm')),
                        DropdownMenuItem(value: 'mortar81', child: Text('هاون 81mm')),
                        DropdownMenuItem(value: 'mortar60', child: Text('هاون 60mm')),
                      ],
                      onChanged: (v) { if (v != null) setState(() => _selectedWeapon = v); },
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: TextEditingController(text: _targetRange),
                    onChanged: (v) => _targetRange = v,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: colors['text']),
                    decoration: InputDecoration(
                      labelText: 'مسافة الهدف (متر)',
                      labelStyle: TextStyle(color: colors['text']?.withOpacity(0.7)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('عدد الحشوات المتزامنة', 
                      style: TextStyle(color: colors['text'], fontSize: 14)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [2, 3, 4, 5].map((n) => ChoiceChip(
                      label: Text('$n حشوات'),
                      selected: _numCharges == n,
                      selectedColor: colors['primary'],
                      backgroundColor: colors['surfaceLight'],
                      labelStyle: TextStyle(
                        color: _numCharges == n ? Colors.black : colors['text'],
                        fontWeight: FontWeight.bold,
                      ),
                      onSelected: (s) { if (s) setState(() => _numCharges = n); },
                    )).toList(),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _isCalculating ? null : _calculateMrsi,
                    icon: _isCalculating 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.calculate),
                    label: Text(_isCalculating ? 'جاري الحساب...' : 'حساب خطة MRSI'),
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
            const SizedBox(height: 20),

            // النتائج
            if (_mrsiResults.isNotEmpty) ...[
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('خطة الإطلاق المتزامن', 
                            style: TextStyle(color: colors['primary'], fontSize: 16, fontWeight: FontWeight.bold)),
                        IconButton(
                          icon: Icon(Icons.save, color: colors['primary']),
                          onPressed: _saveMrsiPlan,
                          tooltip: 'حفظ الخطة',
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: colors['danger']!.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: colors['danger']!),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.timer, color: colors['danger']),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'جميع القذائف تسقط في نفس اللحظة بعد ${_mrsiResults.first['tof'].toStringAsFixed(1)} ثانية',
                              style: TextStyle(color: colors['danger'], fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    ..._mrsiResults.map((r) => _buildMrsiRow(r, colors)),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // جدول زمني بصري
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colors['surface'],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('الجدول الزمني للإطلاق', 
                        style: TextStyle(color: colors['primary'], fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    ..._mrsiResults.map((r) => _buildTimelineRow(r, colors)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMrsiRow(Map<String, dynamic> r, Map<String, Color> colors) {
    final charge = r['charge'] as int;
    final tof = r['tof'] as double;
    final delay = r['launchDelay'] as double;
    final elevation = r['elevation'] as double;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors['bg'],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors['border']!),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colors['primary'],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text('$charge', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('الحشوة $charge', style: TextStyle(color: colors['text'], fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _buildMiniInfo('ToF', '${tof.toStringAsFixed(1)} ث', colors),
                    const SizedBox(width: 8),
                    _buildMiniInfo('ارتفاع', '${elevation.toStringAsFixed(0)} مل', colors),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: delay == 0 ? colors['danger']!.withOpacity(0.2) : colors['primary']!.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Text(delay == 0 ? 'الأولى' : 'تأخير', 
                    style: TextStyle(color: delay == 0 ? colors['danger'] : colors['primary'], fontSize: 10, fontWeight: FontWeight.bold)),
                Text('+${delay.toStringAsFixed(1)} ث', 
                    style: TextStyle(color: colors['text'], fontSize: 13, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniInfo(String label, String value, Map<String, Color> colors) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: colors['surfaceLight'],
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          children: [
            Text(label, style: TextStyle(color: colors['text']?.withOpacity(0.6), fontSize: 10)),
            Text(value, style: TextStyle(color: colors['text'], fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineRow(Map<String, dynamic> r, Map<String, Color> colors) {
    final charge = r['charge'] as int;
    final delay = r['launchDelay'] as double;
    final maxDelay = _mrsiResults.last['launchDelay'] as double;
    final progress = maxDelay > 0 ? delay / maxDelay : 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text('ح$charge', style: TextStyle(color: colors['text'], fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(width: 8),
          Expanded(
            child: Stack(
              children: [
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: colors['surfaceLight'],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                Container(
                  height: 8,
                  width: MediaQuery.of(context).size.width * 0.55 * progress,
                  decoration: BoxDecoration(
                    color: colors['primary'],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text('+${delay.toStringAsFixed(1)}ث', 
              style: TextStyle(color: colors['primary'], fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}