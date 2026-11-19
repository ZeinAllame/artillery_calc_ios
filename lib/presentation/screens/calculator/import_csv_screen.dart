import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../theme/theme_provider.dart';
import '../../../domain/firing_table.dart';
import '../../../services/data_service.dart';
import '../../../models/models.dart';

class CsvImportResult {
  final String tableKey;
  final List<FiringTableRow> rows;
  CsvImportResult(this.tableKey, this.rows);
}

class ImportCsvScreen extends StatefulWidget {
  const ImportCsvScreen({super.key});
  @override
  State<ImportCsvScreen> createState() => _ImportCsvScreenState();
}

class _ImportCsvScreenState extends State<ImportCsvScreen> {
  String _weaponId = '';
  ShellType _shellType = ShellType.he;
  ShellCountry _country = ShellCountry.usa;
  final TextEditingController _csvCtrl = TextEditingController();

  List<FiringTableRow> _parsed = [];
  List<String> _issues = [];
  bool _analyzed = false;

  @override
  void initState() {
    super.initState();
    if (DataService.allWeapons.isNotEmpty) _weaponId = DataService.allWeapons.first.id;
  }

  @override
  void dispose() {
    _csvCtrl.dispose();
    super.dispose();
  }

  String _normalize(String s) {
    const ar = '٠١٢٣٤٥٦٧٨٩';
    for (int i = 0; i < 10; i++) {
      s = s.replaceAll(ar[i], '$i');
    }
    return s.replaceAll('٫', '.').replaceAll('،', ',');
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) {
      setState(() => _csvCtrl.text = data!.text!);
    }
  }

  void _analyze() {
    final rows = <FiringTableRow>[];
    final issues = <String>[];
    final seen = <String>{};
    final lines = _normalize(_csvCtrl.text).split('\n');
    int lineNo = 0;
    bool firstData = true;

    for (final raw in lines) {
      lineNo++;
      final line = raw.trim();
      if (line.isEmpty || line.startsWith('#')) continue;

      final sep = line.contains('\t') ? '\t' : (line.contains(';') ? ';' : ',');
      final cells =
          line.split(sep).map((c) => c.trim()).where((c) => c.isNotEmpty).toList();
      if (cells.isEmpty) continue;

      if (firstData && int.tryParse(cells[0]) == null) {
        firstData = false;
        continue;
      }
      firstData = false;

      if (cells.length < 4) {
        issues.add('سطر $lineNo: أعمدة ناقصة (المطلوب: حشوة,مدى,ارتفاع,زمن)');
        continue;
      }
      final charge = int.tryParse(cells[0]);
      final range = int.tryParse(cells[1]);
      final el = double.tryParse(cells[2]);
      final tof = double.tryParse(cells[3]);
      final height = cells.length > 4 ? (int.tryParse(cells[4]) ?? 0) : 0;

      if (charge == null ||
          charge < 0 ||
          range == null ||
          range <= 0 ||
          el == null ||
          el <= 0 ||
          tof == null ||
          tof < 0) {
        issues.add('سطر $lineNo: قيم غير صالحة → $line');
        continue;
      }
      final key = '$charge:$range';
      if (seen.contains(key)) {
        issues.add('سطر $lineNo: مدى مكرر (حشوة $charge / $range م) — تم تجاهله');
        continue;
      }
      seen.add(key);
      rows.add(FiringTableRow(
        charge: charge,
        rangeMeters: range,
        elevationMils: el,
        timeOfFlightSec: tof,
        heightMeters: height,
      ));
    }

    rows.sort((a, b) {
      final c = a.charge.compareTo(b.charge);
      return c != 0 ? c : a.rangeMeters.compareTo(b.rangeMeters);
    });
    setState(() {
      _parsed = rows;
      _issues = issues;
      _analyzed = true;
    });
  }

  void _save() {
    if (_parsed.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لا توجد صفوف صالحة للحفظ'), backgroundColor: Colors.red));
      return;
    }
    final key = '${_weaponId}_${_shellType.name}_${_country.name}';
    Navigator.pop(context, CsvImportResult(key, _parsed));
  }

  @override
  Widget build(BuildContext context) {
    final colors = Provider.of<ThemeProvider>(context).colors;
    final counts = <int, int>{};
    for (final r in _parsed) {
      counts[r.charge] = (counts[r.charge] ?? 0) + 1;
    }

    return Scaffold(
      backgroundColor: colors['bg'],
      appBar: AppBar(
        title: const Text('استيراد جدول CSV'),
        backgroundColor: colors['surface'],
        iconTheme: IconThemeData(color: colors['text'] ?? Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: colors['surface'],
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(children: [
                DropdownButton<String>(
                  isExpanded: true,
                  value: _weaponId.isEmpty ? null : _weaponId,
                  dropdownColor: colors['surface'],
                  hint: Text('السلاح', style: TextStyle(color: colors['text'])),
                  items: DataService.allWeapons
                      .map((w) => DropdownMenuItem(
                          value: w.id,
                          child: Text(w.nameAr,
                              style: TextStyle(color: colors['text'], fontSize: 13))))
                      .toList(),
                  onChanged: (v) => setState(() => _weaponId = v ?? _weaponId),
                ),
                DropdownButton<ShellType>(
                  isExpanded: true,
                  value: _shellType,
                  dropdownColor: colors['surface'],
                  items: ShellType.values
                      .map((s) => DropdownMenuItem(
                          value: s,
                          child:
                              Text(s.name.toUpperCase(), style: TextStyle(color: colors['text']))))
                      .toList(),
                  onChanged: (v) => setState(() => _shellType = v ?? _shellType),
                ),
                DropdownButton<ShellCountry>(
                  isExpanded: true,
                  value: _country,
                  dropdownColor: colors['surface'],
                  items: ShellCountry.values
                      .map((c) => DropdownMenuItem(
                          value: c,
                          child:
                              Text(c.name.toUpperCase(), style: TextStyle(color: colors['text']))))
                      .toList(),
                  onChanged: (v) => setState(() => _country = v ?? _country),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          Text(
              'الصيغة: حشوة , مدى(م) , ارتفاع(مل) , زمن(ث) [, أقصى ارتفاع(م)]\nمثال:  1,3500,205.1,12.4',
              style: TextStyle(color: colors['warning'], fontSize: 12)),
          const SizedBox(height: 8),
          TextField(
            controller: _csvCtrl,
            maxLines: 8,
            style: TextStyle(color: colors['text'], fontFamily: 'monospace', fontSize: 13),
            decoration: InputDecoration(
              hintText: 'الصق الجدول هنا...',
              hintStyle: TextStyle(color: colors['text']?.withOpacity(0.4)),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
                child: OutlinedButton.icon(
                    onPressed: _paste,
                    icon: const Icon(Icons.paste),
                    label: const Text('لصق من الحافظة'))),
            const SizedBox(width: 8),
            Expanded(
                child: ElevatedButton.icon(
                    onPressed: _analyze,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: colors['primary'], foregroundColor: Colors.black),
                    icon: const Icon(Icons.search),
                    label: const Text('تحليل ومعاينة'))),
          ]),
          if (_analyzed) ...[
            const SizedBox(height: 16),
            Text('النتيجة: ${_parsed.length} صف صالح',
                style: TextStyle(color: colors['text'], fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final e in counts.entries)
                Chip(
                    label: Text('حشوة ${e.key}: ${e.value} صف'),
                    backgroundColor: colors['surfaceLight'],
                    labelStyle: TextStyle(color: colors['text'], fontSize: 12)),
            ]),
            if (_issues.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.12),
                    border: Border.all(color: Colors.orange),
                    borderRadius: BorderRadius.circular(8)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('تنبيهات (${_issues.length}):',
                      style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                  for (final s in _issues.take(8))
                    Text('• $s', style: TextStyle(color: colors['text'], fontSize: 11)),
                  if (_issues.length > 8)
                    Text('... و${_issues.length - 8} أخرى',
                        style: TextStyle(color: colors['text'], fontSize: 11)),
                ]),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4CAF50),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14)),
                    icon: const Icon(Icons.save),
                    label: const Text('متابعة → دمج / استبدال'))),
          ],
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}