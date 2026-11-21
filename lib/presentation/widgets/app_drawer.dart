import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../screens/friendly_forces/friendly_forces_screen.dart';
import '../../theme/theme_provider.dart';
import '../../theme/settings_provider.dart';
import '../screens/calculator/table_manager_screen.dart';
import '../screens/gun_laying/gun_laying_screen.dart';
import '../screens/manuals/manuals_screen.dart';
import '../screens/advanced_tools/advanced_tools_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/advanced_tools/acoustic_mesh_screen.dart';
import '../screens/arc_center_screen.dart'; // ★ تمت الإضافة: استيراد شاشة مركز القوس

/// مفتاح عام للوصول إلى Scaffold الرئيسي من أي شاشة متداخلة
final GlobalKey<ScaffoldState> rootScaffoldKey = GlobalKey<ScaffoldState>();

class AppDrawer extends StatelessWidget {
  final void Function(int index) onSelectTab;
  const AppDrawer({super.key, required this.onSelectTab});

  void _open(BuildContext context, Widget page) {
    final nav = Navigator.of(context);
    nav.pop();
    nav.push(MaterialPageRoute(builder: (_) => page));
  }

  void _goTab(BuildContext context, int index) {
    Navigator.pop(context);
    onSelectTab(index);
  }

  Future<void> _clearAllData(BuildContext context) async {
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final rootContext = rootScaffoldKey.currentContext ?? context;
    nav.pop();

    final confirmed = await showDialog<bool>(
      context: rootContext,
      builder: (dCtx) => AlertDialog(
        title: const Text('تأكيد المسح الشامل'),
        content: const Text(
            'سيتم مسح سجلات الرمي، الأهداف المحفوظة، وإعدادات المدفع.\nجداول الرمي المعدّلة يدوياً لن تُمسح للحماية.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dCtx, false),
              child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dCtx, true),
            child:
                const Text('مسح نهائي', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final p = await SharedPreferences.getInstance();
    final keys = p
        .getKeys()
        .where((k) =>
            !k.startsWith('custom_table_') && k != 'web_authenticated')
        .toList();
    for (final k in keys) {
      await p.remove(k);
    }
    messenger.showSnackBar(
      const SnackBar(
          content: Text('تم مسح البيانات بنجاح'), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Provider.of<ThemeProvider>(context).colors;

    Widget item(String title, IconData icon, VoidCallback onTap,
        {Color? color}) {
      return ListTile(
        leading: Icon(icon, color: color ?? colors['primary'], size: 22),
        title: Text(title,
            style: TextStyle(color: colors['text'], fontSize: 15)),
        onTap: onTap,
      );
    }

    Widget tool(String title, IconData icon, int index) {
      return ListTile(
        dense: true,
        contentPadding: const EdgeInsets.only(left: 32, right: 16),
        leading: Icon(icon, size: 18, color: colors['primary']),
        title: Text(title,
            style: TextStyle(color: colors['text'], fontSize: 13)),
        onTap: () => _open(context, AdvancedToolsScreen(initialIndex: index)),
      );
    }

    return Drawer(
      backgroundColor: colors['surface'],
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: colors['primary']),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset('assets/logo.png',
                      height: 70,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.shield, size: 70, color: Colors.white)),
                  const SizedBox(height: 8),
                  const Text('نظام السيطرة على النيران',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                  const Text('الإصدار 1.0.0',
                      style: TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                item('الحاسبة الرئيسية', Icons.calculate,
                    () => _goTab(context, 0)),
                item('حاسبة الأهداف', Icons.gps_fixed,
                    () => _goTab(context, 1)),
                item('غرفة العمليات', Icons.timer, () => _goTab(context, 2)),
                item('مخزون الذخيرة', Icons.inventory_2,
                    () => _goTab(context, 3)),
                item('الخريطة التكتيكية', Icons.map, () => _goTab(context, 4)),
                const Divider(height: 1),
                item('توجيه المدفع', Icons.explore,
                    () => _open(context, const GunLayingScreen())),
                item('إدارة جداول الرمي', Icons.table_chart,
                    () => _open(context, const TableManagerScreen()),
                    color: Colors.greenAccent),
                
                // ★ تمت الإضافة: عنصر قائمة مركز القوس ★
                item('مركز القوس', Icons.architecture,
                    () => _open(context, const ArcCenterScreen())),
               item('القوات الصديقة / الخطر', Icons.groups,
    () => _open(context, const FriendlyForcesScreen())),
                item('المُراسِل المشفر', Icons.security,
                    () => _open(context, const AcousticMeshScreen())),
                item('الكراسات والأدوات', Icons.menu_book,
                    () => _open(context, const ManualsScreen())),
                const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  child: Text('الأدوات المتقدمة',
                      style: TextStyle(
                          color: colors['text']?.withOpacity(0.6),
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
                ),
                tool('هدف متحرك', Icons.directions_run, 0),
                tool('إزاحة الهدف', Icons.open_with, 1),
                tool('الذخيرة المطلوبة', Icons.layers, 2),
                tool('قارئ الأوامر', Icons.text_snippet, 3),
                tool('نقطة السقوط', Icons.gps_not_fixed, 4),
                tool('الانفجار الجوي', Icons.flight_takeoff, 5),
                tool('وقت التهدئة', Icons.ac_unit, 6),
                tool('سجل الطقس', Icons.cloud, 7),
                tool('توزيع النيران', Icons.grid_view, 8),
                tool('أوامر صوتية', Icons.record_voice_over, 9),
                tool('سجل الاستهلاك', Icons.analytics, 10),
                tool('التصحيح الذاتي AI', Icons.psychology, 11),
                tool('MRSI Pro', Icons.flash_on, 12),
                tool('محاكي الرمي 3D', Icons.flight, 13),
                tool('إدارة البطارية', Icons.group_work, 14),
                tool('كاشف التضاريس', Icons.terrain, 15),
                tool('حاسبة الدخان', Icons.smoke_free, 16),
                tool('إنذار الصواريخ', Icons.warning, 17),
                tool('التشفير المتقدم', Icons.shield, 18),
                const Divider(height: 1),
                item('الإعدادات العامة', Icons.settings,
                    () => _open(context, const SettingsScreen())),
                item('سجل الرمايات', Icons.history, () => _goTab(context, 5)),
              ],
            ),
          ),
          Container(
            color: colors['surfaceLight'],
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.delete_forever,
                      color: Colors.red, size: 20),
                  title: const Text('مسح جميع البيانات',
                      style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 14)),
                  onTap: () => _clearAllData(context),
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 12),
                Text('تصميم وتطوير',
                    style: TextStyle(
                        color: colors['text']?.withOpacity(0.5), fontSize: 11)),
                Text('النقيب زين العابدين جاسب اللامي',
                    style: TextStyle(
                        color: colors['primary'],
                        fontSize: 13,
                        fontWeight: FontWeight.bold)),
                Text('وزارة الدفاع العراقية',
                    style: TextStyle(
                        color: colors['text']?.withOpacity(0.5), fontSize: 10)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}