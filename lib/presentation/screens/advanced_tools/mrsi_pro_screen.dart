import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../theme/theme_provider.dart';
import '../../../domain/firing_table.dart';

class MrsiProScreen extends StatefulWidget {
  const MrsiProScreen({Key? key}) : super(key: key);
  @override
  State<MrsiProScreen> createState() => _MrsiProScreenState();
}

class _MrsiProScreenState extends State<MrsiProScreen> {
  String _selectedWeapon = 'm109a6';
  final _targetRangeCtrl = TextEditingController();
  int _numCharges = 3;
  List<Map<String, dynamic>> _mrsiResults = [];
  bool _isCalculating = false;
  double _totalImpactTime = 0;

  // ربط معرّف السلاح بمفتاح الجدول
  static const Map<String, String> _weaponTableKey = {
    'm109a6': 'm109_he_usa',
    'm198': 'm109_he_usa',
    'mortar120': 'mortar120_he_usa',
    'mortar120_iran': 'mortar120_he_iran',
    'mortar81': 'mortar81_he_china',
    'mortar60': 'mortar60_he_iran',
  };

  @override
  void initState() {
    super.initState();
    _loadSavedPlans();
  }

  @override
  void dispose() {
    _targetRangeCtrl.dispose();
    super.dispose();
  }

  // ★★ استخراج ToF و الارتفاع من الجدول الحقيقي ★★
  Future<List<Map<String, dynamic>>> _getChargeData(String tableKey, int range) async {
    final table = FiringTables.getTableForWeapon(tableKey);
    if (table.isEmpty) return [];

    final Map<int, Map<String, dynamic>> bestByCharge = {};

    for (final row in table) {
      final charge = row.charge;
      final diff = (row.rangeMeters - range).abs();
      
      if (!bestByCharge.containsKey(charge)) {
        bestByCharge[charge] = {
          'charge': charge,
          'range': row.rangeMeters,
          'tof': row.timeOfFlightSec,
          'elevation': row.elevationMils,
          'diff': diff,
        };
      } else {
        if (diff < bestByCharge[charge]!['diff']) {
          bestByCharge[charge] = {
            'charge': charge,
            'range': row.rangeMeters,
            'tof': row.timeOfFlightSec,
            'elevation': row.elevationMils,
            'diff': diff,
          };
        }
      }
    }

    // استبعاد الحشوات التي لا تغطي المدى المطلوب
    final validCharges = bestByCharge.values.where((c) {
      final chargeRows = table.where((r) => r.charge == c['charge']).toList();
      if (chargeRows.isEmpty) return false;
      final minR = chargeRows.map((r) => r.rangeMeters).reduce((a, b) => a < b ? a : b);
      final maxR = chargeRows.map((r) => r.rangeMeters).reduce((a, b) => a > b ? a : b);
      return range >= minR && range <= maxR;
    }).toList();

    // ترتيب حسب ToF تنازلياً (الأطول أولاً)
    validCharges.sort((a, b) => (b['tof'] as double).compareTo(a['tof'] as double));

    // أخذ العدد المطلوب من الحشوات
    final selected = validCharges.take(_numCharges).toList();

    // حساب فارق زمن الإطلاق
    if (selected.isNotEmpty) {
      final maxTof = (selected.first['tof'] as double);
      _totalImpactTime = maxTof;
      for (var r in selected) {
        r['launchDelay'] = maxTof - (r['tof'] as double);
      }
    }

    // ترتيب حسب رقم الحشوة للعرض
    selected.sort((a, b) => (a['charge'] as int).compareTo(b['charge'] as int));

    return selected;
  }

