import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../../theme/theme_provider.dart';
import '../../../domain/firing_table.dart';

class TableManagerScreen extends StatefulWidget {
  const TableManagerScreen({Key? key}) : super(key: key);

  @override
  State<TableManagerScreen> createState() => _TableManagerScreenState();
}

class _TableManagerScreenState extends State<TableManagerScreen> {
  Map<String, List<FiringTableRow>> _allTables = {};

  @override
  void initState() {
    super.initState();
    _loadAllTables();
  }

  Future<void> _loadAllTables() async {
    Map<String, List<FiringTableRow>> tables = Map.from(FiringTables.getAllTables());

    final prefs = await SharedPreferences.getInstance();
    final customKeys = prefs.getKeys().where((k) => k.startsWith('custom_table_'));
    
    for (String key in customKeys) {
      final tableKey = key.replaceFirst('custom_table_', '');
      String? jsonStr = prefs.getString(key);
      if (jsonStr != null) {
        try {
          List<dynamic> list = jsonDecode(jsonStr);
          List<FiringTableRow> rows = list.map((e) => FiringTableRow.fromJson(e)).toList();
          tables[tableKey] = rows; 
        } catch (e) {}
      }
    }

    setState(() {
      _allTables = tables;
    });
  }

  Future<void> _saveTableToPrefs(String tableKey, List<FiringTableRow> rows) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = json.encode(rows.map((e) => e.toJson()).toList());
    await prefs.setString('custom_table_$tableKey', jsonStr);
    FiringTables.updateTable(tableKey, rows);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ التعديلات بنجاح'), backgroundColor: Colors.green),
      );
    }
  }

  void _editTable(String tableKey, List<FiringTableRow> currentRows) async {
    final updatedRows = await Navigator.push<List<FiringTableRow>>(
      context,
      MaterialPageRoute(builder: (_) => EditTableRowsScreen(tableKey: tableKey, initialRows: currentRows)),
    );

    if (updatedRows != null) {
      await _saveTableToPrefs(tableKey, updatedRows);
      _loadAllTables(); 
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Provider.of<ThemeProvider>(context).colors;

    return Scaffold(
      backgroundColor: colors['bg'],
      appBar: AppBar(
        title: const Text('إدارة جداول الرمي'),
        backgroundColor: colors['surface'],
        iconTheme: IconThemeData(color: colors['text'] ?? Colors.white),
      ),
      body: _allTables.isEmpty
          ? Center(child: Text('لا توجد جداول', style: TextStyle(color: colors['text'])))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _allTables.length,
              itemBuilder: (context, index) {
                String key = _allTables.keys.elementAt(index);
                List<FiringTableRow> rows = _allTables[key]!;
                String displayTitle = key.replaceAll('_', ' | ').toUpperCase();

                return Card(
                  color: colors['surface'],
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    side: BorderSide(color: colors['border'] ?? Colors.grey),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: Icon(Icons.table_chart, color: colors['primary'], size: 30),
                    title: Text(displayTitle, style: TextStyle(color: colors['text'], fontWeight: FontWeight.bold)),
                    subtitle: Text('عدد الصفوف: ${rows.length}', style: TextStyle(color: colors['text']?.withOpacity(0.6))),
                    trailing: Icon(Icons.edit, color: colors['warning']),
                    onTap: () => _editTable(key, rows),
                  ),
                );
              },
            ),
    );
  }
}

class EditTableRowsScreen extends StatefulWidget {
  final String tableKey;
  final List<FiringTableRow> initialRows;

  const EditTableRowsScreen({Key? key, required this.tableKey, required this.initialRows}) : super(key: key);

  @override
  State<EditTableRowsScreen> createState() => _EditTableRowsScreenState();
}

class _EditTableRowsScreenState extends State<EditTableRowsScreen> {
  late List<FiringTableRow> _rows;

  @override
  void initState() {
    super.initState();
    _rows = List.from(widget.initialRows);
  }

