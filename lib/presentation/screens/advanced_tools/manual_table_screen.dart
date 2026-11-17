import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../theme/theme_provider.dart';
import 'package:provider/provider.dart';

class ManualTableScreen extends StatefulWidget {
  final String tableKey; // المفتاح الفريد (سلاح_عتاد_دولة)
  final String title;

  const ManualTableScreen({super.key, required this.tableKey, required this.title});

  @override
  State<ManualTableScreen> createState() => _ManualTableScreenState();
}

class _ManualTableScreenState extends State<ManualTableScreen> {
  List<Map<String, TextEditingController>> rows = [];

  @override
  void initState() {
    super.initState();
    _addRow();
  }

  void _addRow() {
    setState(() {
      rows.add({
        'range': TextEditingController(),
        'elevation': TextEditingController(),
        'tof': TextEditingController(),
        'charge': TextEditingController(text: '1'),
      });
    });
  }

  Future<void> _saveTable() async {
    List<Map<String, dynamic>> tableData = [];
    for (var row in rows) {
      if (row['range']!.text.isNotEmpty && row['elevation']!.text.isNotEmpty) {
        tableData.add({
          'rangeMeters': int.parse(row['range']!.text),
          'elevationMils': int.parse(row['elevation']!.text),
          'timeOfFlightSec': double.tryParse(row['tof']!.text) ?? 0.0,
          'charge': int.tryParse(row['charge']!.text) ?? 1,
          'heightMeters': 0,
        });
      }
    }

    if (tableData.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('custom_table_${widget.tableKey}', jsonEncode(tableData));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ الجدول بنجاح'), backgroundColor: Colors.green));
        Navigator.pop(context, true);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء إدخال بيانات صحيحة'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Provider.of<ThemeProvider>(context).colors;

    return Scaffold(
      backgroundColor: colors['bg'],
      appBar: AppBar(
        title: Text('إدخال جدول: ${widget.title}', style: TextStyle(color: colors['text'])),
        backgroundColor: colors['surface'],
        iconTheme: IconThemeData(color: colors['primary']),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                _buildHeader('المدى (م)', colors),
                _buildHeader('الارتفاع (مل)', colors),
                _buildHeader('زمن الطيران (ث)', colors),
                _buildHeader('الحشوة', colors),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: rows.length,
              itemBuilder: (context, index) {
                return Card(
                  color: colors['surface'],
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      children: [
                        _buildField(rows[index]['range']!, colors),
                        _buildField(rows[index]['elevation']!, colors),
                        _buildField(rows[index]['tof']!, colors),
                        _buildField(rows[index]['charge']!, colors),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            color: colors['surface'],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: colors['primary']),
                  onPressed: _addRow, 
                  icon: const Icon(Icons.add, color: Colors.black), 
                  label: const Text('صف جديد', style: TextStyle(color: Colors.black))
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  onPressed: _saveTable, 
                  icon: const Icon(Icons.save, color: Colors.white), 
                  label: const Text('حفظ الجدول', style: TextStyle(color: Colors.white))
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(String text, Map<String, Color> colors) {
    return Expanded(child: Text(text, textAlign: TextAlign.center, style: TextStyle(color: colors['primary'], fontWeight: FontWeight.bold)));
  }

  Widget _buildField(TextEditingController ctrl, Map<String, Color> colors) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          style: TextStyle(color: colors['text'], fontFamily: 'monospace', fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 8),
            filled: true,
            fillColor: colors['bg'],
            border: OutlineInputBorder(borderSide: BorderSide(color: colors['border']!)),
          ),
        ),
      ),
    );
  }
}