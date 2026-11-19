import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../theme/theme_provider.dart';
import '../../widgets/app_drawer.dart' show rootScaffoldKey;

class AcousticMeshScreen extends StatefulWidget {
  const AcousticMeshScreen({Key? key}) : super(key: key);
  @override
  State<AcousticMeshScreen> createState() => _AcousticMeshScreenState();
}

class _AcousticMeshScreenState extends State<AcousticMeshScreen> {
  final _encryptCtrl = TextEditingController();
  final _decryptCtrl = TextEditingController();
  String _decryptedResult = "";
  Map<String, dynamic>? _lastDecryptedData; // ★ جديد: حفظ البيانات المفكوكة

  // ★ مفتاح التشفير السري (يجب أن يكون متطابقاً في جميع أجهزة الفصيلة)
  static const String _secretKey = "ARTY_IRQ_2024_SECURE_MESH";

  // دالة التشفير والضغط (XOR + Base64)
  String _encryptData(String gunMgrs, String tgtMgrs) {
    final map = {'g': gunMgrs, 't': tgtMgrs};
    final jsonStr = jsonEncode(map);
    final bytes = utf8.encode(jsonStr);
    final xored = _xorCrypt(bytes, _secretKey);
    return base64Encode(xored);
  }

  // دالة فك التشفير
  Map<String, dynamic>? _decryptData(String encoded) {
    try {
      final bytes = base64Decode(encoded.trim());
      final xored = _xorCrypt(bytes, _secretKey);
      final jsonStr = utf8.decode(xored);
      return jsonDecode(jsonStr);
    } catch (e) {
      return null;
    }
  }

  // خوارزمية XOR للتشفير المتماثل
  List<int> _xorCrypt(List<int> data, String key) {
    List<int> result = [];
    List<int> keyBytes = utf8.encode(key);
    for (int i = 0; i < data.length; i++) {
      result.add(data[i] ^ keyBytes[i % keyBytes.length]);
    }
    return result;
  }

