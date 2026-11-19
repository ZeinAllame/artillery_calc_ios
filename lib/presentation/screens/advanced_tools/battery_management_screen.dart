import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../theme/theme_provider.dart';

class BatteryManagementScreen extends StatefulWidget {
  const BatteryManagementScreen({Key? key}) : super(key: key);
  @override
  State<BatteryManagementScreen> createState() => _BatteryManagementScreenState();
}

class _BatteryManagementScreenState extends State<BatteryManagementScreen> {
  List<Map<String, dynamic>> _guns = [];
  List<Map<String, dynamic>> _targets = [];
  List<Map<String, dynamic>> _assignments = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final gunsJson = prefs.getString('battery_guns');
    final targetsJson = prefs.getString('battery_targets');
    
    setState(() {
      _guns = gunsJson != null ? List<Map<String, dynamic>>.from(json.decode(gunsJson)) : [];
      _targets = targetsJson != null ? List<Map<String, dynamic>>.from(json.decode(targetsJson)) : [];
    });
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('battery_guns', json.encode(_guns));
    await prefs.setString('battery_targets', json.encode(_targets));
  }

  Future<void> _addGun() async {
    final nameCtrl = TextEditingController();
    final ammoCtrl = TextEditingController(text: '50');
    final statusCtrl = TextEditingController(text: 'جاهز');
    
    final colors = Provider.of<ThemeProvider>(context, listen: false).colors;
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors['surface'],
        title: Text('إضافة مدفع', style: TextStyle(color: colors['text'])),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'اسم/رقم المدفع')),
            const SizedBox(height: 8),
            TextField(controller: ammoCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'الذخيرة المتوفرة')),
            const SizedBox(height: 8),
            TextField(controller: statusCtrl, decoration: const InputDecoration(labelText: 'الحالة (جاهز/صيانة/عطل)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _guns.add({
                  'id': DateTime.now().millisecondsSinceEpoch.toString(),
                  'name': nameCtrl.text,
                  'ammo': int.tryParse(ammoCtrl.text) ?? 0,
                  'status': statusCtrl.text,
                });
              });
              _saveData();
              Navigator.pop(ctx);
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }

  Future<void> _addTarget() async {
    final nameCtrl = TextEditingController();
    final priorityCtrl = TextEditingController(text: '1');
    final descCtrl = TextEditingController();
    
    final colors = Provider.of<ThemeProvider>(context, listen: false).colors;
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors['surface'],
        title: Text('إضافة هدف', style: TextStyle(color: colors['text'])),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'اسم الهدف')),
            const SizedBox(height: 8),
            TextField(controller: priorityCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'الأولوية (1=أعلى)')),
            const SizedBox(height: 8),
            TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'الوصف')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _targets.add({
                  'id': DateTime.now().millisecondsSinceEpoch.toString(),
                  'name': nameCtrl.text,
                  'priority': int.tryParse(priorityCtrl.text) ?? 1,
                  'description': descCtrl.text,
                  'assigned': false,
                });
              });
              _saveData();
              Navigator.pop(ctx);
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }

  void _autoAssign() {
    // ترتيب الأهداف حسب الأولوية
    _targets.sort((a, b) => (a['priority'] as int).compareTo(b['priority'] as int));
    
    // تعيين كل هدف لأفضل مدفع متوفر
    _assignments.clear();
    final gunAmmo = <String, int>{};
    for (var gun in _guns) {
      if (gun['status'] == 'جاهز') {
        gunAmmo[gun['id']] = gun['ammo'] as int;
      }
    }
    
    for (var target in _targets) {
      if (gunAmmo.isEmpty) break;
      
      // اختيار المدفع صاحب أكبر ذخيرة
      String? bestGunId;
      int maxAmmo = 0;
      for (var entry in gunAmmo.entries) {
        if (entry.value > maxAmmo) {
          maxAmmo = entry.value;
          bestGunId = entry.key;
        }
      }
      
      if (bestGunId != null) {
        final gun = _guns.firstWhere((g) => g['id'] == bestGunId);
        _assignments.add({
          'target': target['name'],
          'gun': gun['name'],
          'ammoUsed': 1,
        });
        gunAmmo[bestGunId] = maxAmmo - 1;
        target['assigned'] = true;
      }
    }
    
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم توزيع ${_assignments.length} هدف على المدافع'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _clearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد المسح'),
        content: const Text('سيتم مسح جميع المدافع والأهداف والتعيينات'),
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
    
    if (confirmed == true) {
      setState(() {
        _guns.clear();
        _targets.clear();
        _assignments.clear();
      });
      _saveData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Provider.of<ThemeProvider>(context).colors;

    return Scaffold(
      backgroundColor: colors['bg'],
      appBar: AppBar(
        title: const Text('إدارة بطارية المدفعية'),
        backgroundColor: colors['surface'],
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_forever, color: Colors.red),
            onPressed: _clearAll,
            tooltip: 'مسح الكل',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // إحصائيات
            Row(
              children: [
                Expanded(child: _buildStatCard('المدافع', '${_guns.length}', Icons.local_fire_department, colors)),
                const SizedBox(width: 8),
                Expanded(child: _buildStatCard('الأهداف', '${_targets.length}', Icons.flag, colors)),
                const SizedBox(width: 8),
                Expanded(child: _buildStatCard('المُعيَّنة', '${_assignments.length}', Icons.check_circle, colors)),
              ],
            ),
            const SizedBox(height: 16),

            // زر التوزيع التلقائي
            if (_guns.isNotEmpty && _targets.isNotEmpty)
              ElevatedButton.icon(
                onPressed: _autoAssign,
                icon: const Icon(Icons.auto_awesome),
                label: const Text('توزيع تلقائي للأهداف'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors['primary'],
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
            const SizedBox(height: 16),

            // قسم المدافع
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('المدافع', 
                          style: TextStyle(color: colors['primary'], fontSize: 16, fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: Icon(Icons.add, color: colors['primary']),
                        onPressed: _addGun,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_guns.isEmpty)
                    Center(
                      child: Text('لا توجد مدافع مضافة', 
                          style: TextStyle(color: colors['text']?.withOpacity(0.5))),
                    )
                  else
                    ..._guns.map((gun) => _buildGunCard(gun, colors)),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // قسم الأهداف
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('الأهداف', 
                          style: TextStyle(color: colors['primary'], fontSize: 16, fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: Icon(Icons.add, color: colors['primary']),
                        onPressed: _addTarget,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_targets.isEmpty)
                    Center(
                      child: Text('لا توجد أهداف مضافة', 
                          style: TextStyle(color: colors['text']?.withOpacity(0.5))),
                    )
                  else
                    ..._targets.map((target) => _buildTargetCard(target, colors)),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // قسم التعيينات
            if (_assignments.isNotEmpty)
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
                    Text('خطة التوزيع', 
                        style: TextStyle(color: colors['primary'], fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    ..._assignments.map((assignment) => _buildAssignmentCard(assignment, colors)),
                  ],
                ),
              ),
          ],
        ),
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
          Text(value, style: TextStyle(color: colors['text'], fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: colors['text']?.withOpacity(0.6), fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildGunCard(Map<String, dynamic> gun, Map<String, Color> colors) {
    final isReady = gun['status'] == 'جاهز';
    return Card(
      color: colors['bg'],
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: isReady ? Colors.green : Colors.orange),
      ),
      child: ListTile(
        leading: Icon(
          Icons.local_fire_department,
          color: isReady ? Colors.green : Colors.orange,
        ),
        title: Text(gun['name'], style: TextStyle(color: colors['text'], fontWeight: FontWeight.bold)),
        subtitle: Text('الذخيرة: ${gun['ammo']} | الحالة: ${gun['status']}',
            style: TextStyle(color: colors['text']?.withOpacity(0.7), fontSize: 12)),
        trailing: IconButton(
          icon: const Icon(Icons.delete, color: Colors.red),
          onPressed: () {
            setState(() => _guns.remove(gun));
            _saveData();
          },
        ),
      ),
    );
  }

  Widget _buildTargetCard(Map<String, dynamic> target, Map<String, Color> colors) {
    final isAssigned = target['assigned'] == true;
    return Card(
      color: colors['bg'],
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: isAssigned ? Colors.green : colors['border']!),
      ),
      child: ListTile(
        leading: Icon(
          isAssigned ? Icons.check_circle : Icons.flag,
          color: isAssigned ? Colors.green : colors['warning'],
        ),
        title: Text(target['name'], style: TextStyle(color: colors['text'], fontWeight: FontWeight.bold)),
        subtitle: Text('الأولوية: ${target['priority']} | ${target['description']}',
            style: TextStyle(color: colors['text']?.withOpacity(0.7), fontSize: 12)),
        trailing: IconButton(
          icon: const Icon(Icons.delete, color: Colors.red),
          onPressed: () {
            setState(() => _targets.remove(target));
            _saveData();
          },
        ),
      ),
    );
  }

  Widget _buildAssignmentCard(Map<String, dynamic> assignment, Map<String, Color> colors) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors['bg'],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors['primary']!),
      ),
      child: Row(
        children: [
          Icon(Icons.arrow_forward, color: colors['primary']),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('الهدف: ${assignment['target']}', 
                    style: TextStyle(color: colors['text'], fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('المدفع: ${assignment['gun']} | ذخيرة: ${assignment['ammoUsed']}', 
                    style: TextStyle(color: colors['text']?.withOpacity(0.7), fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}