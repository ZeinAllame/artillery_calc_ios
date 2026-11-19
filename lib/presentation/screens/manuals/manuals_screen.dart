import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../theme/theme_provider.dart';
import '../../widgets/app_drawer.dart' show rootScaffoldKey; // ← الاستيراد المهم

class ManualsScreen extends StatefulWidget {
  const ManualsScreen({Key? key}) : super(key: key);
  
  @override
  State<ManualsScreen> createState() => _ManualsScreenState();
}

class _ManualsScreenState extends State<ManualsScreen> {
  final List<Map<String, String>> manuals = [
    {'title': 'البوصلة العسكرية', 'content': '• البوصلة: جهاز يستخدم لتحديد الاتجاه.\n• تتكون من: إبرة ممغنطة، قرص مدرج، عدسة تصويب، حلقة إبهام.\n• طريقة العمل: أمسك البوصلة أفقياً، وجه العدسة نحو الهدف، اقرأ الرقم المقابل للمؤشر.\n• أنواع الشمال: حقيقي (Geographic)، مغناطيسي (Magnetic)، شبكي (Grid).\n• الفرق بينها يسمى G-M Angle ويجب تصحيحه.'},
    {'title': 'القبان (Clinometer)', 'content': '• جهاز لقياس زاوية ميلان السبطانة.\n• يستخدم لضبط زاوية الارتفاع (Elevation).\n• يوضع على السبطانة ويقرأ الزاوية بالساعات أو الملات.\n• في التطبيق: ضع الهاتف على السبطانة واقرأ القيمة من شاشة توجيه المدفع.'},
    {'title': 'أدوات المدفعي', 'content': '• المدفع: السلاح الرئيسي.\n• السبطانة: الأنبوب الذي تخرج منه القذيفة.\n• المغلاق: الجزء الخلفي لتحميل القذيفة.\n• المشيرة: لضبط الاتجاه.\n• المربض: لتثبيت المدفع.\n• الرمح: لتحديد الاتجاه مبدئياً.\n• أداة الارتفاع: لضبط الزاوية.'},
    {'title': 'جدول الرمي', 'content': '• جدول مرفق مع كل حزمة ذخيرة.\n• يحتوي على: المسافة، الارتفاع، الحشوة، زمن الطيران.\n• لكل حشوة جدول منفصل.\n• اقرأ الصف المقابل للمسافة المطلوبة.\n• استخدم استيفاء خطي (Linear Interpolation) بين الصفوف إذا لم تجد المسافة بالضبط.'},
    {'title': 'أنواع الذخيرة', 'content': '• HE (High Explosive): شديدة الانفجار، ضد المباني والأفراد.\n• WP (White Phosphorus): دخان وحارق.\n• Illum: تنوير ليلاً.\n• Smoke: حجاب دخاني.\n• في التطبيق: أضف كل نوع في شاشة الذخيرة مع رقم الحزمة (LOT) وبلد المنشأ.'},
  ];

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
        title: const Text('الكراسات وأدوات المدفعية'), 
        backgroundColor: colors['surface'],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: manuals.length,
        itemBuilder: (context, i) {
          final m = manuals[i];
          return Card(
            color: colors['surface'],
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: colors['border']!)),
            child: ExpansionTile(
              iconColor: colors['primary'],
              collapsedIconColor: colors['text'],
              title: Text(m['title']!, style: TextStyle(color: colors['primary'], fontWeight: FontWeight.bold, fontSize: 16)),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(m['content']!, style: TextStyle(color: colors['text'], fontSize: 14, height: 1.8)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}