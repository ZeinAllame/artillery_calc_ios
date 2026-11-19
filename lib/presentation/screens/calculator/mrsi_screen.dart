import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../theme/theme_provider.dart';
import '../../../domain/firing_table.dart';
import '../../../models/models.dart';

class MrsiScreen extends StatefulWidget {
  final double baseDistance;
  final String weaponId;
  final ShellType shellType;
  final ShellCountry country;

  const MrsiScreen({
    Key? key, 
    required this.baseDistance, 
    required this.weaponId,
    required this.shellType,
    required this.country,
  }) : super(key: key);

  @override
  State<MrsiScreen> createState() => _MrsiScreenState();
}

class _MrsiScreenState extends State<MrsiScreen> {
  List<Map<String, dynamic>> _mrsiData = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _calculateMRSI();
  }

  void _calculateMRSI() {
    final exactKey = "${widget.weaponId}_${widget.shellType.name}_${widget.country.name}";
    final fallbackKey = "${widget.weaponId}_${widget.shellType.name}";
    
    var rows = FiringTables.findRowsForRange(exactKey, widget.baseDistance.round());
    if (rows.isEmpty) {
      rows = FiringTables.findRowsForRange(fallbackKey, widget.baseDistance.round());
    }

    if (rows.isEmpty) {
      setState(() { _isLoading = false; });
      return;
    }

    // ترتيب حسب زمن الطيران تنازلياً (أطول زمن يُطلق أولاً)
    rows.sort((a, b) => b.timeOfFlightSec.compareTo(a.timeOfFlightSec));

    final maxTof = rows.first.timeOfFlightSec;
    final List<Map<String, dynamic>> results = [];

    for (int i = 0; i < rows.length; i++) {
      final row = rows[i];
      final delay = maxTof - row.timeOfFlightSec;
      results.add({
        'charge': row.charge,
        'elevation': row.elevationMils,
        'tof': row.timeOfFlightSec,
        'delay': delay,
        'isFirst': i == 0,
      });
    }

    setState(() {
      _mrsiData = results;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Provider.of<ThemeProvider>(context).colors;

    return Scaffold(
      backgroundColor: colors['bg'],
      appBar: AppBar(
        title: const Text('حساب الرمي المتزامن (MRSI)'), 
        backgroundColor: colors['surface'],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _mrsiData.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('لا توجد حشوات كافية في الجدول لهذا المدى لإجراء MRSI', 
                    style: TextStyle(color: colors['text']), textAlign: TextAlign.center))
            )
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: colors['surface'], borderRadius: BorderRadius.circular(8)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('المدى الأساسي: ${widget.baseDistance.toStringAsFixed(0)} م', 
                            style: TextStyle(color: colors['primary'], fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('عدد الحلول المتاحة: ${_mrsiData.length} حشوات مختلفة', 
                            style: TextStyle(color: colors['text'])),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _mrsiData.length,
                      itemBuilder: (context, index) {
                        final data = _mrsiData[index];
                        return Card(
                          color: data['isFirst'] ? colors['primary']!.withOpacity(0.15) : colors['surface'],
                          elevation: data['isFirst'] ? 4 : 1,
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: data['isFirst'] ? colors['primary'] : colors['surfaceLight'],
                              child: Text('${index + 1}', style: TextStyle(color: data['isFirst'] ? Colors.black : colors['text'], fontWeight: FontWeight.bold)),
                            ),
                            title: Text('الحشوة ${data['charge']}', 
                                style: TextStyle(color: colors['text'], fontWeight: FontWeight.bold)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('الارتفاع: ${data['elevation'].toStringAsFixed(1)} مل | زمن الطيران: ${data['tof'].toStringAsFixed(1)} ث', 
                                    style: TextStyle(color: colors['text']?.withOpacity(0.8))),
                                if (!data['isFirst'])
                                  Text('⏱ تأخير الإطلاق: ${data['delay'].toStringAsFixed(1)} ثانية بعد الطلقة الأولى', 
                                      style: TextStyle(color: colors['warning'], fontWeight: FontWeight.bold)),
                                if (data['isFirst'])
                                  Text('🚀 هذه هي الطلقة الأولى (تطلق فوراً)', 
                                      style: TextStyle(color: colors['primary'], fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}