  void _addRow() {
    _showRowDialog(null, (newRow) {
      setState(() => _rows.add(newRow));
    });
  }

  void _editRow(int index) {
    _showRowDialog(_rows[index], (updatedRow) {
      setState(() => _rows[index] = updatedRow);
    });
  }

  void _deleteRow(int index) {
    setState(() => _rows.removeAt(index));
  }

  void _showRowDialog(FiringTableRow? row, Function(FiringTableRow) onSave) {
    final chargeCtrl = TextEditingController(text: row?.charge.toString() ?? '');
    final rangeCtrl = TextEditingController(text: row?.rangeMeters.toString() ?? '');
    final elCtrl = TextEditingController(text: row?.elevationMils.toString() ?? '');
    final tofCtrl = TextEditingController(text: row?.timeOfFlightSec.toString() ?? '');
    final heightCtrl = TextEditingController(text: row?.heightMeters.toString() ?? '');

    showDialog(
      context: context,
      builder: (context) {
        final colors = Provider.of<ThemeProvider>(context, listen: false).colors;
        return AlertDialog(
          backgroundColor: colors['surface'],
          title: Text(row == null ? 'إضافة صف جديد' : 'تعديل الصف', style: TextStyle(color: colors['text'])),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: chargeCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'رقم الحشوة (Charge)')),
                TextField(controller: rangeCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'المدى بالأمتار (Range)')),
                TextField(controller: elCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'زاوية الارتفاع (Mils)')),
                TextField(controller: tofCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'زمن الطيران (ثانية)')),
                TextField(controller: heightCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'أقصى ارتفاع (متر)')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء', style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              onPressed: () {
                if (chargeCtrl.text.isNotEmpty && rangeCtrl.text.isNotEmpty) {
                  onSave(FiringTableRow(
                    charge: int.tryParse(chargeCtrl.text) ?? 0,
                    rangeMeters: int.tryParse(rangeCtrl.text) ?? 0,
                    elevationMils: int.tryParse(elCtrl.text) ?? 0,
                    timeOfFlightSec: double.tryParse(tofCtrl.text) ?? 0.0,
                    heightMeters: int.tryParse(heightCtrl.text) ?? 0,
                  ));
                  Navigator.pop(context);
                }
              },
              child: const Text('حفظ'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Provider.of<ThemeProvider>(context).colors;
    _rows.sort((a, b) => a.rangeMeters.compareTo(b.rangeMeters));

    return Scaffold(
      backgroundColor: colors['bg'],
      appBar: AppBar(
        title: Text(widget.tableKey.replaceAll('_', ' | ').toUpperCase()),
        backgroundColor: colors['surface'],
        iconTheme: IconThemeData(color: colors['text'] ?? Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.save, color: Colors.greenAccent),
            onPressed: () => Navigator.pop(context, _rows),
            tooltip: 'حفظ وإغلاق',
          ),
        ],
      ),
      body: _rows.isEmpty
          ? Center(child: Text('الجدول فارغ. اضغط + للإضافة', style: TextStyle(color: colors['text'])))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _rows.length,
              itemBuilder: (context, index) {
                final r = _rows[index];
                return Card(
                  color: colors['surface'],
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(
                    side: BorderSide(color: colors['border'] ?? Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListTile(
                    title: Text('حشوة ${r.charge} | مدى ${r.rangeMeters} م', style: TextStyle(color: colors['text'], fontWeight: FontWeight.bold)),
                    subtitle: Text('زاوية: ${r.elevationMils} مل | TOF: ${r.timeOfFlightSec} ث', style: TextStyle(color: colors['text']?.withOpacity(0.7))),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(icon: const Icon(Icons.edit, color: Colors.blueAccent), onPressed: () => _editRow(index)),
                        IconButton(icon: const Icon(Icons.delete, color: Colors.redAccent), onPressed: () => _deleteRow(index)),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addRow,
        backgroundColor: colors['primary'],
        foregroundColor: Colors.black,
        child: const Icon(Icons.add),
      ),
    );
  }
}