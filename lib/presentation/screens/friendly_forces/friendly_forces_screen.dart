import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mgrs_dart/mgrs_dart.dart';

import '../../../theme/theme_provider.dart';
import '../../../domain/mgrs_decoder.dart';
import '../../../models/friendly_unit.dart';

class FriendlyForcesScreen extends StatefulWidget {
  const FriendlyForcesScreen({Key? key}) : super(key: key);
  @override
  State<FriendlyForcesScreen> createState() => _FriendlyForcesScreenState();
}

class _FriendlyForcesScreenState extends State<FriendlyForcesScreen> {
  @override
  void initState() {
    super.initState();
    FriendlyForcesStore.load().then((_) => setState(() {}));
  }

  // ★★ إضافة فرقة جديدة (جذر مستقل) ★★
  void _addDivision() {
    final ctrl = TextEditingController();
    final colors = Provider.of<ThemeProvider>(context, listen: false).colors;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors['surface'],
        title: Text('فرقة جديدة', style: TextStyle(color: colors['text'])),
        content: TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'اسم الفرقة')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              if (ctrl.text.isNotEmpty) {
                FriendlyForcesStore.roots.add(FriendlyUnit(
                  id: DateTime.now().microsecondsSinceEpoch.toString(),
                  name: ctrl.text,
                  level: UnitLevel.division,
                ));
                FriendlyForcesStore.save();
                setState(() {});
                Navigator.pop(ctx);
              }
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }

  void _deleteRoot(FriendlyUnit root) {
    if (FriendlyForcesStore.roots.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يجب الإبقاء على فرقة واحدة على الأقل'), backgroundColor: Colors.orange));
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف الفرقة'),
        content: Text('حذف "${root.name}" بكل ما فيها من ألوية ونقاط؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              FriendlyForcesStore.roots.remove(root);
              FriendlyForcesStore.save();
              setState(() {});
              Navigator.pop(ctx);
            },
            child: const Text('حذف', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showAddDialog(FriendlyUnit parent) {
    final colors = Provider.of<ThemeProvider>(context, listen: false).colors;
    final nameCtrl = TextEditingController();
    final zCtrl = TextEditingController(text: "38");
    final bCtrl = TextEditingController(text: "S");
    final sCtrl = TextEditingController(text: "MB");
    final eCtrl = TextEditingController();
    final nCtrl = TextEditingController();
    final radiusCtrl = TextEditingController(text: '500');
    UnitLevel level = _nextLevel(parent.level);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          backgroundColor: colors['surface'],
          title: Text('إضافة داخل: ${parent.name}', style: TextStyle(color: colors['text'], fontSize: 15)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Wrap(
                  spacing: 6,
                  children: UnitLevel.values.map((l) {
                    final enabled = _canAddUnder(parent.level, l);
                    return ChoiceChip(
                      label: Text(l.labelAr, style: const TextStyle(fontSize: 11)),
                      selected: level == l,
                      onSelected: enabled ? (_) => setDlg(() => level = l) : null,
                    );
                  }).toList(),
                ),
                const SizedBox(height: 10),
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'الاسم')),
                const SizedBox(height: 8),
                if (level == UnitLevel.point) ...[
                  Row(children: [
                    Expanded(child: TextField(controller: zCtrl, maxLength: 2, decoration: const InputDecoration(labelText: 'Zone'))),
                    const SizedBox(width: 5),
                    Expanded(child: TextField(controller: bCtrl, maxLength: 1, decoration: const InputDecoration(labelText: 'Band'))),
                    const SizedBox(width: 5),
                    Expanded(child: TextField(controller: sCtrl, maxLength: 2, decoration: const InputDecoration(labelText: 'Sq'))),
                  ]),
                  const SizedBox(height: 6),
                  Row(children: [
                    Expanded(child: TextField(controller: eCtrl, maxLength: 5, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Easting'))),
                    const SizedBox(width: 5),
                    Expanded(child: TextField(controller: nCtrl, maxLength: 5, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Northing'))),
                    IconButton(
                      icon: const Icon(Icons.gps_fixed, color: Colors.cyan),
                      onPressed: () async {
                        try {
                          LocationPermission permission = await Geolocator.checkPermission();
                          if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
                          if (permission == LocationPermission.deniedForever) return;
                          final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
                          final m = Mgrs.forward([pos.longitude, pos.latitude], 5);
                          setDlg(() {
                            zCtrl.text = m.substring(0, 2);
                            bCtrl.text = m.substring(2, 3);
                            sCtrl.text = m.substring(3, 5);
                            eCtrl.text = m.substring(5, 10);
                            nCtrl.text = m.substring(10, 15);
                          });
                        } catch (_) {}
                      },
                    ),
                  ]),
                  const SizedBox(height: 6),
                  TextField(
                    controller: radiusCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'مسافة الأمان (م) — لا تقل عن 500'),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () {
                double? e, n;
                if (level == UnitLevel.point) {
                  final mgrs = "${zCtrl.text}${bCtrl.text}${sCtrl.text}${eCtrl.text}${nCtrl.text}";
                  final utm = MgrsDecoder.decode(mgrs);
                  if (utm == null) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('MGRS غير صحيح'), backgroundColor: Colors.red));
                    return;
                  }
                  e = utm.easting;
                  n = utm.northing;
                }
                final unit = FriendlyUnit(
                  id: DateTime.now().microsecondsSinceEpoch.toString(),
                  name: nameCtrl.text.isEmpty ? '${level.labelAr} بدون اسم' : nameCtrl.text,
                  level: level,
                  utmE: e,
                  utmN: n,
                  safetyRadiusM: level == UnitLevel.point
                      ? (double.tryParse(radiusCtrl.text) ?? 500).clamp(500.0, 2000.0)
                      : 500,
                );
                setState(() => parent.children.add(unit));
                FriendlyForcesStore.save();
                Navigator.pop(ctx);
              },
              child: const Text('إضافة'),
            ),
          ],
        ),
      ),
    );
  }

  UnitLevel _nextLevel(UnitLevel parent) {
    switch (parent) {
      case UnitLevel.division: return UnitLevel.brigade;
      case UnitLevel.brigade: return UnitLevel.regiment;
      case UnitLevel.regiment: return UnitLevel.battalion;
      case UnitLevel.battalion: return UnitLevel.company;
      default: return UnitLevel.point;
    }
  }

  bool _canAddUnder(UnitLevel parent, UnitLevel child) {
    const order = [UnitLevel.division, UnitLevel.brigade, UnitLevel.regiment, UnitLevel.battalion, UnitLevel.company, UnitLevel.point];
    return order.indexOf(child) > order.indexOf(parent);
  }

  void _deleteUnit(FriendlyUnit parent, FriendlyUnit unit) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف'),
        content: Text('حذف "${unit.name}" وكل ما بداخله؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              setState(() => parent.children.remove(unit));
              FriendlyForcesStore.save();
              Navigator.pop(ctx);
            },
            child: const Text('حذف', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildNode(FriendlyUnit parent, FriendlyUnit unit) {
    final colors = Provider.of<ThemeProvider>(context).colors;
    if (unit.level == UnitLevel.point) {
      return ListTile(
        dense: true,
        leading: Icon(Icons.location_on, color: Colors.greenAccent, size: 20),
        title: Text(unit.name, style: TextStyle(color: colors['text'], fontSize: 13)),
        subtitle: Text(
          'E ${unit.utmE?.toStringAsFixed(0)} N ${unit.utmN?.toStringAsFixed(0)} | أمان: ${unit.safetyRadiusM.toStringAsFixed(0)}م',
          style: TextStyle(color: colors['text']?.withOpacity(0.6), fontSize: 11)),
        trailing: IconButton(
          icon: const Icon(Icons.delete, color: Colors.red, size: 18),
          onPressed: () => _deleteUnit(parent, unit),
        ),
      );
    }
    return Card(
      color: colors['bg'],
      child: ExpansionTile(
        leading: Icon(Icons.folder, color: colors['primary']),
        title: Text('${unit.name}  (${unit.level.labelAr})',
            style: TextStyle(color: colors['text'], fontSize: 14, fontWeight: FontWeight.bold)),
        subtitle: Text('${unit.children.length} عنصر',
            style: TextStyle(color: colors['text']?.withOpacity(0.5), fontSize: 11)),
        children: [
          ...unit.children.map((c) => _buildNode(unit, c)),
          Padding(
            padding: const EdgeInsets.only(right: 16, bottom: 8),
            child: Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _showAddDialog(unit),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('إضافة عنصر'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ★★ عرض الجذر (فرقة) مع أزرار إضافة وحذف ★★
  Widget _buildRoot(FriendlyUnit root) {
    final colors = Provider.of<ThemeProvider>(context).colors;
    return Card(
      color: colors['bg'],
      child: ExpansionTile(
        initiallyExpanded: true,
        leading: Icon(Icons.account_tree, color: colors['primary']),
        title: Text('${root.name}  (${root.level.labelAr})',
            style: TextStyle(color: colors['text'], fontSize: 15, fontWeight: FontWeight.bold)),
        subtitle: Text('${root.children.length} عنصر',
            style: TextStyle(color: colors['text']?.withOpacity(0.5), fontSize: 11)),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(
            icon: const Icon(Icons.add_circle, color: Colors.green),
            onPressed: () => _showAddDialog(root),
            tooltip: 'إضافة عنصر',
          ),
          IconButton(
            icon: const Icon(Icons.delete_forever, color: Colors.red),
            onPressed: () => _deleteRoot(root),
            tooltip: 'حذف الفرقة',
          ),
        ]),
        children: [
          ...root.children.map((c) => _buildNode(root, c)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Provider.of<ThemeProvider>(context).colors;
    final roots = FriendlyForcesStore.roots;

    return Scaffold(
      backgroundColor: colors['bg'],
      appBar: AppBar(
        title: const Text('القوات الصديقة — حاسبة الخطر'),
        backgroundColor: colors['surface'],
        actions: [
          IconButton(
            icon: const Icon(Icons.add_business),
            onPressed: _addDivision,
            tooltip: 'إضافة فرقة جديدة',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors['warning']!.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: colors['warning']!),
              ),
              child: Text(
                '⚠️ كل نقطة صديقة تحتاج مسافة أمان (≥ 500م). الحاسبة ستنبّهك تلقائياً إذا كان الهدف داخل نطاق أي نقطة.',
                style: TextStyle(color: colors['warning'], fontSize: 12)),
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                ...roots.map(_buildRoot),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ElevatedButton.icon(
                    onPressed: _addDivision,
                    icon: const Icon(Icons.add_business),
                    label: const Text('إضافة فرقة جديدة'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors['primary'],
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14)),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }
}