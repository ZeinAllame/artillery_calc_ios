import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../theme/theme_provider.dart';
import '../../../models/models.dart';
import '../../widgets/app_drawer.dart' show rootScaffoldKey; // ← الاستيراد المهم

class FireMissionLogScreen extends StatefulWidget {
  const FireMissionLogScreen({Key? key}) : super(key: key);

  @override
  State<FireMissionLogScreen> createState() => _FireMissionLogScreenState();
}

class _FireMissionLogScreenState extends State<FireMissionLogScreen> {
  List<FireMission> missions = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMissions();
  }

  Future<void> _loadMissions() async {
    final prefs = await SharedPreferences.getInstance();
    final String? missionsJson = prefs.getString('fire_missions');
    
    if (missionsJson != null) {
      List<dynamic> list = json.decode(missionsJson);
      setState(() {
        missions = list.map((e) => FireMission.fromJson(e)).toList();
        isLoading = false;
      });
    } else {
      setState(() => isLoading = false);
    }
  }

  Future<void> _deleteMission(String id) async {
    setState(() => missions.removeWhere((element) => element.id == id));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fire_missions', json.encode(missions.map((e) => e.toJson()).toList()));
  }

  @override
  Widget build(BuildContext context) {
    final colors = Provider.of<ThemeProvider>(context).colors;

    return Scaffold(
      backgroundColor: colors['bg'],
      appBar: AppBar(
        // ← إصلاح الشريط الجانبي هنا
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(Icons.menu, color: colors['text']),
            onPressed: () => rootScaffoldKey.currentState?.openDrawer(),
          ),
        ),
        title: const Text('سجل الرمايات (Fire Missions)'), 
        backgroundColor: colors['surface'],
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator(color: colors['primary']))
          : missions.isEmpty
              ? Center(child: Text('لا يوجد رمايات محفوظة', style: TextStyle(color: colors['text'], fontSize: 18)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: missions.length,
                  itemBuilder: (context, index) {
                    final mission = missions[index];
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
                        title: Text(mission.name, style: TextStyle(color: colors['primary'], fontWeight: FontWeight.bold, fontSize: 16)),
                        subtitle: Text(mission.date, style: TextStyle(color: colors['text']?.withOpacity(0.5), fontSize: 12)),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildInfoRow("المدفع", mission.weaponName, colors),
                                _buildInfoRow("العتاد", mission.shellName, colors),
                                const Divider(),
                                _buildInfoRow("إحداثيات المدفع", mission.gunMgrs, colors),
                                _buildInfoRow("إحداثيات الهدف", mission.targetMgrs, colors),
                                const Divider(),
                                _buildInfoRow("المسافة", mission.distance, colors),
                                _buildInfoRow("الاتجاه", mission.azimuth, colors),
                                _buildInfoRow("الارتفاع", mission.elevation, colors),
                                _buildInfoRow("الحشوة", mission.charge, colors),
                                _buildInfoRow("زمن الطيران", mission.tof, colors),
                                const SizedBox(height: 10),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => _deleteMission(mission.id),
                                  ),
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
      padding: const EdgeInsets.symmetric(vertical: 4.0),
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