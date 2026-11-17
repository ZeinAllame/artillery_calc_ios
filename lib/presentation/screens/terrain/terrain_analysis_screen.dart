import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mgrs_dart/mgrs_dart.dart';
import 'package:provider/provider.dart';
import '../../../theme/theme_provider.dart';

class TerrainAnalysisScreen extends StatefulWidget {
  const TerrainAnalysisScreen({Key? key}) : super(key: key);

  @override
  State<TerrainAnalysisScreen> createState() => _TerrainAnalysisScreenState();
}

class _TerrainAnalysisScreenState extends State<TerrainAnalysisScreen> {
  final gunMgrsCtrl = TextEditingController(text: "38SMB3578284178");
  final tgtMgrsCtrl = TextEditingController(text: "38SMB3599583060");
  String _result = "أدخل الإحداثيات لبدء التحليل";
  bool _isLoading = false;

  Future<void> _analyzeTerrain() async {
    setState(() { _isLoading = true; _result = "جاري تحليل التضاريس..."; });

    try {
      final gunPoint = Mgrs.toPoint(gunMgrsCtrl.text);
      final tgtPoint = Mgrs.toPoint(tgtMgrsCtrl.text);

      // نأخذ 5 نقاط بين المدفع والهدف للفحص
      List<String> locations = [];
      for (int i = 0; i <= 5; i++) {
        double lat = gunPoint[1] + (tgtPoint[1] - gunPoint[1]) * (i / 5);
        double lon = gunPoint[0] + (tgtPoint[0] - gunPoint[0]) * (i / 5);
        locations.add("$lat,$lon");
      }

      final url = Uri.parse('https://api.open-elevation.com/api/v1/lookup?locations=${locations.join("|")}');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['results'] as List;

        double maxElevation = 0;
        for (var res in results) {
          double elev = res['elevation'].toDouble();
          if (elev > maxElevation) maxElevation = elev;
        }

        setState(() {
          _result = "أعلى نقطة في مسار الرمي: ${maxElevation.toStringAsFixed(0)} متر.\n\n(إذا كانت هذه النقطة أعلى من خط رؤية المدفع والهدف، فهناك حائل يجب التعامل معه).";
        });
      } else {
        setState(() => _result = "فشل الاتصال بخادم الارتفاعات.");
      }
    } catch (e) {
      setState(() => _result = "خطأ: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Provider.of<ThemeProvider>(context).colors;

    return Scaffold(
      backgroundColor: colors['bg'],
      appBar: AppBar(title: const Text('تحليل التضاريس (LOS)'), backgroundColor: colors['surface']),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(controller: gunMgrsCtrl, decoration: const InputDecoration(labelText: 'MGRS المدفع')),
            TextField(controller: tgtMgrsCtrl, decoration: const InputDecoration(labelText: 'MGRS الهدف')),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _analyzeTerrain,
              icon: const Icon(Icons.terrain),
              label: const Text('فحص خط الرؤية (Crest Clearance)'),
              style: ElevatedButton.styleFrom(backgroundColor: colors['primary'], foregroundColor: Colors.black),
            ),
            const SizedBox(height: 20),
            if (_isLoading) CircularProgressIndicator(color: colors['primary']),
            if (!_isLoading)
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: colors['surface'], borderRadius: BorderRadius.circular(12)),
                  child: SingleChildScrollView(child: Text(_result, style: TextStyle(color: colors['text'], fontSize: 18))),
                ),
              )
          ],
        ),
      ),
    );
  }
}