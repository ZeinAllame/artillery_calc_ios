import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../../theme/theme_provider.dart';

class AmmoTrackerScreen extends StatefulWidget {
  const AmmoTrackerScreen({Key? key}) : super(key: key);

  @override
  State<AmmoTrackerScreen> createState() => _AmmoTrackerScreenState();
}

class _AmmoTrackerScreenState extends State<AmmoTrackerScreen> {
  List<Map<String, dynamic>> ammoList = [];

  @override
  void initState() {
    super.initState();
    _loadAmmo();
  }

  Future<void> _loadAmmo() async {
    final prefs = await SharedPreferences.getInstance();
    final ammoJson = prefs.getString('ammo_inventory');
    if (ammoJson != null) {
      setState(() {
        ammoList = List<Map<String, dynamic>>.from(json.decode(ammoJson));
      });
    }
  }

  Future<void> _saveAmmo() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ammo_inventory', json.encode(ammoList));
  }

  void _addAmmo() {
    final nameCtrl = TextEditingController();
    final countCtrl = TextEditingController();
    final lotCtrl = TextEditingController();
    final countryCtrl = TextEditingController(); 

    showDialog(
      context: context,
      builder: (context) {
        final colors = Provider.of<ThemeProvider>(context, listen: false).colors;
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: colors['surface'],
              title: Text('إضافة عتاد جديد', style: TextStyle(color: colors['text'])),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'نوع العتاد (مثال: 155mm HE)')),
                    TextField(controller: countCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'الكمية')),
                    TextField(controller: lotCtrl, decoration: const InputDecoration(labelText: 'رقم الحزمة (LOT)')),
                    TextField(controller: countryCtrl, decoration: const InputDecoration(labelText: 'بلد المنشأ')), 
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء', style: TextStyle(color: Colors.grey))),
                ElevatedButton(
                  onPressed: () {
                    if (nameCtrl.text.isNotEmpty && countCtrl.text.isNotEmpty) {
                      setState(() {
                        ammoList.add({
                          'name': nameCtrl.text,
                          'count': int.tryParse(countCtrl.text) ?? 0,
                          'lot': lotCtrl.text.isEmpty ? 'غير محدد' : lotCtrl.text,
                          'country': countryCtrl.text.isEmpty ? 'غير محدد' : countryCtrl.text,
                        });
                        _saveAmmo();
                      });
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('حفظ'),
                ),
              ],
            );
          }
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Provider.of<ThemeProvider>(context).colors;
    
    return Scaffold(
      backgroundColor: colors['bg'],
      appBar: AppBar(
        title: const Text('مخزون الذخيرة (Ammo)'), 
        backgroundColor: colors['surface'],
        iconTheme: IconThemeData(color: colors['text'] ?? Colors.white),
      ),
      body: ammoList.isEmpty
          ? Center(child: Text('لا يوجد عتاد مسجل.\nاضغط على زر + للإضافة', textAlign: TextAlign.center, style: TextStyle(color: colors['text']?.withOpacity(0.5), fontSize: 18)))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: ammoList.length,
              itemBuilder: (context, index) {
                final ammo = ammoList[index];
                
                return Card(
                  color: colors['surface'],
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(side: BorderSide(color: colors['border'] ?? Colors.grey), borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: Icon(Icons.inventory_2, color: colors['primary'], size: 30),
                    title: Text(ammo['name'], style: TextStyle(color: colors['text'], fontWeight: FontWeight.bold)),
                    subtitle: Text('${ammo['country']} | حزمة: ${ammo['lot']}', style: TextStyle(color: colors['text']?.withOpacity(0.6))),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove_circle, color: Colors.red), 
                          onPressed: () {
                            setState(() { if(ammo['count'] > 0) ammo['count']--; _saveAmmo(); });
                          }
                        ),
                        Text('${ammo['count']}', style: TextStyle(color: colors['text'], fontSize: 18, fontWeight: FontWeight.bold)),
                        IconButton(
                          icon: const Icon(Icons.add_circle, color: Colors.green), 
                          onPressed: () {
                            setState(() { ammo['count']++; _saveAmmo(); });
                          }
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.grey), 
                          onPressed: () {
                            setState(() { ammoList.removeAt(index); _saveAmmo(); });
                          }
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addAmmo,
        backgroundColor: colors['primary'],
        foregroundColor: Colors.black,
        child: const Icon(Icons.add),
      ),
    );
  }
}