  Future<void> _calculateMrsi() async {
    final range = int.tryParse(_targetRangeCtrl.text);
    if (range == null || range <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أدخل مسافة الهدف بشكل صحيح'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isCalculating = true);
    await Future.delayed(const Duration(milliseconds: 300));

    final tableKey = _weaponTableKey[_selectedWeapon] ?? 'm109_he_usa';
    final results = await _getChargeData(tableKey, range);

    if (results.isEmpty) {
      if (mounted) {
        setState(() => _isCalculating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ لا توجد حشوات تغطي هذا المدى'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    if (results.length < _numCharges) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ℹ️ تم العثور على ${results.length} حشوة فقط لهذا المدى'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    }

    if (mounted) {
      setState(() {
        _mrsiResults = results;
        _isCalculating = false;
      });
      HapticFeedback.mediumImpact();
    }
  }

  Future<void> _saveMrsiPlan() async {
    if (_mrsiResults.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final plans = prefs.getStringList('mrsi_plans') ?? [];

    final planData = {
      'date': DateTime.now().toIso8601String(),
      'weapon': _selectedWeapon,
      'range': _targetRangeCtrl.text,
      'charges': _mrsiResults.length,
      'results': _mrsiResults,
    };

    plans.insert(0, json.encode(planData));
    if (plans.length > 20) plans.removeLast();

    await prefs.setStringList('mrsi_plans', plans);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ تم حفظ خطة MRSI'), backgroundColor: Colors.green),
      );
    }
  }

  Future<void> _loadSavedPlans() async {
    final prefs = await SharedPreferences.getInstance();
    final plans = prefs.getStringList('mrsi_plans');
    if (plans != null && plans.isNotEmpty) {
      // تحميل آخر خطة تلقائياً
      final lastPlan = json.decode(plans.first) as Map<String, dynamic>;
      if (mounted) {
        setState(() {
          _selectedWeapon = lastPlan['weapon'] ?? _selectedWeapon;
          _targetRangeCtrl.text = lastPlan['range'] ?? '';
          _mrsiResults = List<Map<String, dynamic>>.from(lastPlan['results'] ?? []);
          if (_mrsiResults.isNotEmpty) {
            _totalImpactTime = _mrsiResults.first['tof'] as double;
          }
        });
      }
    }
  }

  void _copyPlan() {
    if (_mrsiResults.isEmpty) return;

    final buffer = StringBuffer();
    buffer.writeln('═══════════════════════════════');
    buffer.writeln('   خطة MRSI - الرمي المتزامن');
    buffer.writeln('═══════════════════════════════');
    buffer.writeln('السلاح: $_selectedWeapon');
    buffer.writeln('مدى الهدف: ${_targetRangeCtrl.text} م');
    buffer.writeln('عدد الحشوات: ${_mrsiResults.length}');
    buffer.writeln('زمن السقوط: ${_totalImpactTime.toStringAsFixed(1)} ث');
    buffer.writeln('───────────────────────────────');

    for (var r in _mrsiResults) {
      final delay = r['launchDelay'] as double;
      buffer.writeln('الحشوة ${r['charge']}:');
      buffer.writeln('  • الارتفاع: ${(r['elevation'] as double).toStringAsFixed(0)} مل');
      buffer.writeln('  • ToF: ${(r['tof'] as double).toStringAsFixed(1)} ث');
      buffer.writeln('  • تأخير الإطلاق: +${delay.toStringAsFixed(1)} ث');
    }

    buffer.writeln('═══════════════════════════════');

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('📋 تم نسخ الخطة'), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Provider.of<ThemeProvider>(context).colors;

    return ListView(
      padding: const EdgeInsets.all(16),
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
                    Text('إطلاق عدة حشوات بفواصل زمنية دقيقة لتسقط جميعها على الهدف في نفس اللحظة.',
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
                    DropdownMenuItem(value: 'mortar120', child: Text('هاون 120mm أمريكي')),
                    DropdownMenuItem(value: 'mortar120_iran', child: Text('هاون 120mm إيراني')),
                    DropdownMenuItem(value: 'mortar81', child: Text('هاون 81mm')),
                    DropdownMenuItem(value: 'mortar60', child: Text('هاون 60mm إيراني')),
                  ],
                  onChanged: (v) { if (v != null) setState(() => _selectedWeapon = v); },
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _targetRangeCtrl,
                keyboardType: TextInputType.number,
                style: TextStyle(color: colors['text']),
                decoration: InputDecoration(
                  labelText: 'مسافة الهدف (متر)',
                  labelStyle: TextStyle(color: colors['text']?.withOpacity(0.7)),
                  hintText: 'مثال: 5000',
                  hintStyle: TextStyle(color: colors['text']?.withOpacity(0.4)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 16),
              Text('عدد الحشوات المتزامنة',
                  style: TextStyle(color: colors['text'], fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              // ★★ حل مشكلة Overflow باستخدام Wrap ★★
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.start,
                children: [2, 3, 4, 5, 6].map((n) => ChoiceChip(
                  label: Text('$n حشوات', style: const TextStyle(fontSize: 13)),
                  selected: _numCharges == n,
                  selectedColor: colors['primary'],
                  backgroundColor: colors['surfaceLight'],
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  labelStyle: TextStyle(
                    color: _numCharges == n ? Colors.black : colors['text'],
                    fontWeight: FontWeight.bold,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: _numCharges == n ? colors['primary']! : colors['border']!,
                      width: 1.5,
                    ),
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
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.copy, color: colors['primary'], size: 20),
                          onPressed: _copyPlan,
                          tooltip: 'نسخ الخطة',
                        ),
                        IconButton(
                          icon: Icon(Icons.save, color: colors['primary'], size: 20),
                          onPressed: _saveMrsiPlan,
                          tooltip: 'حفظ الخطة',
                        ),
                      ],
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
                          'جميع القذائف تسقط في نفس اللحظة بعد ${_totalImpactTime.toStringAsFixed(1)} ثانية',
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

          // الجدول الزمني البصري
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
          const SizedBox(height: 16),

          // تعليمات التنفيذ
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors['warning']!.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: colors['warning']!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.assignment, color: colors['warning']),
                    const SizedBox(width: 8),
                    Text('تعليمات التنفيذ',
                        style: TextStyle(color: colors['warning'], fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                Text('1. ابدأ بإطلاق الحشوة ذات التأخير +0.0 ث (الأولى)',
                    style: TextStyle(color: colors['text'], fontSize: 12)),
                Text('2. انتظر الوقت المحدد لكل حشوة قبل الإطلاق التالي',
                    style: TextStyle(color: colors['text'], fontSize: 12)),
                Text('3. جميع القذائف ستصل للهدف في نفس اللحظة',
                    style: TextStyle(color: colors['text'], fontSize: 12)),
                Text('4. تأكد من سلامة المدفع بعد كل حشوة عالية',
                    style: TextStyle(color: colors['text'], fontSize: 12)),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMrsiRow(Map<String, dynamic> r, Map<String, Color> colors) {
    final charge = r['charge'] as int;
    final tof = (r['tof'] as double);
    final delay = (r['launchDelay'] as double);
    final elevation = (r['elevation'] as double);
    final isLeader = delay == 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isLeader ? colors['primary']!.withOpacity(0.1) : colors['bg'],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isLeader ? colors['primary']! : colors['border']!,
          width: isLeader ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              color: isLeader ? colors['primary'] : colors['surfaceLight'],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text('$charge',
                  style: TextStyle(
                    color: isLeader ? Colors.black : colors['text'],
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  )),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('الحشوة $charge',
                        style: TextStyle(color: colors['text'], fontWeight: FontWeight.bold, fontSize: 14)),
                    if (isLeader) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('الأولى',
                            style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _buildMiniInfo('ToF', '${tof.toStringAsFixed(1)} ث', colors),
                    const SizedBox(width: 6),
                    _buildMiniInfo('ارتفاع', '${elevation.toStringAsFixed(0)} مل', colors),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isLeader ? Colors.red.withOpacity(0.2) : colors['primary']!.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(isLeader ? 'الآن' : 'تأخير',
                    style: TextStyle(
                      color: isLeader ? Colors.red : colors['primary'],
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    )),
                Text('T+${delay.toStringAsFixed(1)} ث',
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
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
        decoration: BoxDecoration(
          color: colors['surfaceLight'],
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          children: [
            Text(label, style: TextStyle(color: colors['text']?.withOpacity(0.6), fontSize: 9)),
            Text(value, style: TextStyle(color: colors['text'], fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineRow(Map<String, dynamic> r, Map<String, Color> colors) {
    final charge = r['charge'] as int;
    final delay = r['launchDelay'] as double;
    final maxDelay = _mrsiResults.map((x) => x['launchDelay'] as double).reduce((a, b) => a > b ? a : b);
    final progress = maxDelay > 0 ? delay / maxDelay : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 35,
            child: Text('ح$charge', style: TextStyle(color: colors['text'], fontWeight: FontWeight.bold, fontSize: 12)),
          ),
          Expanded(
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                Container(
                  height: 10,
                  decoration: BoxDecoration(
                    color: colors['surfaceLight'],
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
                Container(
                  height: 10,
                  width: MediaQuery.of(context).size.width * 0.55 * progress,
                  decoration: BoxDecoration(
                    color: colors['primary'],
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 55,
            child: Text(
              'T+${delay.toStringAsFixed(1)}ث',
              style: TextStyle(color: colors['primary'], fontSize: 11, fontWeight: FontWeight.bold),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}