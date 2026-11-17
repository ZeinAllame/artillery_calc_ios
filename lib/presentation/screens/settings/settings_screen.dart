import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:mgrs_dart/mgrs_dart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../../theme/theme_provider.dart';
import '../../../theme/settings_provider.dart';
import '../../../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final gmCtrl = TextEditingController();
  bool fetching = false;

  @override
  void initState() {
    super.initState();
    // تحميل قيمة الانحراف المغناطيسي الحالية عند فتح الشاشة
    final sp = Provider.of<SettingsProvider>(context, listen: false);
    gmCtrl.text = sp.gMAngle.toStringAsFixed(2);
  }

  @override
  void dispose() {
    gmCtrl.dispose();
    super.dispose();
  }

  // حفظ زاوية الانحراف يدوياً
  Future<void> _saveGm() async {
    final v = double.tryParse(gmCtrl.text) ?? 0.0;
    await Provider.of<SettingsProvider>(context, listen: false).setGMAngle(v);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ الزاوية بنجاح'), backgroundColor: Colors.green),
      );
    }
  }

  // جلب زاوية الانحراف تلقائياً عبر GPS و API
  Future<void> _autoFetch() async {
    setState(() => fetching = true);
    try {
      final p = await SharedPreferences.getInstance();
      final gunMgrs = p.getString('last_gun_mgrs');
      
      if (gunMgrs == null) {
        throw 'يرجى حساب موقع المدفع أولاً في واجهة الحاسبة';
      }
      
      final pt = Mgrs.toPoint(gunMgrs);
      final lat = pt[1].toStringAsFixed(4);
      final lon = pt[0].toStringAsFixed(4);

      // استخدام خادم BGS (British Geological Survey)
      final url = Uri.parse(
          'https://geomag.bgs.ac.uk/web_service/GMM/calculate?latitude=$lat&longitude=$lon&height=0&date=2025-01-01&resultFormat=json');
      
      final res = await http.get(
        url,
        headers: {'Accept': 'application/json', 'User-Agent': 'Mozilla/5.0'},
      ).timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data['geomagnetic-field-model-result'] != null) {
          final decl = data['geomagnetic-field-model-result']['declination']['value'];
          final declVal = double.tryParse(decl.toString()) ?? 0.0;
          
          setState(() => gmCtrl.text = declVal.toStringAsFixed(2));
          await Provider.of<SettingsProvider>(context, listen: false).setGMAngle(declVal);
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('✅ G-M Angle: $declVal°'), backgroundColor: Colors.green),
            );
          }
          return;
        }
      }
      throw 'فشل الاتصال بالخادم';
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تعذر الجلب: $e\nأدخل الزاوية يدوياً (بغداد: +4.5°)'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => fetching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tp = Provider.of<ThemeProvider>(context);
    final sp = Provider.of<SettingsProvider>(context);
    final colors = tp.colors;

    return Scaffold(
      backgroundColor: colors['bg'],
      appBar: AppBar(title: const Text('الإعدادات'), backgroundColor: colors['surface']),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ============== قسم المظهر ==============
          Text('المظهر (Theme)', style: TextStyle(color: colors['primary'], fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(color: colors['surface'], borderRadius: BorderRadius.circular(8)),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<AppThemeMode>(
                isExpanded: true,
                dropdownColor: colors['surface'],
                value: tp.currentMode,
                items: const [
                  DropdownMenuItem(value: AppThemeMode.tactical, child: Text('تكتيكي', style: TextStyle(color: Colors.white))),
                  DropdownMenuItem(value: AppThemeMode.desert, child: Text('صحراوي', style: TextStyle(color: Colors.white))),
                  DropdownMenuItem(value: AppThemeMode.steel, child: Text('معدني', style: TextStyle(color: Colors.white))),
                  DropdownMenuItem(value: AppThemeMode.dark, child: Text('ليلي', style: TextStyle(color: Colors.white))),
                  DropdownMenuItem(value: AppThemeMode.nightVision, child: Text('رؤية ليلية', style: TextStyle(color: Colors.white))),
                ],
                onChanged: (v) {
                  if (v != null) tp.changeTheme(v);
                },
              ),
            ),
          ),
          
          const SizedBox(height: 30),

          // ============== قسم وحدات القياس ==============
          Text('وحدات القياس (تطبق على كل البرنامج)', style: TextStyle(color: colors['primary'], fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          _unitRow('وحدة الاتجاه', sp.directionUnit, (v) => sp.setDirectionUnit(v), colors),
          const SizedBox(height: 8),
          _unitRow('وحدة الارتفاع', sp.elevationUnit, (v) => sp.setElevationUnit(v), colors),

          const SizedBox(height: 30),

          // ============== قسم الانحراف المغناطيسي ==============
          Text('زاوية الانحراف المغناطيسي (G-M Angle)', style: TextStyle(color: colors['primary'], fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          TextField(
            controller: gmCtrl,
            keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
            style: TextStyle(color: colors['text']),
            decoration: InputDecoration(
              labelText: 'الزاوية (درجات)',
              suffixIcon: IconButton(icon: const Icon(Icons.save), onPressed: _saveGm),
            ),
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: fetching ? null : _autoFetch,
            icon: fetching 
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) 
                : const Icon(Icons.cloud_download),
            label: Text(fetching ? 'جاري الجلب...' : 'جلب تلقائي عبر GPS (BGS)'),
            style: ElevatedButton.styleFrom(
              backgroundColor: colors['secondary'], 
              foregroundColor: Colors.white, 
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
          
          const SizedBox(height: 30),

          // ============== معلومات إضافية ==============
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: colors['surface'], borderRadius: BorderRadius.circular(8)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ملاحظة ميدانية:', style: TextStyle(color: colors['warning'], fontWeight: FontWeight.bold)),
                const SizedBox(height: 5),
                Text(
                  'زاوية الانحراف المغناطيسي في العراق (بغداد) تتراوح تقريباً بين +4.0° إلى +5.0°. إذا فشل الجلب التلقائي، يمكنك إدخال القيمة يدوياً.',
                  style: TextStyle(color: colors['text']?.withOpacity(0.8), fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // مكون مساعد لعرض الوحدات (اتجاه / ارتفاع)
  Widget _unitRow(String label, int val, Function(int) onChanged, Map<String, Color> colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(color: colors['surface'], borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyle(color: colors['text']))),
          DropdownButton<int>(
            value: val,
            dropdownColor: colors['surface'],
            underline: const SizedBox(),
            items: const [
              DropdownMenuItem(value: 6400, child: Text('ملات 6400', style: TextStyle(color: Colors.white))),
              DropdownMenuItem(value: 6000, child: Text('ملات 6000', style: TextStyle(color: Colors.white))),
              DropdownMenuItem(value: 360, child: Text('درجات 360', style: TextStyle(color: Colors.white))),
            ],
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
          ),
        ],
      ),
    );
  }
}