  Future<void> _generateEncryptedMessage() async {
    final prefs = await SharedPreferences.getInstance();
    final gun = prefs.getString('last_gun_mgrs') ?? 'غير محدد';
    final tgt = prefs.getString('last_tgt_mgrs') ?? 'غير محدد';

    if (gun == 'غير محدد' && tgt == 'غير محدد') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد إحداثيات محفوظة. قم بحساب هدف أولاً.'), backgroundColor: Colors.red),
      );
      return;
    }

    final encrypted = _encryptData(gun, tgt);
    setState(() {
      _encryptCtrl.text = encrypted;
    });

    Clipboard.setData(ClipboardData(text: encrypted));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ تم التشفير والنسخ إلى الحافظة'), backgroundColor: Colors.green),
    );
  }

  void _processDecryption() {
    final result = _decryptData(_decryptCtrl.text);
    if (result != null) {
      final gun = result['g'] ?? 'غير معروف';
      final tgt = result['t'] ?? 'غير معروف';
      setState(() {
        _decryptedResult = "📍 مدفع: $gun\n🎯 هدف: $tgt";
        _lastDecryptedData = result; // ★ حفظ البيانات لاستخدامها في الإرسال
      });
    } else {
      setState(() {
        _decryptedResult = "❌ فشل فك التشفير: النص غير صالح أو تالف.";
        _lastDecryptedData = null;
      });
    }
  }

  // ★ دالة إرسال الإحداثيات إلى الحاسبة
  Future<void> _sendToCalculator() async {
    if (_lastDecryptedData == null) return;

    final gunMgrs = _lastDecryptedData!['g'] as String? ?? '';
    final tgtMgrs = _lastDecryptedData!['t'] as String? ?? '';

    if (gunMgrs.length < 12 || tgtMgrs.length < 12) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الإحداثيات غير صالحة'), backgroundColor: Colors.red),
      );
      return;
    }

    // ★ تقسيم MGRS إلى أجزائه
    // الصيغة: Zone(2) + Band(1) + Square(2) + Easting(5) + Northing(5) = 15 حرف
    String parseZone(String mgrs) => mgrs.substring(0, 2);
    String parseBand(String mgrs) => mgrs.substring(2, 3);
    String parseSquare(String mgrs) => mgrs.substring(3, 5);
    String parseE(String mgrs) => mgrs.substring(5, 10);
    String parseN(String mgrs) => mgrs.substring(10, 15);

    final prefs = await SharedPreferences.getInstance();

    // ★ حفظ إحداثيات الهدف (نفس المفاتيح التي تقرأها الحاسبة)
    await prefs.setString('calc_tgt_zone', parseZone(tgtMgrs));
    await prefs.setString('calc_tgt_band', parseBand(tgtMgrs));
    await prefs.setString('calc_tgt_sq', parseSquare(tgtMgrs));
    await prefs.setString('calc_tgt_e', parseE(tgtMgrs));
    await prefs.setString('calc_tgt_n', parseN(tgtMgrs));

    // ★ حفظ إحداثيات المدفع أيضاً (اختياري - لتحديث موقع المدفع)
    await prefs.setString('last_gun_mgrs', gunMgrs);
    await prefs.setString('last_tgt_mgrs', tgtMgrs);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ تم حفظ الإحداثيات - جاري الانتقال للحاسبة...'), backgroundColor: Colors.green, duration: Duration(seconds: 2)),
    );

    // ★ الانتقال إلى الحاسبة الرئيسية
    // ننتظر قليلاً حتى يرى المستخدم الرسالة
    await Future.delayed(const Duration(milliseconds: 800));

    if (!mounted) return;

    // نعود للشاشة الرئيسية (MainShell)
    Navigator.of(context).popUntil((route) => route.isFirst);

    // ننتظر حتى تكتمل عملية العودة ثم ننتقل لتبويب الحاسبة (index 0)
    await Future.delayed(const Duration(milliseconds: 300));

    if (!mounted) return;

    // ★ استخدام rootScaffoldKey للوصول إلى MainShellState والانتقال للحاسبة
    // لكن rootScaffoldKey يعطينا ScaffoldState وليس MainShellState
    // الحل: نستخدم Navigator للعودة ثم نفتح القائمة الجانبية ونختار الحاسبة
    // أو الأبسط: نترك الحاسبة تلتقط الإحداثيات تلقائياً عند العودة

    // ★ البديل الأفضل: إعادة فتح التطبيق من البداية مع فتح الحاسبة
    // لكن الأبسط: نستخدم rootScaffoldKey currentState لفتح الـ Drawer
    final scaffoldState = rootScaffoldKey.currentState;
    if (scaffoldState != null && scaffoldState.mounted) {
      scaffoldState.openDrawer();
    }
  }

  @override
  void dispose() {
    _encryptCtrl.dispose();
    _decryptCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Provider.of<ThemeProvider>(context).colors;
    return Scaffold(
      backgroundColor: colors['bg'],
      appBar: AppBar(
        title: const Text('المُرَاسِل التكتيكي المشفر'),
        backgroundColor: colors['surface'],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // قسم التشفير
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors['surface'],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors['primary']!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.lock_outline, color: colors['primary']),
                      const SizedBox(width: 8),
                      Text('1. إنشاء رسالة مشفرة', style: TextStyle(color: colors['primary'], fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text('سيقوم هذا الزر بأخذ إحداثيات المدفع والهدف الأخيرة، وتشفيرها في نص قصير آمن.',
                      style: TextStyle(color: colors['text']?.withOpacity(0.7), fontSize: 13)),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _generateEncryptedMessage,
                    icon: const Icon(Icons.security),
                    label: const Text('تشفير ونسخ الإحداثيات'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors['primary'],
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                  if (_encryptCtrl.text.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text('النص المشفر (جاهز للصق):', style: TextStyle(color: colors['text']?.withOpacity(0.7), fontSize: 12)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: colors['bg'], borderRadius: BorderRadius.circular(8)),
                      child: SelectableText(
                        _encryptCtrl.text,
                        style: TextStyle(color: colors['warning'], fontFamily: 'monospace', fontSize: 12, height: 1.4),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 24),

            // قسم فك التشفير
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors['surface'],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors['warning']!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.lock_open, color: colors['warning']),
                      const SizedBox(width: 8),
                      Text('2. فك تشفير رسالة مستلمة', style: TextStyle(color: colors['warning'], fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _decryptCtrl,
                    maxLines: 3,
                    style: TextStyle(color: colors['text'], fontFamily: 'monospace', fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'الصق النص المشفر هنا...',
                      hintStyle: TextStyle(color: colors['text']?.withOpacity(0.4)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.paste),
                        onPressed: () async {
                          final data = await Clipboard.getData(Clipboard.kTextPlain);
                          if (data?.text != null) {
                            setState(() => _decryptCtrl.text = data!.text!);
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _decryptCtrl.text.isEmpty ? null : _processDecryption,
                    icon: const Icon(Icons.unpublished),
                    label: const Text('فك التشفير'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors['warning'],
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                  if (_decryptedResult.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _decryptedResult.contains('❌') ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _decryptedResult.contains('❌') ? Colors.red : Colors.green),
                      ),
                      child: SelectableText(
                        _decryptedResult,
                        style: TextStyle(
                          color: _decryptedResult.contains('❌') ? Colors.red : Colors.green,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          height: 1.5,
                        ),
                      ),
                    ),
                    // ★ زر الإرسال إلى الحاسبة (يظهر فقط عند نجاح فك التشفير)
                    if (_lastDecryptedData != null) ...[
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: _sendToCalculator,
                        icon: const Icon(Icons.calculate),
                        label: const Text('إرسال إلى حاسبة الرمي'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),

            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors['surfaceLight'],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: colors['text']?.withOpacity(0.7), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'طريقة الاستخدام: الجهاز (أ) يضغط "تشفير" وينسخ النص. يرسله عبر واتساب أو يقرأه صوتياً. الجهاز (ب) يلصق النص ويضغط "فك التشفير" ثم "إرسال إلى الحاسبة".',
                      style: TextStyle(color: colors['text']?.withOpacity(0.7), fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}