import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../theme/theme_provider.dart';
import '../../../domain/firing_table.dart';
import '../../../domain/custom_tables_loader.dart';
import '../../../services/data_service.dart';
import '../../../models/models.dart';
import 'import_csv_screen.dart';

// ============================================================
// أسماء عربية للعرض فقط (المفاتيح الداخلية لا تتغير)
// ============================================================
const Map<String, String> _shellArabic = {
  'he': 'شديد الانفجار (HE)',
  'smoke': 'دخان (Smoke)',
  'illumination': 'تنوير (Illum)',
  'airburst': 'انفلاق جوي (Airburst)',
};

const Map<String, String> _countryArabic = {
  'usa': 'أمريكا',
  'russia': 'روسيا',
  'china': 'الصين',
  'iran': 'إيران',
  'serbia': 'صربيا',
  'yugoslavia': 'يوغوسلافيا',
  'iraq': 'العراق',
};

const Map<String, String> _weaponFallback = {
  'mortar60': 'هاون 60 ملم (M224)',
  'mortar81': 'هاون 81 ملم (M252)',
  'mortar82': 'هاون 82 ملم (BM-37)',
  'mortar120': 'هاون 120 ملم (M120)',
  'd30': 'مدفعية 122 ملم (D-30)',
  '2s1': 'مدفعية 122 ملم ذاتية الحركة (2S1)',
  'm109a6': 'مدفعية 155 ملم ذاتية الحركة (M109A6)',
  'm198': 'مدفعية 155 ملم (M198)',
  'type59': 'مدفعية 130 ملم (Type 59 / M-46)',
  'm46': 'مدفعية 130 ملم (M-46)',
  '2s3': 'مدفعية 152 ملم ذاتية الحركة (2S3)',
  'bm21': 'راجمة صواريخ 122 ملم (BM-21)',
};

String firingTableDisplayName(String key) {
  final parts = key.split('_');
  final weaponId = parts.isNotEmpty ? parts[0] : key;
  final shellName = parts.length > 1 ? parts[1] : '';
  final countryName = parts.length > 2 ? parts[2] : '';

  String weaponAr;
  final match = DataService.allWeapons.where((w) => w.id == weaponId);
  if (match.isNotEmpty) {
    weaponAr = match.first.nameAr;
  } else {
    weaponAr = _weaponFallback[weaponId] ?? weaponId;
  }
  final shellAr = _shellArabic[shellName] ?? shellName.toUpperCase();
  final countryAr = _countryArabic[countryName] ?? countryName.toUpperCase();
  return '$weaponAr — $shellAr — $countryAr';
}

// ============================================================
// شاشة قائمة الجداول
// ============================================================
class TableManagerScreen extends StatefulWidget {
  const TableManagerScreen({super.key});
  @override
  State<TableManagerScreen> createState() => _TableManagerScreenState();
}

