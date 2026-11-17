import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../theme/theme_provider.dart';
import '../../../models/models.dart';

class TargetLogScreen extends StatefulWidget {
  const TargetLogScreen({Key? key}) : super(key: key);

  @override
  State<TargetLogScreen> createState() => _TargetLogScreenState();
}

class _TargetLogScreenState extends State<TargetLogScreen> {
  List<SavedTarget> targets = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTargets();
  }

  Future<void> _loadTargets() async {
    final prefs = await SharedPreferences.getInstance();
    final String? targetsJson = prefs.getString('saved_targets');
    
    if (targetsJson != null) {
      List<dynamic> list = json.decode(targetsJson);
      setState(() {
        targets = list.map((e) => SavedTarget.fromJson(e)).toList();
        isLoading = false;
      });
    } else {
      setState(() => isLoading = false);
    }
  }

  Future<void> _deleteTarget(String id) async {
    setState(() => targets.removeWhere((element) => element.id == id));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_targets', json.encode(targets.map((e) => e.toJson()).toList()));
  }

  @override
  Widget build(BuildContext context) {
    final colors = Provider.of<ThemeProvider>(context).colors;

    return Scaffold(
      backgroundColor: colors['bg'],
      appBar: AppBar(
        title: const Text('سجل الأهداف (Target Log)'), 
        backgroundColor: colors['surface'],
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator(color: colors['primary']))
          : targets.isEmpty
              ? Center(child: Text('لا يوجد أهداف محفوظة', style: TextStyle(color: colors['text'], fontSize: 18)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: targets.length,
                  itemBuilder: (context, index) {
                    final target = targets[index];
                    return Card(
                      color: colors['surface'],
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: colors['border']!),
                      ),
                      child: ExpansionTile(
                        iconColor: colors['primary'],
                        collapsedIconColor: colors['text'],
                        title: Text("${target.name} (${target.targetNumber})", style: TextStyle(color: colors['primary'], fontWeight: FontWeight.bold, fontSize: 16)),
                        subtitle: Text("${target.targetNature} | ${target.date}", style: TextStyle(color: colors['text']?.withOpacity(0.5), fontSize: 12)),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildInfoRow("موقع الراصد", target.observerMgrs, colors),
                                const Divider(),
                                _buildInfoRow("إحداثيات الهدف", target.targetMgrs, colors),
                                const Divider(),
                                _buildInfoRow("المسافة", "${target.distance.toStringAsFixed(0)} م", colors),
                                const Divider(),
                                _buildInfoRow("الاتجاه", "${target.azimuth.toStringAsFixed(0)} مل", colors),
                                const SizedBox(height: 15),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    ElevatedButton.icon(
                                      onPressed: () {
                                        // إرجاع الهدف المحدد إلى الشاشة السابقة
                                        Navigator.pop(context, target);
                                      },
                                      icon: const Icon(Icons.edit_location_alt),
                                      label: const Text('استخدام الهدف'),
                                      style: ElevatedButton.styleFrom(backgroundColor: colors['primary'], foregroundColor: Colors.black),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      onPressed: () => _deleteTarget(target.id),
                                    ),
                                  ],
                                )
                              ],
                            ),
                          )
                        ],
                      ),
                    );
                  },
                ),
    );
  }

  Widget _buildInfoRow(String label, String value, Map<String, Color> colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: colors['text']?.withOpacity(0.7), fontSize: 14)),
          Text(value, style: TextStyle(color: colors['text'], fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}