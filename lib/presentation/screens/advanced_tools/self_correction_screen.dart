import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../../../theme/theme_provider.dart';

class SelfCorrectionScreen extends StatefulWidget {
  const SelfCorrectionScreen({Key? key}) : super(key: key);
  @override
  State<SelfCorrectionScreen> createState() => _SelfCorrectionScreenState();
}

class _SelfCorrectionScreenState extends State<SelfCorrectionScreen> {
  List<Map<String, dynamic>> _corrections = [];
  double _avgRangeError = 0.0;
  double _avgDirError = 0.0;
  double _recommendedRangeCorr = 0.0;
  double _recommendedDirCorr = 0.0;
  int _totalShots = 0;
  int _accurateShots = 0;
  double _accuracyRate = 0.0;

  final _rangeErrorCtrl = TextEditingController();
  final _dirErrorCtrl = TextEditingController();
  final _shotDescCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCorrections();
  }

  @override
  void dispose() {
    _rangeErrorCtrl.dispose();
    _dirErrorCtrl.dispose();
    _shotDescCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCorrections() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('self_corrections');
    if (data != null && mounted) {
      setState(() {
        _corrections = List<Map<String, dynamic>>.from(json.decode(data));
        _calculateStats();
      });
    }
  }

  void _calculateStats() {
    if (_corrections.isEmpty) {
      _avgRangeError = 0;
      _avgDirError = 0;
      _recommendedRangeCorr = 0;
      _recommendedDirCorr = 0;
      _totalShots = 0;
      _accurateShots = 0;
      _accuracyRate = 0;
      return;
    }

    double rangeSum = 0;
    double dirSum = 0;
    _accurateShots = 0;

    for (var c in _corrections) {
      final rErr = (c['rangeError'] as num).toDouble();
      final dErr = (c['dirError'] as num).toDouble();
      rangeSum += rErr.abs();
      dirSum += dErr.abs();
      if (rErr.abs() <= 50 && dErr.abs() <= 50) _accurateShots++;
    }

    _totalShots = _corrections.length;
    _avgRangeError = rangeSum / _totalShots;
    _avgDirError = dirSum / _totalShots;

    double rangeCorrectionSum = 0;
    double dirCorrectionSum = 0;
    int corrCount = 0;

    for (var c in _corrections) {
      if (c.containsKey('appliedCorr') && c['appliedCorr'] == true) {
        rangeCorrectionSum += (c['appliedRangeCorr'] as num).toDouble();
        dirCorrectionSum += (c['appliedDirCorr'] as num).toDouble();
        corrCount++;
      } else {
        rangeCorrectionSum -= (c['rangeError'] as num).toDouble();
        dirCorrectionSum -= (c['dirError'] as num).toDouble();
        corrCount++;
      }
    }

    if (corrCount > 0) {
      _recommendedRangeCorr = rangeCorrectionSum / corrCount;
      _recommendedDirCorr = dirCorrectionSum / corrCount;
    }

    _accuracyRate = (_totalShots > 0) ? (_accurateShots / _totalShots) * 100 : 0;
  }

  Future<void> _addCorrection() async {
    final rangeErr = double.tryParse(_rangeErrorCtrl.text) ?? 0;
    final dirErr = double.tryParse(_dirErrorCtrl.text) ?? 0;

    if (_rangeErrorCtrl.text.isEmpty && _dirErrorCtrl.text.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أدخل قيمة خطأ واحدة على الأقل'), backgroundColor: Colors.red),
      );
      return;
    }

    final newCorrection = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'date': DateTime.now().toIso8601String(),
      'rangeError': rangeErr,
      'dirError': dirErr,
      'description': _shotDescCtrl.text,
      'appliedCorr': false,
    };

    if (mounted) {
      setState(() {
        _corrections.insert(0, newCorrection);
      });
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('self_corrections', json.encode(_corrections));

    _calculateStats();
    _rangeErrorCtrl.clear();
    _dirErrorCtrl.clear();
    _shotDescCtrl.clear();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ خطأ الرمية'), backgroundColor: Colors.green),
      );
    }
  }

  Future<void> _clearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد المسح'),
        content: const Text('سيتم مسح جميع بيانات التصحيح. هل أنت متأكد؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('مسح', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('self_corrections');
      setState(() {
        _corrections = [];
        _calculateStats();
      });
    }
  }

  String _describeRangeError(double err) {
    if (err.abs() <= 25) return 'دقيق جداً';
    if (err > 0) return err > 100 ? 'قصير جداً' : 'قصير';
    return err < -100 ? 'بعيد جداً' : 'بعيد';
  }

  String _describeDirError(double err) {
    if (err.abs() <= 25) return 'دقيق جداً';
    if (err > 0) return err > 100 ? 'يمين كثيراً' : 'يمين';
    return err < -100 ? 'يسار كثيراً' : 'يسار';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Provider.of<ThemeProvider>(context).colors;

    return Scaffold(
      backgroundColor: colors['bg'],
      appBar: AppBar(
        title: const Text('التصحيح الذاتي AI'),
        backgroundColor: colors['surface'],
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_forever, color: Colors.red),
            onPressed: _clearAll,
            tooltip: 'مسح كل البيانات',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // بطاقة الذكاء
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [colors['primary']!.withOpacity(0.2), colors['primary']!.withOpacity(0.05)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors['primary']!, width: 2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.psychology, color: colors['primary'], size: 28),
                      const SizedBox(width: 8),
                      Text('توصيات الذكاء الاصطناعي', 
                          style: TextStyle(color: colors['primary'], fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_totalShots >= 3) ...[
                    _buildAiRecommendation(
                      'تصحيح المدى المقترح',
                      '${_recommendedRangeCorr >= 0 ? "+" : ""}${_recommendedRangeCorr.toStringAsFixed(0)} متر',
                      _recommendedRangeCorr > 0 ? 'أضف للمسافة' : 'اطرح من المسافة',
                      colors,
                    ),
                    const SizedBox(height: 8),
                    _buildAiRecommendation(
                      'تصحيح الاتجاه المقترح',
                      '${_recommendedDirCorr >= 0 ? "+" : ""}${_recommendedDirCorr.toStringAsFixed(0)} مل',
                      _recommendedDirCorr > 0 ? 'صحح لليسار' : 'صحح لليمين',
                      colors,
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colors['warning']!.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: colors['warning']),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'نحتاج 3 رمايات على الأقل لتوليد توصيات ذكية. لديك حالياً $_totalShots رمية.',
                              style: TextStyle(color: colors['text'], fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // إحصائيات
            Row(
              children: [
                Expanded(child: _buildStatCard('إجمالي الرميات', '$_totalShots', Icons.fitness_center, colors)),
                const SizedBox(width: 8),
                // ★ تم استخدام center_focus_strong كبديل مضمون لأيقونة الهدف
                Expanded(child: _buildStatCard('دقة الرمي', '${_accuracyRate.toStringAsFixed(0)}%', Icons.center_focus_strong, colors)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _buildStatCard('متوسط خطأ المدى', '${_avgRangeError.toStringAsFixed(0)} م', Icons.linear_scale, colors)),
                const SizedBox(width: 8),
                Expanded(child: _buildStatCard('متوسط خطأ الاتجاه', '${_avgDirError.toStringAsFixed(0)} مل', Icons.explore, colors)),
              ],
            ),
            const SizedBox(height: 20),

            // إدخال خطأ جديد
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
                  Text('تسجيل خطأ رمية جديدة', 
                      style: TextStyle(color: colors['primary'], fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _rangeErrorCtrl,
                    keyboardType: const TextInputType.numberWithOptions(signed: true),
                    style: TextStyle(color: colors['text']),
                    decoration: InputDecoration(
                      labelText: 'خطأ المدى (متر) - موجب=قصير، سالب=بعيد',
                      labelStyle: TextStyle(color: colors['text']?.withOpacity(0.7)),
                      hintText: 'مثال: 50 أو -30',
                      hintStyle: TextStyle(color: colors['text']?.withOpacity(0.4)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _dirErrorCtrl,
                    keyboardType: const TextInputType.numberWithOptions(signed: true),
                    style: TextStyle(color: colors['text']),
                    decoration: InputDecoration(
                      labelText: 'خطأ الاتجاه (ملة) - موجب=يمين، سالب=يسار',
                      labelStyle: TextStyle(color: colors['text']?.withOpacity(0.7)),
                      hintText: 'مثال: 20 أو -15',
                      hintStyle: TextStyle(color: colors['text']?.withOpacity(0.4)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _shotDescCtrl,
                    style: TextStyle(color: colors['text']),
                    decoration: InputDecoration(
                      labelText: 'وصف (اختياري)',
                      labelStyle: TextStyle(color: colors['text']?.withOpacity(0.7)),
                      hintText: 'مثال: رمية تجريبية، هدف متحرك...',
                      hintStyle: TextStyle(color: colors['text']?.withOpacity(0.4)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _addCorrection,
                    icon: const Icon(Icons.add_chart),
                    label: const Text('حفظ خطأ الرمية'),
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

            // قائمة الرميات السابقة
            if (_corrections.isNotEmpty) ...[
              Text('سجل الرميات السابقة', 
                  style: TextStyle(color: colors['primary'], fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ..._corrections.take(10).map((c) => _buildCorrectionCard(c, colors)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAiRecommendation(String title, String value, String action, Map<String, Color> colors) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors['bg'],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors['primary']!.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.auto_awesome, color: colors['primary'], size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: colors['text']?.withOpacity(0.7), fontSize: 12)),
                const SizedBox(height: 4),
                Text(value, style: TextStyle(color: colors['primary'], fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(action, style: TextStyle(color: colors['warning'], fontSize: 11, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Map<String, Color> colors) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors['surface'],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors['border']!),
      ),
      child: Column(
        children: [
          Icon(icon, color: colors['primary'], size: 24),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(color: colors['text'], fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: colors['text']?.withOpacity(0.6), fontSize: 10), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildCorrectionCard(Map<String, dynamic> c, Map<String, Color> colors) {
    final rangeErr = (c['rangeError'] as num).toDouble();
    final dirErr = (c['dirError'] as num).toDouble();
    final date = DateTime.parse(c['date']);
    final isAccurate = rangeErr.abs() <= 50 && dirErr.abs() <= 50;

    return Card(
      color: colors['surface'],
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: isAccurate ? Colors.green : colors['border']!),
      ),
      child: ListTile(
        leading: Icon(
          isAccurate ? Icons.check_circle : Icons.error_outline,
          color: isAccurate ? Colors.green : Colors.orange,
        ),
        title: Text(
          DateFormat('yyyy-MM-dd HH:mm').format(date),
          style: TextStyle(color: colors['text'], fontWeight: FontWeight.bold, fontSize: 13),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('المدى: ${_describeRangeError(rangeErr)} (${rangeErr >= 0 ? "+" : ""}${rangeErr.toStringAsFixed(0)}م)',
                style: TextStyle(color: colors['text']?.withOpacity(0.8), fontSize: 12)),
            Text('الاتجاه: ${_describeDirError(dirErr)} (${dirErr >= 0 ? "+" : ""}${dirErr.toStringAsFixed(0)}مل)',
                style: TextStyle(color: colors['text']?.withOpacity(0.8), fontSize: 12)),
            if (c['description'] != null && c['description'].toString().isNotEmpty)
              Text('📝 ${c['description']}', style: TextStyle(color: colors['text']?.withOpacity(0.6), fontSize: 11)),
          ],
        ),
      ),
    );
  }
}