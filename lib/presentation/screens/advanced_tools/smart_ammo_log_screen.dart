import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:convert';
import '../../../theme/theme_provider.dart';

class SmartAmmoLogScreen extends StatefulWidget {
  const SmartAmmoLogScreen({Key? key}) : super(key: key);
  @override
  State<SmartAmmoLogScreen> createState() => _SmartAmmoLogScreenState();
}

class _SmartAmmoLogScreenState extends State<SmartAmmoLogScreen> {
  List<Map<String, dynamic>> _fireMissions = [];
  Map<String, int> _ammoConsumption = {};
  Map<String, int> _targetHits = {};
  double _efficiency = 0.0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final missionsJson = prefs.getString('fire_missions');
    
    if (missionsJson != null) {
      final List<dynamic> missionsList = json.decode(missionsJson);
      setState(() {
        _fireMissions = missionsList.cast<Map<String, dynamic>>();
        _calculateStats();
      });
    }
  }

  void _calculateStats() {
    _ammoConsumption = {};
    _targetHits = {};
    
    for (var mission in _fireMissions) {
      final weapon = mission['weaponName'] ?? 'غير محدد';
      _ammoConsumption[weapon] = (_ammoConsumption[weapon] ?? 0) + 1;
      _targetHits[weapon] = (_targetHits[weapon] ?? 0) + 1;
    }
    
    if (_fireMissions.isNotEmpty) {
      _efficiency = (_targetHits.values.fold(0, (a, b) => a + b) / 
                    _ammoConsumption.values.fold(0, (a, b) => a + b)) * 100;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Provider.of<ThemeProvider>(context).colors;

    return Scaffold(
      backgroundColor: colors['bg'],
      appBar: AppBar(
        title: const Text('سجل الاستهلاك الذكي'),
        backgroundColor: colors['surface'],
      ),
      body: _fireMissions.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.analytics, size: 64, color: colors['text']?.withOpacity(0.5)),
                  const SizedBox(height: 16),
                  Text('لا توجد بيانات', 
                      style: TextStyle(color: colors['text']?.withOpacity(0.7), fontSize: 16)),
                  const SizedBox(height: 8),
                  Text('ابدأ بحفظ الرمايات لعرض الإحصائيات', 
                      style: TextStyle(color: colors['text']?.withOpacity(0.5), fontSize: 12)),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // بطاقة الكفاءة
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colors['surface'],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colors['primary']!),
                    ),
                    child: Column(
                      children: [
                        Text('كفاءة الرمي', 
                            style: TextStyle(color: colors['primary'], fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text('${_efficiency.toStringAsFixed(1)}%', 
                            style: TextStyle(color: colors['warning'], fontSize: 36, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('(${_targetHits.values.fold(0, (a, b) => a + b)} هدف / ${_ammoConsumption.values.fold(0, (a, b) => a + b)} طلقة)', 
                            style: TextStyle(color: colors['text']?.withOpacity(0.7), fontSize: 12)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // رسم بياني للاستهلاك
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colors['surface'],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('استهلاك الذخيرة حسب السلاح', 
                            style: TextStyle(color: colors['primary'], fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 200,
                          child: BarChart(
                            BarChartData(
                              alignment: BarChartAlignment.spaceAround,
                              maxY: _ammoConsumption.values.isEmpty ? 10 : 
                                  _ammoConsumption.values.reduce((a, b) => a > b ? a : b) * 1.2,
                              barTouchData: BarTouchData(
                                touchTooltipData: BarTouchTooltipData(
                                  tooltipBgColor: colors['surface'],
                                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                    return BarTooltipItem(
                                      rod.toY.toStringAsFixed(0),
                                      TextStyle(color: colors['text'], fontWeight: FontWeight.bold),
                                    );
                                  },
                                ),
                              ),
                              titlesData: FlTitlesData(
                                show: true,
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    getTitlesWidget: (value, meta) {
                                      final keys = _ammoConsumption.keys.toList();
                                      if (value.toInt() < keys.length) {
                                        return Padding(
                                          padding: const EdgeInsets.only(top: 8),
                                          child: Text(
                                            keys[value.toInt()].split(' ').first,
                                            style: TextStyle(color: colors['text'], fontSize: 10),
                                          ),
                                        );
                                      }
                                      return const SizedBox.shrink();
                                    },
                                  ),
                                ),
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    getTitlesWidget: (value, meta) {
                                      return Text(
                                        value.toInt().toString(),
                                        style: TextStyle(color: colors['text']?.withOpacity(0.7), fontSize: 10),
                                      );
                                    },
                                  ),
                                ),
                                topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              ),
                              borderData: FlBorderData(show: false),
                              barGroups: _ammoConsumption.entries.toList().asMap().entries.map((entry) {
                                return BarChartGroupData(
                                  x: entry.key,
                                  barRods: [
                                    BarChartRodData(
                                      toY: entry.value.value.toDouble(),
                                      color: colors['primary'],
                                      width: 16,
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(4),
                                        topRight: Radius.circular(4),
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // قائمة التفاصيل
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colors['surface'],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('تفاصيل الاستهلاك', 
                            style: TextStyle(color: colors['primary'], fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        ..._ammoConsumption.entries.map((entry) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(entry.key, 
                                    style: TextStyle(color: colors['text'], fontSize: 14),
                                    overflow: TextOverflow.ellipsis),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: colors['primary']!.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text('${entry.value} طلقة', 
                                    style: TextStyle(color: colors['primary'], fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        )),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}