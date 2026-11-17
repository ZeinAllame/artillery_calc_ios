import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../theme/theme_provider.dart';

class AcousticMeshScreen extends StatefulWidget {
  const AcousticMeshScreen({Key? key}) : super(key: key);

  @override
  State<AcousticMeshScreen> createState() => _AcousticMeshScreenState();
}

class _AcousticMeshScreenState extends State<AcousticMeshScreen> {
  final TextEditingController _msgCtrl = TextEditingController();
  bool _isTransmitting = false;
  String _status = "جاهز للإرسال";

  Future<void> _transmitData() async {
    if (_msgCtrl.text.isEmpty) return;
    
    setState(() {
      _isTransmitting = true;
      _status = "جاري بث النغمات الصوتية...";
    });

    // تحويل النص إلى نغمات (محاكاة FSK)
    for (int i = 0; i < _msgCtrl.text.length; i++) {
      // تشغيل نغمة النظام
      SystemSound.play(SystemSoundType.click);
      
      // تأخير بسيط بين كل نغمة
      await Future.delayed(const Duration(milliseconds: 200));
      
      // نغمة مختلفة للفراغ
      if (_msgCtrl.text[i] == ' ') {
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }

    setState(() {
      _isTransmitting = false;
      _status = "تم إرسال البيانات (ضع الهاتف الآخر في وضع الاستقبال)";
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Provider.of<ThemeProvider>(context).colors;

    return Scaffold(
      backgroundColor: colors['bg'],
      appBar: AppBar(title: const Text('نقل البيانات بالصوت (Mesh)'), backgroundColor: colors['surface']),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(_status, style: TextStyle(color: colors['primary'], fontSize: 18), textAlign: TextAlign.center),
            const SizedBox(height: 30),
            TextField(
              controller: _msgCtrl,
              decoration: const InputDecoration(labelText: 'البيانات (مثال: 38SMB3578284178)'),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _isTransmitting ? null : _transmitData,
              icon: Icon(_isTransmitting ? Icons.wifi_tethering : Icons.volume_up),
              label: const Text('بث البيانات'),
              style: ElevatedButton.styleFrom(
                backgroundColor: colors['primary'], 
                foregroundColor: Colors.black,
                minimumSize: const Size(double.infinity, 50)
              ),
            ),
          ],
        ),
      ),
    );
  }
}