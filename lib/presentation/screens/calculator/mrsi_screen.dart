import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../theme/theme_provider.dart';

class MrsiScreen extends StatefulWidget {
  final double baseDistance;
  const MrsiScreen({Key? key, required this.baseDistance}) : super(key: key);

  @override
  State<MrsiScreen> createState() => _MrsiScreenState();
}

class _MrsiScreenState extends State<MrsiScreen> {
  int rounds = 3;
  double delaySeconds = 5.0;

  @override
  Widget build(BuildContext context) {
    final colors = Provider.of<ThemeProvider>(context).colors;

    return Scaffold(
      backgroundColor: colors['bg'],
      appBar: AppBar(title: const Text('الرمي المتزامن (MRSI)'), backgroundColor: colors['surface']),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('المسافة الأساسية: ${widget.baseDistance.toStringAsFixed(0)} م', style: TextStyle(color: colors['primary'], fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Text('عدد القذائف:', style: TextStyle(color: colors['text'])),
            Slider(
              value: rounds.toDouble(),
              min: 2,
              max: 4,
              divisions: 2,
              label: "$rounds",
              onChanged: (val) => setState(() => rounds = val.toInt()),
            ),
            const SizedBox(height: 20),
            Text('الفارق الزمني بين الطلقات (ثوانٍ):', style: TextStyle(color: colors['text'])),
            Slider(
              value: delaySeconds,
              min: 1,
              max: 10,
              divisions: 9,
              label: "${delaySeconds.toInt()} ث",
              onChanged: (val) => setState(() => delaySeconds = val),
            ),
            const SizedBox(height: 30),
            Expanded(
              child: ListView.builder(
                itemCount: rounds,
                itemBuilder: (context, index) {
                  // محاكاة حساب زوايا مختلفة (في الواقع تحتاج لجدول رمي متقدم)
                  double fakeElevation = 1000 - (index * 50); 
                  return Card(
                    color: colors['surface'],
                    child: ListTile(
                      title: Text('الطلقة ${index + 1}', style: TextStyle(color: colors['text'])),
                      subtitle: Text('وقت الإطلاق: قبل الهدف بـ ${(index * delaySeconds).toInt()} ث', style: TextStyle(color: colors['warning'])),
                      trailing: Text('الارتفاع: ${fakeElevation.toInt()} مل', style: TextStyle(color: colors['primary'], fontWeight: FontWeight.bold)),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
} 