class _TableManagerScreenState extends State<TableManagerScreen> {
  Map<String, List<FiringTableRow>> _allTables = {};
  Set<String> _customKeys = {};
  bool _loading = true;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _loadAllTables();
  }

  Future<void> _loadAllTables() async {
    final tables = Map<String, List<FiringTableRow>>.from(FiringTables.getAllTables());
    final custom = <String>{};
    final prefs = await SharedPreferences.getInstance();
    for (final key in prefs.getKeys().where((k) => k.startsWith(CustomTablesLoader.prefix))) {
      final tableKey = key.substring(CustomTablesLoader.prefix.length);
      final jsonStr = prefs.getString(key);
      if (jsonStr == null) continue;
      try {
        final rows = (jsonDecode(jsonStr) as List)
            .map((e) => FiringTableRow.fromJson(e as Map<String, dynamic>))
            .toList();
        rows.sort((a, b) => a.rangeMeters.compareTo(b.rangeMeters));
        tables[tableKey] = rows;
        custom.add(tableKey);
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      _allTables = tables;
      _customKeys = custom;
      _loading = false;
    });
  }

  Future<void> _editTable(String tableKey, List<FiringTableRow> currentRows) async {
    final updatedRows = await Navigator.push<List<FiringTableRow>>(
      context,
      MaterialPageRoute(
        builder: (_) => EditTableRowsScreen(tableKey: tableKey, initialRows: currentRows),
      ),
    );
    if (updatedRows == null) return;
    await CustomTablesLoader.save(tableKey, updatedRows);
    await _loadAllTables();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم حفظ التعديلات بنجاح'), backgroundColor: Colors.green),
    );
  }

  Future<void> _importCsv() async {
    final res = await Navigator.push<CsvImportResult>(
      context,
      MaterialPageRoute(builder: (_) => const ImportCsvScreen()),
    );
    if (res == null || !mounted) return;

    final existing = _allTables[res.tableKey] ?? <FiringTableRow>[];
    String mode = 'replace';
    if (existing.isNotEmpty) {
      final choice = await showDialog<String>(
        context: context,
        builder: (dCtx) => AlertDialog(
          title: const Text('الجدول موجود مسبقاً'),
          content: Text(
              'يوجد ${existing.length} صف في:\n${firingTableDisplayName(res.tableKey)}\n\nاستبدال الكل أم دمج الجديد فوق القديم؟'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('إلغاء')),
            TextButton(onPressed: () => Navigator.pop(dCtx, 'merge'), child: const Text('دمج')),
            ElevatedButton(
                onPressed: () => Navigator.pop(dCtx, 'replace'), child: const Text('استبدال')),
          ],
        ),
      );
      if (choice == null || !mounted) return;
      mode = choice;
    }

    List<FiringTableRow> finalRows;
    if (mode == 'merge') {
      final map = {for (final r in existing) '${r.charge}:${r.rangeMeters}': r};
      for (final r in res.rows) {
        map['${r.charge}:${r.rangeMeters}'] = r;
      }
      finalRows = map.values.toList()
        ..sort((a, b) {
          final c = a.charge.compareTo(b.charge);
          return c != 0 ? c : a.rangeMeters.compareTo(b.rangeMeters);
        });
    } else {
      finalRows = res.rows;
    }

    await CustomTablesLoader.save(res.tableKey, finalRows);
    await _loadAllTables();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('تم استيراد ${res.rows.length} صف إلى ${firingTableDisplayName(res.tableKey)}'),
      backgroundColor: Colors.green,
    ));
  }

  Future<void> _createNewTable() async {
    if (DataService.allWeapons.isEmpty) return;
    String weaponId = DataService.allWeapons.first.id;
    ShellType shellType = ShellType.he;
    ShellCountry country = ShellCountry.usa;

    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => StatefulBuilder(
        builder: (dCtx, setS) {
          final colors = Provider.of<ThemeProvider>(dCtx, listen: false).colors;
          return AlertDialog(
            backgroundColor: colors['surface'],
            title: Text('جدول رمي جديد', style: TextStyle(color: colors['text'])),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButton<String>(
                    isExpanded: true,
                    value: weaponId,
                    dropdownColor: colors['surface'],
                    items: DataService.allWeapons
                        .map((w) => DropdownMenuItem(
                              value: w.id,
                              child: Text(w.nameAr,
                                  style: TextStyle(color: colors['text'], fontSize: 13)),
                            ))
                        .toList(),
                    onChanged: (v) => setS(() => weaponId = v ?? weaponId),
                  ),
                  const SizedBox(height: 8),
                  DropdownButton<ShellType>(
                    isExpanded: true,
                    value: shellType,
                    dropdownColor: colors['surface'],
                    items: ShellType.values
                        .map((s) => DropdownMenuItem(
                              value: s,
                              child: Text(_shellArabic[s.name] ?? s.name.toUpperCase(),
                                  style: TextStyle(color: colors['text'])),
                            ))
                        .toList(),
                    onChanged: (v) => setS(() => shellType = v ?? shellType),
                  ),
                  const SizedBox(height: 8),
                  DropdownButton<ShellCountry>(
                    isExpanded: true,
                    value: country,
                    dropdownColor: colors['surface'],
                    items: ShellCountry.values
                        .map((c) => DropdownMenuItem(
                              value: c,
                              child: Text(_countryArabic[c.name] ?? c.name.toUpperCase(),
                                  style: TextStyle(color: colors['text'])),
                            ))
                        .toList(),
                    onChanged: (v) => setS(() => country = v ?? country),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(dCtx, false), child: const Text('إلغاء')),
              ElevatedButton(
                  onPressed: () => Navigator.pop(dCtx, true), child: const Text('التالي')),
            ],
          );
        },
      ),
    );

    if (ok != true || !mounted) return;
    final key = '${weaponId}_${shellType.name}_${country.name}';
    await _editTable(key, _allTables[key] ?? <FiringTableRow>[]);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Provider.of<ThemeProvider>(context).colors;
    final keys = _allTables.keys.where((k) {
      if (_search.isEmpty) return true;
      final q = _search.toLowerCase();
      return k.toLowerCase().contains(q) ||
          firingTableDisplayName(k).toLowerCase().contains(q);
    }).toList()
      ..sort();

    return Scaffold(
      backgroundColor: colors['bg'],
      appBar: AppBar(
        title: const Text('إدارة جداول الرمي'),
        backgroundColor: colors['surface'],
        iconTheme: IconThemeData(color: colors['text'] ?? Colors.white),
        actions: [
          IconButton(
            icon: Icon(Icons.upload_file, color: colors['primary']),
            tooltip: 'استيراد CSV',
            onPressed: _importCsv,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: TextField(
                    style: TextStyle(color: colors['text']),
                    decoration: InputDecoration(
                      hintText: 'بحث باسم السلاح أو نوع العتاد...',
                      hintStyle: TextStyle(color: colors['text']?.withOpacity(0.5)),
                      prefixIcon: Icon(Icons.search, color: colors['primary']),
                      isDense: true,
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (v) => setState(() => _search = v),
                  ),
                ),
                Expanded(
                  child: keys.isEmpty
                      ? Center(
                          child: Text('لا توجد جداول. اضغط + لإنشاء جدول',
                              style: TextStyle(color: colors['text'])))
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                          itemCount: keys.length,
                          itemBuilder: (context, index) {
                            final key = keys[index];
                            final rows = _allTables[key]!;
                            final isCustom = _customKeys.contains(key);
                            return Card(
                              color: colors['surface'],
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(
                                side: BorderSide(
                                    color: isCustom
                                        ? Colors.greenAccent
                                        : (colors['border'] ?? Colors.grey)),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ListTile(
                                leading: Icon(Icons.table_chart,
                                    color: isCustom ? Colors.greenAccent : colors['primary'],
                                    size: 30),
                                title: Text(
                                  firingTableDisplayName(key),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      color: colors['text'],
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(key,
                                        style: TextStyle(
                                            color: colors['text']?.withOpacity(0.45),
                                            fontSize: 10,
                                            fontFamily: 'monospace')),
                                    Text(
                                        'عدد الصفوف: ${rows.length}${isCustom ? "  •  معدّل يدوياً" : ""}',
                                        style: TextStyle(
                                            color: colors['text']?.withOpacity(0.6),
                                            fontSize: 12)),
                                  ],
                                ),
                                trailing: Icon(Icons.edit, color: colors['warning']),
                                onTap: () => _editTable(key, rows),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createNewTable,
        backgroundColor: colors['primary'],
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add),
        label: const Text('جدول جديد'),
      ),
    );
  }
}

// ============================================================
// صف قابل للتحرير داخل الشبكة
// ============================================================
class _EditableRow {
  final TextEditingController rangeCtrl;
  final TextEditingController elCtrl;
  final TextEditingController tofCtrl;
  final FocusNode rangeFocus;
  int heightMeters;

  _EditableRow({String range = '', String el = '', String tof = '', this.heightMeters = 0})
      : rangeCtrl = TextEditingController(text: range),
        elCtrl = TextEditingController(text: el),
        tofCtrl = TextEditingController(text: tof),
        rangeFocus = FocusNode();

  factory _EditableRow.fromRow(FiringTableRow r) => _EditableRow(
        range: r.rangeMeters.toString(),
        el: _fmt(r.elevationMils),
        tof: _fmt(r.timeOfFlightSec),
        heightMeters: r.heightMeters,
      );

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  bool get isBlank =>
      rangeCtrl.text.trim().isEmpty &&
      elCtrl.text.trim().isEmpty &&
      tofCtrl.text.trim().isEmpty;

  void detachListeners(VoidCallback l) {
    rangeCtrl.removeListener(l);
    elCtrl.removeListener(l);
    tofCtrl.removeListener(l);
  }

  void dispose() {
    rangeCtrl.dispose();
    elCtrl.dispose();
    tofCtrl.dispose();
    rangeFocus.dispose();
  }
}

// ============================================================
// شاشة إدخال/تعديل الجدول — شبكة صفوف + تبويب لكل حشوة
// ============================================================
class EditTableRowsScreen extends StatefulWidget {
  final String tableKey;
  final List<FiringTableRow> initialRows;
  const EditTableRowsScreen({super.key, required this.tableKey, required this.initialRows});

  @override
  State<EditTableRowsScreen> createState() => _EditTableRowsScreenState();
}

class _EditTableRowsScreenState extends State<EditTableRowsScreen>
    with TickerProviderStateMixin {
  final Map<int, List<_EditableRow>> _rowsByCharge = {};
  final List<int> _charges = [];
  TabController? _tabController;
  int _lastIndex = 0;
  bool _dirty = false;
  bool _plusBusy = false;

  // مقبرة: كل ما يُحذف أو يُستبدل يُؤجل التخلص منه إلى إغلاق الشاشة
  final List<TabController> _retiredTabs = [];
  final List<_EditableRow> _graveyard = [];
  final List<TextEditingController> _dialogCtrls = [];

  @override
  void initState() {
    super.initState();
    for (final r in widget.initialRows) {
      _rowsByCharge.putIfAbsent(r.charge, () => []).add(_EditableRow.fromRow(r));
    }
    if (_rowsByCharge.isEmpty) _rowsByCharge[0] = [_EditableRow()];
    _charges.addAll(_rowsByCharge.keys.toList()..sort());
    for (final c in _charges) {
      _sortCharge(c);
      _listenToCharge(c);
    }
    _buildTabController(0);
  }

  void _sortCharge(int c) {
    _rowsByCharge[c]!.sort((a, b) =>
        (int.tryParse(a.rangeCtrl.text) ?? 0).compareTo(int.tryParse(b.rangeCtrl.text) ?? 0));
  }

  void _listenToCharge(int c) {
    for (final r in _rowsByCharge[c]!) {
      r.rangeCtrl.addListener(_markDirty);
      r.elCtrl.addListener(_markDirty);
      r.tofCtrl.addListener(_markDirty);
    }
  }

  void _markDirty() => _dirty = true;

  void _buildTabController(int initial) {
    final old = _tabController;
    if (old != null) {
      old.removeListener(_onTabChanged);
      _retiredTabs.add(old); // لا نتخلص منه الآن — آمن حتى إغلاق الشاشة
    }
    _tabController =
        TabController(length: _charges.length + 1, vsync: this, initialIndex: initial);
    _lastIndex = initial;
    _tabController!.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    final i = _tabController!.index;
    if (i == _charges.length) {
      _tabController!.index = _lastIndex;
      if (!_plusBusy) {
        _plusBusy = true;
        _promptAddCharge().whenComplete(() => _plusBusy = false);
      }
    } else {
      _lastIndex = i;
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    _tabController?.removeListener(_onTabChanged);
    _tabController?.dispose();
    for (final t in _retiredTabs) {
      t.dispose();
    }
    for (final list in _rowsByCharge.values) {
      for (final r in list) {
        r.dispose();
      }
    }
    for (final r in _graveyard) {
      r.dispose();
    }
    for (final c in _dialogCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  void _addRow() {
    final c = _charges[_lastIndex];
    final row = _EditableRow();
    row.rangeCtrl.addListener(_markDirty);
    row.elCtrl.addListener(_markDirty);
    row.tofCtrl.addListener(_markDirty);
    setState(() {
      _rowsByCharge[c]!.add(row);
      _dirty = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) row.rangeFocus.requestFocus();
    });
  }

  void _deleteRow(int c, int i) {
    setState(() {
      final r = _rowsByCharge[c]!.removeAt(i);
      r.detachListeners(_markDirty);
      _graveyard.add(r);
      _dirty = true;
    });
  }

  Future<void> _promptAddCharge() async {
    final ctrl = TextEditingController();
    _dialogCtrls.add(ctrl);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Text('إضافة حشوة جديدة'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'رقم الحشوة (مثال: 5)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () => Navigator.pop(dCtx, true), child: const Text('إضافة')),
        ],
      ),
    );
    final text = ctrl.text.trim();
    if (ok != true || !mounted) return;
    final c = int.tryParse(text);
    if (c == null || c < 0) return;
    if (_charges.contains(c)) {
      _tabController!.index = _charges.indexOf(c);
      return;
    }
    setState(() {
      _charges.add(c);
      _charges.sort();
      _rowsByCharge[c] = [_EditableRow()];
      _listenToCharge(c);
      _dirty = true;
    });
    _buildTabController(_charges.indexOf(c));
    setState(() {});
  }

  Future<void> _confirmDeleteCharge(int c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: Text('حذف الحشوة $c'),
        content: Text('سيتم حذف كل صفوف الحشوة $c (${_rowsByCharge[c]!.length} صف). متابعة؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dCtx, true),
            child: const Text('حذف', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() {
      for (final r in _rowsByCharge[c]!) {
        r.detachListeners(_markDirty);
        _graveyard.add(r);
      }
      _rowsByCharge.remove(c);
      _charges.remove(c);
      if (_charges.isEmpty) {
        _charges.add(0);
        _rowsByCharge[0] = [_EditableRow()];
        _listenToCharge(0);
      }
      _dirty = true;
    });
    _buildTabController(0);
    setState(() {});
  }

  Future<void> _editHeight(_EditableRow row) async {
    final ctrl = TextEditingController(text: row.heightMeters.toString());
    _dialogCtrls.add(ctrl);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Text('أقصى ارتفاع (متر)'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'أقصى ارتفاع للمسار بالمتر'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () => Navigator.pop(dCtx, true), child: const Text('حفظ')),
        ],
      ),
    );
    final text = ctrl.text.trim();
    if (ok != true || !mounted) return;
    setState(() {
      row.heightMeters = int.tryParse(text) ?? row.heightMeters;
      _dirty = true;
    });
  }

  void _save() {
    final all = <FiringTableRow>[];
    for (final c in _charges) {
      for (final r in _rowsByCharge[c]!) {
        if (r.isBlank) continue;
        final range = int.tryParse(r.rangeCtrl.text.trim()) ?? 0;
        final el = double.tryParse(r.elCtrl.text.trim());
        final tof = double.tryParse(r.tofCtrl.text.trim());
        if (range <= 0 || el == null || el <= 0 || tof == null || tof < 0) {
          _tabController!.index = _charges.indexOf(c);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('صف غير مكتمل في الحشوة $c: المدى والارتفاع مطلوبان (>0) والزمن >=0'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
        all.add(FiringTableRow(
          charge: c,
          rangeMeters: range,
          elevationMils: el,
          timeOfFlightSec: tof,
          heightMeters: r.heightMeters,
        ));
      }
    }
    all.sort((a, b) {
      final cc = a.charge.compareTo(b.charge);
      return cc != 0 ? cc : a.rangeMeters.compareTo(b.rangeMeters);
    });
    _dirty = false;
    Navigator.pop(context, all);
  }

  Future<void> _confirmExit() async {
    if (!_dirty) {
      Navigator.pop(context);
      return;
    }
    final res = await showDialog<String>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Text('تغييرات غير محفوظة'),
        content: const Text('هل تريد حفظ التعديلات قبل الخروج؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dCtx, 'discard'),
              child: const Text('تجاهل', style: TextStyle(color: Colors.red))),
          TextButton(
              onPressed: () => Navigator.pop(dCtx, 'cancel'),
              child: const Text('متابعة التحرير')),
          ElevatedButton(onPressed: () => Navigator.pop(dCtx, 'save'), child: const Text('حفظ')),
        ],
      ),
    );
    if (!mounted) return;
    if (res == 'save') {
      _save();
    } else if (res == 'discard') {
      Navigator.pop(context);
    }
  }

  Widget _header(Map<String, Color> colors) {
    final s = TextStyle(color: colors['primary'], fontSize: 11, fontWeight: FontWeight.bold);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 6),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text('الحشوة', textAlign: TextAlign.center, style: s)),
          const SizedBox(width: 6),
          Expanded(flex: 2, child: Text('زمن الطيران (ث)', textAlign: TextAlign.center, style: s)),
          const SizedBox(width: 6),
          Expanded(flex: 3, child: Text('الارتفاع (مل)', textAlign: TextAlign.center, style: s)),
          const SizedBox(width: 6),
          Expanded(flex: 3, child: Text('المدى (م)', textAlign: TextAlign.center, style: s)),
          const SizedBox(width: 34),
        ],
      ),
    );
  }

  Widget _field(TextEditingController ctrl, Map<String, Color> colors,
      {FocusNode? focus, bool decimal = false}) {
    return TextField(
      controller: ctrl,
      focusNode: focus,
      keyboardType: TextInputType.numberWithOptions(decimal: decimal),
      textAlign: TextAlign.center,
      style: TextStyle(color: colors['text'], fontWeight: FontWeight.bold, fontSize: 14),
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 2),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: colors['border'] ?? Colors.grey),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: colors['primary'] ?? Colors.orange, width: 1.8),
        ),
      ),
    );
  }

  Widget _rowCard(int c, int i, Map<String, Color> colors) {
    final r = _rowsByCharge[c]![i];
    return GestureDetector(
      onLongPress: () => _editHeight(r),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: colors['surfaceLight'],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors['border'] ?? Colors.grey),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Container(
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: colors['border'] ?? Colors.grey),
                ),
                child: Text('$c',
                    style: TextStyle(
                        color: colors['text']?.withOpacity(0.7), fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(flex: 2, child: _field(r.tofCtrl, colors, decimal: true)),
            const SizedBox(width: 6),
            Expanded(flex: 3, child: _field(r.elCtrl, colors, decimal: true)),
            const SizedBox(width: 6),
            Expanded(flex: 3, child: _field(r.rangeCtrl, colors, focus: r.rangeFocus)),
            SizedBox(
              width: 34,
              child: IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Icon(Icons.delete_outline, size: 20, color: Colors.red.withOpacity(0.7)),
                onPressed: () => _deleteRow(c, i),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chargePage(int c, Map<String, Color> colors) {
    final rows = _rowsByCharge[c]!;
    if (rows.isEmpty) {
      return Center(
          child: Text('لا توجد صفوف في الحشوة $c\nاضغط "صف جديد" للإضافة',
              textAlign: TextAlign.center, style: TextStyle(color: colors['text'])));
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      itemCount: rows.length,
      itemBuilder: (context, i) => _rowCard(c, i, colors),
    );
  }

  Widget _bottomBar(Map<String, Color> colors) {
    return Container(
      color: colors['surface'],
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _addRow,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors['primary'],
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('صف جديد', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                  ),
                  icon: const Icon(Icons.save),
                  label: const Text('حفظ الجدول', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Provider.of<ThemeProvider>(context).colors;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _confirmExit();
      },
      child: Scaffold(
        backgroundColor: colors['bg'],
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(firingTableDisplayName(widget.tableKey),
                  style: TextStyle(fontSize: 14, color: colors['text']),
                  overflow: TextOverflow.ellipsis),
              Text(widget.tableKey,
                  style: TextStyle(
                      fontSize: 9,
                      color: colors['text']?.withOpacity(0.5),
                      fontFamily: 'monospace'),
                  overflow: TextOverflow.ellipsis),
            ],
          ),
          backgroundColor: colors['surface'],
          iconTheme: IconThemeData(color: colors['text'] ?? Colors.white),
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: _confirmExit),
          bottom: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: colors['primary'],
            unselectedLabelColor: colors['text']?.withOpacity(0.6),
            indicatorColor: colors['primary'],
            tabs: [
              for (final c in _charges)
                Tab(
                  child: GestureDetector(
                    onLongPress: () => _confirmDeleteCharge(c),
                    child: Text('حشوة $c'),
                  ),
                ),
              const Tab(icon: Icon(Icons.add, size: 20)),
            ],
          ),
        ),
        body: Column(
          children: [
            _header(colors),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  for (final c in _charges) _chargePage(c, colors),
                  const SizedBox(),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: _bottomBar(colors),
      ),
    );
  }
}